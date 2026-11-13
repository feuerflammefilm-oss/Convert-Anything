import Foundation

enum FFmpegError: LocalizedError {
    case notFound
    case failed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notFound: return "FFmpeg wurde nicht gefunden."
        case .failed(let msg): return msg
        case .cancelled: return "Abgebrochen"
        }
    }
}

enum Tools {
    /// Sucht zuerst in der App, dann in den üblichen Homebrew-Pfaden.
    static func path(_ name: String) -> String? {
        var candidates: [String] = []
        if let r = Bundle.main.resourceURL { candidates.append(r.appendingPathComponent(name).path) }
        if let e = Bundle.main.executableURL { candidates.append(e.deletingLastPathComponent().appendingPathComponent(name).path) }
        candidates += ["/opt/homebrew/bin/\(name)", "/usr/local/bin/\(name)"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Länge der Datei in Sekunden (für den Fortschrittsbalken).
    static func duration(of url: URL) -> Double? {
        guard let ffprobe = path("ffprobe") else { return nil }
        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffprobe)
        p.arguments = ["-v", "error", "-show_entries", "format=duration",
                       "-of", "default=noprint_wrappers=1:nokey=1", url.path]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        let text = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        return Double(text)
    }
}

/// Startet einen einzelnen FFmpeg-Prozess und meldet den Fortschritt.
final class FFmpegRunner {
    private var process: Process?
    private var wasCancelled = false
    private let lock = NSLock()

    func cancel() {
        lock.lock(); defer { lock.unlock() }
        wasCancelled = true
        process?.terminate()
    }

    func run(input: URL, output: URL, preset: Preset, duration: Double?,
             onProgress: @escaping (Double) -> Void) async throws {
        guard let ffmpeg = Tools.path("ffmpeg") else { throw FFmpegError.notFound }

        let p = Process()
        p.executableURL = URL(fileURLWithPath: ffmpeg)
        p.arguments = ["-hide_banner", "-nostdin", "-y", "-i", input.path]
            + preset.args
            + ["-progress", "pipe:1", "-nostats", output.path]

        let outPipe = Pipe()
        let errPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = errPipe

        // Fortschritt aus "out_time_us=…"-Zeilen lesen
        var lineBuffer = ""
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            lineBuffer += String(decoding: data, as: UTF8.self)
            while let nl = lineBuffer.firstIndex(of: "\n") {
                let line = String(lineBuffer[..<nl])
                lineBuffer.removeSubrange(...nl)
                if let duration, duration > 0,
                   line.hasPrefix("out_time_us=") || line.hasPrefix("out_time_ms=") {
                    let value = line.split(separator: "=").last.flatMap { Double($0) } ?? 0
                    onProgress(min(1, max(0, value / 1_000_000 / duration)))
                }
            }
        }

        // Die letzten Fehlermeldungen merken
        var errTail = ""
        let errLock = NSLock()
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            errLock.lock()
            errTail += String(decoding: data, as: UTF8.self)
            if errTail.count > 4000 { errTail = String(errTail.suffix(4000)) }
            errLock.unlock()
        }

        lock.lock()
        process = p
        let cancelledBeforeStart = wasCancelled
        lock.unlock()
        if cancelledBeforeStart { throw FFmpegError.cancelled }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            p.terminationHandler = { proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                self.lock.lock()
                let cancelled = self.wasCancelled
                self.lock.unlock()

                if cancelled {
                    cont.resume(throwing: FFmpegError.cancelled)
                } else if proc.terminationStatus == 0 {
                    cont.resume()
                } else {
                    errLock.lock()
                    let lines = errTail.split(separator: "\n").suffix(3).joined(separator: "\n")
                    errLock.unlock()
                    cont.resume(throwing: FFmpegError.failed(lines.isEmpty ? "Fehler (Code \(proc.terminationStatus))" : lines))
                }
            }
            do {
                try p.run()
            } catch {
                p.terminationHandler = nil
                cont.resume(throwing: error)
            }
        }
    }
}
