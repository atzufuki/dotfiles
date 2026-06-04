// agy_zed_bridge.ts
// A local bridge that exposes your Antigravity (agy) subscription as an OpenAI-compatible API for Zed.

const PORT = 9988;
const AGY_PATH = "/home/atzufuki/.local/bin/agy";

interface Message {
  role: string;
  content: string;
}

interface ChatRequest {
  model: string;
  messages: Message[];
  stream?: boolean;
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

      // Format conversation history for agy
      let prompt = "";
      for (const msg of messages) {
        if (msg.role === "system") {
          prompt += `[System]\n${msg.content}\n\n`;
        } else if (msg.role === "user") {
          prompt += `[User]\n${msg.content}\n\n`;
        } else if (msg.role === "assistant") {
          prompt += `[Assistant]\n${msg.content}\n\n`;
        }
      }

      console.log(`[Proxy] Model: ${model} | Prompt length: ${prompt.length} chars | Stream: ${stream}`);

      // Spawn agy process
      const command = new Deno.Command(AGY_PATH, {
        args: ["--model", model, "--print", prompt],
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
            try {
              while (true) {
                const { value, done } = await reader.read();
                if (done) break;
                const text = decoder.decode(value, { stream: true });
                if (text) {
                  // Format as OpenAI SSE chunk
                  const sseChunk = `data: ${JSON.stringify({
                    choices: [
                      {
                        delta: { content: text },
                        index: 0,
                        finish_reason: null,
                      },
                    ],
                  })}\n\n`;
                  controller.enqueue(encoder.encode(sseChunk));
                }
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
              })}\n\ndata: [DONE]\n\n`;
              controller.enqueue(encoder.encode(endChunk));
            } catch (err) {
              console.error("[Proxy Stream Error]", err);
            } finally {
              controller.close();
            }
          },
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

        if (errText && !text) {
          return new Response(JSON.stringify({ error: errText }), {
            status: 500,
            headers: { 
              "Content-Type": "application/json",
              "Access-Control-Allow-Origin": "*"
            },
          });
        }

        const responseObj = {
          choices: [
            {
              message: {
                role: "assistant",
                content: text,
              },
              finish_reason: "stop",
              index: 0,
            },
          ],
        };

        return new Response(JSON.stringify(responseObj), {
          headers: {
            "Content-Type": "application/json",
            "Access-Control-Allow-Origin": "*",
          },
        });
      }
    } catch (err) {
      console.error("[Proxy Request Error]", err);
      return new Response(JSON.stringify({ error: err.message }), {
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
