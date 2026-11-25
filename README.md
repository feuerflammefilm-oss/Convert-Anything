# FuFF Convert

Kleine Mac-App zum Konvertieren von Audio und Video – ähnlich wie Adobe Media Encoder oder Compressor.
Unter der Haube arbeitet [FFmpeg](https://ffmpeg.org), das direkt in die App eingebaut ist.

## Was sie kann

- Dateien oder ganze Ordner per Drag & Drop in die Warteschlange ziehen
- Für jede Datei ein eigenes Preset wählen, dann **Start** (⌘↩)
- Fortschrittsbalken, Abbrechen, „Im Finder zeigen“, Ton wenn alles fertig ist
- Ziel: neben dem Original oder in einem festen Ordner. Es wird nie etwas überschrieben.

**Presets**

| Audio | Proxys | Video |
|---|---|---|
| MP3 320 / 192 / 128 | ProRes Proxy 1080p / 720p | H.264 hohe Qualität (Hardware) |
| AAC (M4A) 256 | ProRes LT 1080p | H.264 Web 1080p |
| WAV 16 / 24 Bit | H.264 1080p / 720p | HEVC / H.265 (Hardware) |
| AIFF 16 / 24 Bit | | ProRes 422 / HQ / 4444 |
| FLAC | | DNxHR HQ |

## Installieren (ohne Xcode)

1. Auf GitHub rechts auf **Releases → „latest“** gehen und `FuFF-Convert.zip` herunterladen.
2. ZIP öffnen und **FuFF Convert.app** in den Ordner **Programme** ziehen.
3. Beim ersten Start: **Rechtsklick → Öffnen**. Falls macOS es trotzdem blockiert:
   **Systemeinstellungen → Datenschutz & Sicherheit → „Dennoch öffnen“**.
   Alternativ im Terminal:
   ```bash
   xattr -cr "/Applications/FuFF Convert.app"
   ```

Die App ist nicht bei Apple registriert (kostet 99 $/Jahr), deshalb dieser einmalige Schritt.

## Wie sie gebaut wird

Bei jedem Push auf `main` baut GitHub Actions auf einem Mac in der Cloud die App
(`scripts/build_app.sh`) und veröffentlicht sie als Release „latest“.

Neue Presets kommen in `Sources/ConvertAnything/Presets.swift`.
