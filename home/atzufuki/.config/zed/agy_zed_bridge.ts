// agy_zed_bridge.ts
// A local bridge that exposes your Antigravity (agy) subscription as an OpenAI-compatible API for Zed.
// Supports separating reasoning/thinking steps into a dedicated collapsible UI box in Zed.

const PORT = 9988;
const AGY_PATH = "/home/atzufuki/.local/bin/agy";

interface Message {
  role: string;
  content: any; // Can be string or array of content blocks
}

interface ChatRequest {
  model: string;
  messages: Message[];
  stream?: boolean;
}

// Helper to extract text content from standard or rich content blocks
function extractTextContent(content: any): string {
  if (typeof content === "string") {
    return content;
  }
  if (Array.isArray(content)) {
    return content
      .map(block => {
        if (typeof block === "string") return block;
        if (block && typeof block === "object") {
          if (block.type === "text" && typeof block.text === "string") {
            return block.text;
          }
        }
        return "";
      })
      .join("\n");
  }
  if (content && typeof content === "object") {
    if (content.type === "text" && typeof content.text === "string") {
      return content.text;
    }
  }
  return "";
}

// Helper to parse the agy CLI log file for error messages when it fails silently
async function getLastErrorFromLog(): Promise<string | null> {
  const logPaths = [
    "/home/atzufuki/.gemini/antigravity-cli/cli.log",
    "/home/atzufuki/.gemini/antigravity/cli.log"
  ];
  for (const logPath of logPaths) {
    try {
      const file = await Deno.readTextFile(logPath);
      const lines = file.split("\n").filter(line => line.trim().length > 0);
      
      // Scan backwards for the most recent error
      for (let i = lines.length - 1; i >= Math.max(0, lines.length - 50); i--) {
        const line = lines[i];
        const startsWithError = line.startsWith("E") || line.startsWith("F");
        const containsErrorWord = line.toLowerCase().includes("error") || line.toLowerCase().includes("failed") || line.toLowerCase().includes("exhausted");
        
        if (startsWithError || containsErrorWord) {
          const msgIndex = line.indexOf("] ");
          if (msgIndex !== -1) {
            return line.slice(msgIndex + 2).trim();
          }
          return line.trim();
        }
      }
    } catch {
      // Ignore if file doesn't exist or can't be read
    }
  }
  return null;
}

// Formats data as OpenAI Server-Sent Event (SSE) chunk
const formatSse = (delta: { content?: string; reasoning_content?: string }) => {
  return `data: ${JSON.stringify({
    choices: [
      {
        delta,
        index: 0,
        finish_reason: null,
      },
    ],
  })}

`;
};

// Helper function to detect the active project workspace directory of Zed
async function detectWorkspaceDir(): Promise<string> {
  try {
    const process = new Deno.Command("lsof", {
      args: ["-c", "zed-editor", "-a", "-d", "cwd,rtd,txt,mem,0-999", "-F", "n"],
      stdout: "piped",
      stderr: "null",
    });
    const { stdout } = await process.output();
    const output = new TextDecoder().decode(stdout);
    
    // Parse output lines starting with 'n'
    const paths = output
      .split("\n")
      .filter(line => line.startsWith("n"))
      .map(line => line.slice(1).trim());

    // Sort paths by length descending to match most specific files first
    paths.sort((a, b) => b.length - a.length);

    for (const p of paths) {
      if (
        (p.startsWith("/home/atzufuki/") || p.startsWith("/var/home/atzufuki/")) &&
        !p.includes("/.local/") &&
        !p.includes("/.cache/") &&
        !p.includes("/.config/") &&
        !p.includes("/.gemini/") &&
        !p.includes("/.cargo/") &&
        !p.includes("/.rustup/")
      ) {
        let cleanPath = p;
        const gitIndex = p.indexOf("/.git");
        if (gitIndex !== -1) {
          cleanPath = p.slice(0, gitIndex);
        }
        
        try {
          const stat = await Deno.stat(cleanPath);
          if (stat.isDirectory) {
            return cleanPath;
          }
        } catch {
          // If it's a file, get its directory
          try {
            const parent = cleanPath.substring(0, cleanPath.lastIndexOf("/"));
            const stat = await Deno.stat(parent);
            if (stat.isDirectory && parent !== "/home/atzufuki" && parent !== "/var/home/atzufuki") {
              return parent;
            }
          } catch {}
        }
      }
    }
  } catch (err) {
    console.error("[Workspace Detector] Error:", err);
  }
  return "/home/atzufuki"; // Default fallback
}

const handler = async (req: Request): Promise<Response> => {
  const url = new URL(req.url);

  // CORS Preflight
  if (req.method === "OPTIONS") {
    return new Response(null, {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "GET, POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  // 1. GET /v1/models (Lists available models to Zed)
  if (req.method === "GET" && (url.pathname === "/v1/models" || url.pathname === "/models")) {
    const models = [
      "Gemini 3.5 Flash (Medium)",
      "Gemini 3.5 Flash (High)",
      "Gemini 3.5 Flash (Low)",
      "Gemini 3.1 Pro (Low)",
      "Gemini 3.1 Pro (High)",
      "Claude Sonnet 4.6 (Thinking)",
      "Claude Opus 4.6 (Thinking)",
      "GPT-OSS 120B (Medium)"
    ].map(id => ({ id, object: "model" }));

    return new Response(JSON.stringify({ object: "list", data: models }), {
      headers: {
        "Content-Type": "application/json",
        "Access-Control-Allow-Origin": "*"
      },
    });
  }

  // 2. POST /v1/chat/completions (Executes the model via agy CLI)
  if (req.method === "POST" && (url.pathname === "/v1/chat/completions" || url.pathname === "/chat/completions")) {
    try {
      const body: ChatRequest = await req.json();
      const model = body.model || "Gemini 3.5 Flash (Medium)";
      const messages = body.messages || [];
      const stream = body.stream ?? false;

      // Extract only the latest message safely and append response instruction
      const rawContent = messages[messages.length - 1]?.content || "";
      const lastMessage = extractTextContent(rawContent);
      const prompt = lastMessage + `\n\n[Instruction: Write your thoughts, plans, or tool actions first. When you are ready to output your final response to the user, output the separator "=== RESPONSE ===" on its own line, and then write your final response text. Do NOT repeat your final response text or greetings before the "=== RESPONSE ===" separator.]`;

      // Configure CLI arguments to continue existing conversation state.
      // We only use --continue if the thread actually contains assistant replies.
      const args = ["--model", model];
      const numPreviousAssistantMessages = messages.filter(msg => msg.role === "assistant").length;
      const hasAssistantMessage = numPreviousAssistantMessages > 0;
      if (hasAssistantMessage) {
        args.push("--continue");
      }
      // Increased print-timeout to 6h for very long-running agent cycles
      args.push("--print-timeout", "6h", "--print", prompt);

      const workspaceDir = await detectWorkspaceDir();
      console.log(`[Proxy] Model: ${model} | Continue: ${hasAssistantMessage} | Workspace: ${workspaceDir} | Prompt: ${lastMessage.substring(0, 60)}... | Stream: ${stream}`);

      // Spawn agy process
      const command = new Deno.Command(AGY_PATH, {
        args: args,
        cwd: workspaceDir,
        stdout: "piped",
        stderr: "piped",
      });

      const child = command.spawn();

      if (stream) {
        const encoder = new TextEncoder();
        const decoder = new TextDecoder();
        const reader = child.stdout.getReader();

        const streamResponse = new ReadableStream({
          async start(controller) {
            let markersSeen = 0;
            let buffer = "";
            let hasStreamedData = false;

            try {
              while (true) {
                const { value, done } = await reader.read();
                if (done) break;
                const text = decoder.decode(value, { stream: true });
                if (text) {
                  buffer += text;

                  const marker = "=== RESPONSE ===";
                  
                  // Keep processing buffer while there are markers to consume
                  while (true) {
                    const markerIndex = buffer.indexOf(marker);
                    if (markerIndex === -1) {
                      break;
                    }

                    // We found a marker!
                    const textBeforeMarker = buffer.slice(0, markerIndex);
                    
                    if (markersSeen < numPreviousAssistantMessages) {
                      // Discard history text before the marker (since agy --continue outputs all history)
                    } else if (markersSeen === numPreviousAssistantMessages) {
                      // This is the current turn's separator transition!
                      // Stream the text before the marker as reasoning_content
                      if (textBeforeMarker) {
                        controller.enqueue(encoder.encode(formatSse({ reasoning_content: textBeforeMarker })));
                        hasStreamedData = true;
                      }
                    } else {
                      // Already in content mode, stream text before the marker as content (should not normally happen)
                      if (textBeforeMarker) {
                        controller.enqueue(encoder.encode(formatSse({ content: textBeforeMarker })));
                        hasStreamedData = true;
                      }
                    }

                    markersSeen++;
                    // Remove processed text and marker from buffer
                    buffer = buffer.slice(markerIndex + marker.length);
                  }

                  // Process remaining buffer text (which doesn't contain a marker)
                  if (buffer.length > 0) {
                    if (markersSeen < numPreviousAssistantMessages) {
                      // Still in history mode, do NOT stream and keep buffer small to avoid memory leak
                    } else if (markersSeen === numPreviousAssistantMessages) {
                      // In reasoning mode for the current turn.
                      // Stream out safe reasoning content (leave a margin to avoid splitting a future marker)
                      if (buffer.length > 24) {
                        const streamable = buffer.slice(0, buffer.length - 24);
                        controller.enqueue(encoder.encode(formatSse({ reasoning_content: streamable })));
                        hasStreamedData = true;
                        buffer = buffer.slice(buffer.length - 24);
                      }
                    } else {
                      // In content mode for the current turn.
                      controller.enqueue(encoder.encode(formatSse({ content: buffer })));
                      hasStreamedData = true;
                      buffer = "";
                    }
                  }
                }
              }

              // Flush remaining buffer at the end
              if (buffer) {
                if (markersSeen < numPreviousAssistantMessages) {
                  // Succeeded but we never reached the current turn's start? Fallback to content
                  controller.enqueue(encoder.encode(formatSse({ content: buffer })));
                  hasStreamedData = true;
                } else if (markersSeen === numPreviousAssistantMessages) {
                  // Never saw the current turn's separator, treat remaining as normal content
                  controller.enqueue(encoder.encode(formatSse({ content: buffer })));
                  hasStreamedData = true;
                } else {
                  // In content mode
                  controller.enqueue(encoder.encode(formatSse({ content: buffer })));
                  hasStreamedData = true;
                }
              }

              // Check exit status of agy command
              const status = await child.status;
              let errorMsg: string | null = null;

              if (!status.success) {
                const errText = await new Response(child.stderr).text();
                errorMsg = errText.trim() || await getLastErrorFromLog() || "Agent process execution failed.";
              } else if (!hasStreamedData) {
                // Exit was clean but nothing was outputted to stdout. Detect silent failures (like quota limits) from log.
                errorMsg = await getLastErrorFromLog();
              }

              if (errorMsg) {
                console.error("[Proxy] agy process failed or returned empty. Error:", errorMsg);
                const isQuota = errorMsg.toLowerCase().includes("quota") || errorMsg.toLowerCase().includes("credit") || errorMsg.toLowerCase().includes("limit");
                const errorChunk = `data: ${JSON.stringify({
                  error: {
                    message: errorMsg.trim(),
                    type: isQuota ? "insufficient_quota" : "api_error",
                    param: null,
                    code: isQuota ? "insufficient_quota" : "execution_failed"
                  }
                })}\n\n`;
                controller.enqueue(encoder.encode(errorChunk));
                return;
              }

              // End of stream chunks
              const endChunk = `data: ${JSON.stringify({
                choices: [
                  {
                    delta: {},
                    index: 0,
                    finish_reason: "stop",
                  },
                ],
              })}

data: [DONE]

`;
              controller.enqueue(encoder.encode(endChunk));
            } catch (err) {
              if (err instanceof TypeError && 'message' in err && err.message.includes('cannot close or enqueue')) {
                // Ignore expected connection aborts
              } else {
                console.error("[Proxy Stream Error]", err);
              }
            } finally {
              controller.close();
            }
          },
          cancel(reason) {
            console.log(`[Proxy] Client closed connection (${reason}). Killing agy process.`);
            try {
              child.kill("SIGTERM");
            } catch (err) {
              console.error("[Proxy] Failed to kill agy process on abort:", err);
            }
          }
        });

        return new Response(streamResponse, {
          headers: {
            "Content-Type": "text/event-stream",
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "Access-Control-Allow-Origin": "*",
          },
        });
      } else {
        // Non-streaming response
        const { stdout, stderr } = await child.output();
        const text = new TextDecoder().decode(stdout);
        const errText = new TextDecoder().decode(stderr);

        let errorMsg: string | null = null;
        if (errText && !text) {
          errorMsg = errText.trim();
        } else if (!text.trim()) {
          errorMsg = await getLastErrorFromLog();
        }

        if (errorMsg) {
          const isQuota = errorMsg.toLowerCase().includes("quota") || errorMsg.toLowerCase().includes("credit") || errorMsg.toLowerCase().includes("limit");
          return new Response(JSON.stringify({
            error: {
              message: errorMsg.trim(),
              type: isQuota ? "insufficient_quota" : "api_error",
              code: isQuota ? "insufficient_quota" : "execution_failed"
            }
          }), {
            status: isQuota ? 429 : 500,
            headers: {
              "Content-Type": "application/json",
              "Access-Control-Allow-Origin": "*"
            },
          });
        }

        const marker = "=== RESPONSE ===";
        const parts = text.split(marker);
        
        let reasoningText = "";
        let contentText = "";

        // Skip the history parts (first numPreviousAssistantMessages parts)
        if (parts.length > numPreviousAssistantMessages) {
          const currentTurnParts = parts.slice(numPreviousAssistantMessages);
          if (currentTurnParts.length > 1) {
            reasoningText = currentTurnParts[0].trim();
            contentText = currentTurnParts.slice(1).join(marker).trim();
          } else {
            contentText = currentTurnParts[0].trim();
          }
        } else {
          contentText = text.trim();
        }

        const responseObj = {
          choices: [
            {
              message: {
                role: "assistant",
                content: contentText,
                reasoning_content: reasoningText || undefined,
              },
              finish_reason: "stop",
              index: 0,
            },
          ],
        };

        return new Response(JSON.stringify(responseObj), {
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*"
          },
        });
      }
    } catch (err) {
      console.error("[Proxy Request Error]", err);
      const errorMsg = err instanceof Error ? err.message : String(err);
      return new Response(JSON.stringify({
        error: {
          message: errorMsg,
          type: "api_error",
          code: "request_failed"
        }
      }), {
        status: 400,
        headers: {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*"
        },
      });
    }
  }

  return new Response("Not Found", { status: 404 });
};

console.log(`[Proxy] Running on http://localhost:${PORT}`);
Deno.serve({ port: PORT }, handler);
