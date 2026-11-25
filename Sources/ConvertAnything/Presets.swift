import Foundation

enum PresetCategory: String, CaseIterable, Identifiable {
    case audio, proxy, video, original

    var id: String { rawValue }

    var title: String {
        switch self {
        case .audio: return "Audio"
        case .proxy: return "Proxys"
        case .video: return "Video"
        case .original: return "Ohne Umwandeln"
        }
    }
}

/// Ein Preset beschreibt, welche FFmpeg-Argumente zwischen Eingabe und Ausgabe stehen.
struct Preset: Identifiable, Hashable {
    let id: String
    let name: String
    let category: PresetCategory
    /// Wird an den Dateinamen angehängt, z. B. "Interview_proxy.mov".
    let suffix: String
    /// Leer = Dateiendung der Originaldatei behalten
    let fileExtension: String
    let args: [String]

    static func find(_ id: String) -> Preset {
        all.first { $0.id == id } ?? all[0]
    }

    static func inCategory(_ c: PresetCategory) -> [Preset] {
        all.filter { $0.category == c }
    }

    // MARK: - Bausteine

    private static func fit(_ w: Int, _ h: Int) -> String {
        "scale=w=\(w):h=\(h):force_original_aspect_ratio=decrease:force_divisible_by=2"
    }

    private static func prores(_ profile: Int, pixFmt: String = "yuv422p10le") -> [String] {
        ["-c:v", "prores_ks", "-profile:v", "\(profile)", "-vendor", "apl0", "-pix_fmt", pixFmt]
    }

    private static let pcmAudio = ["-c:a", "pcm_s16le"]
    private static let aacAudio = ["-c:a", "aac", "-b:a", "320k"]

    // MARK: - Alle Presets

    static let all: [Preset] = [
        // Audio
        Preset(id: "mp3-320", name: "MP3 – 320 kbit/s", category: .audio, suffix: "", fileExtension: "mp3",
               args: ["-vn", "-c:a", "libmp3lame", "-b:a", "320k"]),
        Preset(id: "mp3-192", name: "MP3 – 192 kbit/s", category: .audio, suffix: "", fileExtension: "mp3",
               args: ["-vn", "-c:a", "libmp3lame", "-b:a", "192k"]),
        Preset(id: "mp3-128", name: "MP3 – 128 kbit/s", category: .audio, suffix: "", fileExtension: "mp3",
               args: ["-vn", "-c:a", "libmp3lame", "-b:a", "128k"]),
        Preset(id: "aac-256", name: "AAC (M4A) – 256 kbit/s", category: .audio, suffix: "", fileExtension: "m4a",
               args: ["-vn", "-c:a", "aac", "-b:a", "256k"]),
        Preset(id: "wav-16", name: "WAV – 16 Bit", category: .audio, suffix: "", fileExtension: "wav",
               args: ["-vn", "-c:a", "pcm_s16le"]),
        Preset(id: "wav-24", name: "WAV – 24 Bit", category: .audio, suffix: "", fileExtension: "wav",
               args: ["-vn", "-c:a", "pcm_s24le"]),
        Preset(id: "aiff-16", name: "AIFF – 16 Bit", category: .audio, suffix: "", fileExtension: "aiff",
               args: ["-vn", "-c:a", "pcm_s16be"]),
        Preset(id: "aiff-24", name: "AIFF – 24 Bit", category: .audio, suffix: "", fileExtension: "aiff",
               args: ["-vn", "-c:a", "pcm_s24be"]),
        Preset(id: "flac", name: "FLAC (verlustfrei)", category: .audio, suffix: "", fileExtension: "flac",
               args: ["-vn", "-c:a", "flac"]),

        // Proxys
        Preset(id: "proxy-prores-1080", name: "ProRes Proxy – 1080p", category: .proxy, suffix: "_proxy", fileExtension: "mov",
               args: ["-vf", fit(1920, 1080)] + prores(0) + pcmAudio),
        Preset(id: "proxy-prores-720", name: "ProRes Proxy – 720p", category: .proxy, suffix: "_proxy", fileExtension: "mov",
               args: ["-vf", fit(1280, 720)] + prores(0) + pcmAudio),
        Preset(id: "proxy-proreslt-1080", name: "ProRes LT – 1080p", category: .proxy, suffix: "_proxy", fileExtension: "mov",
               args: ["-vf", fit(1920, 1080)] + prores(1) + pcmAudio),
        Preset(id: "proxy-h264-1080", name: "H.264 – 1080p (Hardware)", category: .proxy, suffix: "_proxy", fileExtension: "mp4",
               args: ["-vf", fit(1920, 1080), "-c:v", "h264_videotoolbox", "-b:v", "10M", "-pix_fmt", "yuv420p"]
                    + aacAudio + ["-movflags", "+faststart"]),
        Preset(id: "proxy-h264-720", name: "H.264 – 720p (Hardware)", category: .proxy, suffix: "_proxy", fileExtension: "mp4",
               args: ["-vf", fit(1280, 720), "-c:v", "h264_videotoolbox", "-b:v", "5M", "-pix_fmt", "yuv420p"]
                    + aacAudio + ["-movflags", "+faststart"]),

        // Video (Originalauflösung)
        Preset(id: "h264-high", name: "H.264 – hohe Qualität (Hardware)", category: .video, suffix: "_h264", fileExtension: "mp4",
               args: ["-c:v", "h264_videotoolbox", "-b:v", "25M", "-pix_fmt", "yuv420p"] + aacAudio + ["-movflags", "+faststart"]),
        Preset(id: "h264-web-1080", name: "H.264 – Web 1080p (Hardware)", category: .video, suffix: "_web", fileExtension: "mp4",
               args: ["-vf", fit(1920, 1080), "-c:v", "h264_videotoolbox", "-b:v", "8M", "-pix_fmt", "yuv420p"]
                    + ["-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"]),
        Preset(id: "hevc-high", name: "HEVC (H.265) – hohe Qualität (Hardware)", category: .video, suffix: "_hevc", fileExtension: "mp4",
               args: ["-c:v", "hevc_videotoolbox", "-b:v", "15M", "-tag:v", "hvc1"] + aacAudio + ["-movflags", "+faststart"]),
        Preset(id: "prores-422", name: "ProRes 422", category: .video, suffix: "_prores", fileExtension: "mov",
               args: prores(2) + pcmAudio),
        Preset(id: "prores-422hq", name: "ProRes 422 HQ", category: .video, suffix: "_proresHQ", fileExtension: "mov",
               args: prores(3) + pcmAudio),
        Preset(id: "prores-4444", name: "ProRes 4444", category: .video, suffix: "_prores4444", fileExtension: "mov",
               args: prores(4, pixFmt: "yuva444p10le") + pcmAudio),
        Preset(id: "copy", name: "Original-Format beibehalten (verlustfrei)", category: .original, suffix: "", fileExtension: "",
               args: ["-map", "0", "-c", "copy"]),
        Preset(id: "dnxhr-hq", name: "DNxHR HQ", category: .video, suffix: "_dnxhr", fileExtension: "mov",
               args: ["-c:v", "dnxhd", "-profile:v", "dnxhr_hq", "-pix_fmt", "yuv422p"] + pcmAudio),
    ]
}
