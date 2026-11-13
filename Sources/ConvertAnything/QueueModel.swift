import AppKit
import Foundation

enum JobStatus: Equatable {
    case waiting, running, done, failed(String), cancelled
}

@MainActor
final class Job: ObservableObject, Identifiable {
    let id = UUID()
    let input: URL
    @Published var presetID: String
    @Published var status: JobStatus = .waiting
    @Published var progress: Double = 0
    @Published var output: URL?

    init(input: URL, presetID: String) {
        self.input = input
        self.presetID = presetID
    }

    var preset: Preset { Preset.find(presetID) }
}

@MainActor
final class QueueModel: ObservableObject {
    @Published var jobs: [Job] = []
    @Published var isRunning = false
    @Published var defaultPresetID: String {
        didSet { UserDefaults.standard.set(defaultPresetID, forKey: "defaultPreset") }
    }
    /// nil = neben der Originaldatei speichern
    @Published var outputFolder: URL? {
        didSet { UserDefaults.standard.set(outputFolder?.path, forKey: "outputFolder") }
    }

    private var runner: FFmpegRunner?

    static let mediaExtensions: Set<String> = [
        "wav", "aif", "aiff", "mp3", "m4a", "aac", "flac", "ogg", "opus", "wma", "caf",
        "mov", "mp4", "m4v", "mkv", "avi", "mxf", "webm", "mts", "m2ts", "mpg", "mpeg", "wmv", "3gp", "dv", "r3d", "braw"
    ]

    init() {
        defaultPresetID = UserDefaults.standard.string(forKey: "defaultPreset") ?? Preset.all[0].id
        if let path = UserDefaults.standard.string(forKey: "outputFolder") {
            outputFolder = URL(fileURLWithPath: path)
        }
    }

    var ffmpegAvailable: Bool { Tools.path("ffmpeg") != nil }

    // MARK: - Dateien hinzufügen

    func add(urls: [URL]) {
        for url in urls {
            var isDir: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) else { continue }
            if isDir.boolValue {
                let files = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil,
                                                           options: [.skipsHiddenFiles])?
                    .compactMap { $0 as? URL } ?? []
                for f in files.sorted(by: { $0.path < $1.path }) where isMedia(f) { append(f) }
            } else {
                append(url)
            }
        }
    }

    private func isMedia(_ url: URL) -> Bool {
        Self.mediaExtensions.contains(url.pathExtension.lowercased())
    }

    private func append(_ url: URL) {
        jobs.append(Job(input: url, presetID: defaultPresetID))
    }

    func applyDefaultPresetToWaiting() {
        for job in jobs where job.status == .waiting { job.presetID = defaultPresetID }
    }

    func remove(_ job: Job) {
        guard job.status != .running else { return }
        jobs.removeAll { $0.id == job.id }
    }

    func clearFinished() {
        jobs.removeAll { $0.status != .waiting && $0.status != .running }
    }

    func retry(_ job: Job) {
        job.status = .waiting
        job.progress = 0
    }

    // MARK: - Warteschlange abarbeiten

    func start() {
        guard !isRunning else { return }
        isRunning = true
        Task { await processQueue() }
    }

    func stop() {
        isRunning = false
        runner?.cancel()
    }

    private func processQueue() async {
        var finishedAny = false
        while isRunning, let job = jobs.first(where: { $0.status == .waiting }) {
            await run(job)
            finishedAny = true
        }
        isRunning = false
        if finishedAny { NSSound(named: "Glass")?.play() }
    }

    private func run(_ job: Job) async {
        let preset = job.preset
        let output = outputURL(for: job.input, preset: preset)
        job.status = .running
        job.progress = 0
        job.output = output

        let input = job.input
        let duration = await Task.detached { Tools.duration(of: input) }.value

        let runner = FFmpegRunner()
        self.runner = runner
        do {
            try await runner.run(input: input, output: output, preset: preset, duration: duration) { value in
                Task { @MainActor in job.progress = value }
            }
            job.progress = 1
            job.status = .done
        } catch FFmpegError.cancelled {
            try? FileManager.default.removeItem(at: output)
            job.status = .waiting
            job.progress = 0
            job.output = nil
        } catch {
            try? FileManager.default.removeItem(at: output)
            job.status = .failed(error.localizedDescription)
            job.output = nil
        }
        self.runner = nil
    }

    /// Erzeugt einen freien Dateinamen, damit nichts überschrieben wird.
    private func outputURL(for input: URL, preset: Preset) -> URL {
        let folder = outputFolder ?? input.deletingLastPathComponent()
        let base = input.deletingPathExtension().lastPathComponent + preset.suffix
        var candidate = folder.appendingPathComponent(base).appendingPathExtension(preset.fileExtension)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) || candidate.standardizedFileURL == input.standardizedFileURL {
            candidate = folder.appendingPathComponent("\(base) \(n)").appendingPathExtension(preset.fileExtension)
            n += 1
        }
        return candidate
    }
}
