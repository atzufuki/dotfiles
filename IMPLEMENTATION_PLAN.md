# Toteutussuunnitelma: Container-only Desktop Environment

## Tavoite

Muuttaa dotfiles-repo tukemaan uutta arkkitehtuuria, jossa:
- Host-järjestelmä on minimaalinen (ei GNOME/KDE:tä hostissa)
- Host ajaa vain kevyen Wayland-compositorin (gamescope)
- Kaikki työpöytäympäristöt ajetaan Distrobox-konteissa
- GPU-kiihdytys, Wayland, PipeWire toimivat kontissa

## Arkkitehtuuri

### Host-taso
```
Fedora minimal host
└── gamescope (Wayland compositor)
    └── Session launcher
        └── distrobox enter → container DE
```

### Container-taso
- GNOME-kontti (gnome-box)
- Plasma-kontti (tulevaisuudessa)
- SteamOS-tyyli kontti (tulevaisuudessa)
- Muut kokeelliset DE:t

## Toteutus vaiheittain

### Vaihe 1: Host-järjestelmän paketit

**Tiedosto: `host-packages.txt`**

Vaaditut paketit hostiin:
```
podman
distrobox
gamescope
pipewire
pipewire-wireplumber
seatd
xorg-x11-server-Xwayland
mesa-dri-drivers
```

### Vaihe 2: Container-kuvien määritykset

**Tiedosto: `containers/gnome/Containerfile`**

Fedora GNOME -konttikuva:
```dockerfile
FROM fedora:43

RUN dnf install -y \
    gnome-shell \
    gnome-session \
    gsettings-desktop-schemas \
    dbus-x11 \
    xorg-x11-server-Xwayland \
    && dnf clean all
```

**Tiedosto: `containers/gnome/create.sh`**

Distrobox-luontiskripti oikeilla bindeillä:
```bash
#!/bin/bash
distrobox create -n gnome-box -i fedora-gnome:43 \
  --additional-flags "
    --ipc=host
    --security-opt label=disable
    --device /dev/dri
    --device /dev/snd
    --volume=$XDG_RUNTIME_DIR:$XDG_RUNTIME_DIR
    --env XDG_RUNTIME_DIR=$XDG_RUNTIME_DIR
    --env WAYLAND_DISPLAY=$WAYLAND_DISPLAY
  "
```

### Vaihe 3: Container sisäiset käynnistysskriptit

**Tiedosto: `containers/gnome/start-gnome.sh`**

Kontissa ajettava GNOME-käynnistys:
```bash
#!/bin/sh
export XDG_SESSION_TYPE=wayland
export XDG_CURRENT_DESKTOP=GNOME
exec dbus-run-session -- gnome-shell --display-server
```

Asennetaan kontin sisään: `~/.local/bin/start-gnome`

### Vaihe 4: Host-session launcher

**Tiedosto: `host/launchers/gnome-session.sh`**

Host-skripti joka käynnistää GNOME-kontin:
```bash
#!/bin/bash
exec distrobox enter gnome-box -- ~/.local/bin/start-gnome
```

### Vaihe 5: Gamescope Wayland session

**Tiedosto: `host/wayland-sessions/distrobox-gnome.desktop`**

Desktop entry gamescope-sessiota varten:
```ini
[Desktop Entry]
Name=GNOME (Distrobox)
Comment=GNOME Desktop Environment in Container
Exec=/usr/local/bin/gamescope-gnome-launcher.sh
Type=Application
DesktopNames=GNOME
```

**Tiedosto: `host/bin/gamescope-gnome-launcher.sh`**

Gamescope wrapper joka käynnistää kontin:
```bash
#!/bin/bash
exec gamescope -- /usr/local/bin/gnome-session.sh
```

### Vaihe 6: Pääasennus skripti

**Tiedosto: `setup.sh`**

Uusi master-skripti joka:
1. Asentaa host-paketit
2. Rakentaa container-kuvat
3. Luo distrobox-kontit
4. Kopioi launchers ja desktop files
5. Konfiguroi oikeudet

### Vaihe 7: Dokumentaatio

**Tiedosto: `README.md`**

Päivitetty dokumentaatio:
- Uuden arkkitehtuurin selitys
- Asennusohjeet
- Kontinhallinta-ohjeet
- Troubleshooting

**Tiedosto: `docs/ARCHITECTURE.md`**

Tekninen arkkitehtuuridokumentti:
- Wayland socket sharing
- PipeWire audio routing
- GPU passthrough
- Security implications (label=disable)

## Tiedostorakenne (uusi)

```
dotfiles/
├── README.md                           # Päivitetty kuvaus
├── setup.sh                            # Pääasennus
├── IMPLEMENTATION_PLAN.md              # Tämä tiedosto
│
├── host/
│   ├── packages.txt                    # Host-paketit
│   ├── bin/
│   │   ├── gamescope-gnome-launcher.sh
│   │   └── gnome-session.sh
│   └── wayland-sessions/
│       └── distrobox-gnome.desktop
│
├── containers/
│   ├── gnome/
│   │   ├── Containerfile              # GNOME image
│   │   ├── create.sh                  # Distrobox create
│   │   └── start-gnome.sh             # Kontin sisäinen launcher
│   │
│   ├── plasma/                         # Tulevaisuus
│   │   ├── Containerfile
│   │   ├── create.sh
│   │   └── start-plasma.sh
│   │
│   └── steamos/                        # Tulevaisuus
│       ├── Containerfile
│       ├── create.sh
│       └── start-steam.sh
│
└── docs/
    ├── ARCHITECTURE.md                 # Tekninen dokumentaatio
    ├── TROUBLESHOOTING.md              # Ongelmien ratkaisu
    └── EXAMPLES.md                     # Esimerkkejä

```

## Vanhat tiedostot (poistetaan)

Nämä eivät ole enää tarpeen uudessa arkkitehtuurissa:

```
containers/gnome/bootstrap.sh           # Korvataan create.sh + Containerfile
containers/sway/                        # Ei tarpeen, sway ei ole DE-kontti
etc/profile.d/fix_tmp.sh                # Ei tarpeen uudessa mallissa
home/atzufuki/                          # Käyttäjäkohtainen, ei geneerinen
usr/local/bin/distrobox-gnome-session.sh  # Korvataan uusilla launchereilla
usr/share/wayland-sessions/distrobox-gnome.desktop  # Siirretään host/
```

## Toteutusjärjestys

1. ✅ **Luo toteutussuunnitelma** (tämä tiedosto)
2. ⬜ Luo uusi tiedostorakenne
3. ⬜ Kirjoita host-pakettilista
4. ⬜ Luo GNOME Containerfile
5. ⬜ Luo distrobox create-skripti
6. ⬜ Luo start-gnome.sh konttiin
7. ⬜ Luo host launchers
8. ⬜ Luo gamescope desktop entry
9. ⬜ Kirjoita uusi setup.sh
10. ⬜ Päivitä README.md
11. ⬜ Luo ARCHITECTURE.md
12. ⬜ Testaa puhtaalla Fedora-asennuksella
13. ⬜ Poista vanhat tiedostot

## Haasteet ja ratkaisut

### Haaste 1: Wayland socket sharing
**Ratkaisu:** Bind XDG_RUNTIME_DIR volumella ja aseta WAYLAND_DISPLAY env var

### Haaste 2: GPU access
**Ratkaisu:** `--device /dev/dri` ja mesa-dri-drivers hostissa

### Haaste 3: Audio (PipeWire)
**Ratkaisu:** XDG_RUNTIME_DIR sisältää PipeWire socketit, bindata se

### Haaste 4: SELinux
**Ratkaisu:** `--security-opt label=disable` (turvallisuusriski, dokumentoi!)

### Haaste 5: Container persistence
**Ratkaisu:** Distrobox säilyttää datan, mutta tarjoa rebuild-skriptit

## Testaussuunnitelma

1. **VM-testi:** Asenna puhtaaseen Fedora 43 VM:ään
2. **Reboot-testi:** Varmista että session launcher toimii uudelleenkäynnistyksen jälkeen
3. **Multi-kontti testi:** Luo GNOME + toinen kontti, vaihda niiden välillä
4. **Performance:** Vertaa natiivin GNOME:n kanssa (FPS, latenssi)
5. **GPU-testi:** glxinfo, vulkaninfo kontissa
6. **Audio-testi:** PulseAudio/PipeWire toimii kontissa

## Tulevat laajennukset

- [ ] Plasma-kontti
- [ ] SteamOS-tyylinen gaming-kontti
- [ ] Automaattinen container cleanup
- [ ] Container snapshot/restore
- [ ] Multi-monitor tuki testaus
- [ ] Nvidia GPU tuki
- [ ] Helper flag: `distrobox create --desktop-session gnome`

## Edut uudessa mallissa

✅ Puhdas host-järjestelmä
✅ Helppo kokeilla eri DE:itä
✅ Rikkinäinen DE → poista kontti, luo uusi
✅ Päivitykset vain konteissa, host pysyy vakaana
✅ Soveltuu immutable OS -malliin (Silverblue, etc.)
✅ Mahdollistaa "SteamOS @ home" -tyylisen kokemuksen

## Liitteet

- Issue: https://github.com/atzufuki/dotfiles/issues/3
- Distrobox docs: https://distrobox.it/
- Gamescope: https://github.com/ValveSoftware/gamescope
