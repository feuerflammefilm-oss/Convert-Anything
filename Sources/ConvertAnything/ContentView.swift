import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PresetPicker: View {
    let title: String
    @Binding var selection: String

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(PresetCategory.allCases) { cat in
                Section(cat.title) {
                    ForEach(Preset.inCategory(cat)) { p in
                        Text(p.name).tag(p.id)
                    }
                }
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: QueueModel
    @State private var isDropTargeted = false
    @State private var mergeFiles: [URL]?

    var body: some View {
        VStack(spacing: 0) {
            settingsBar
            Divider()
            if !model.ffmpegAvailable { ffmpegWarning }
            queue
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .sheet(isPresented: Binding(get: { mergeFiles != nil }, set: { if !$0 { mergeFiles = nil } })) {
            MergeSheet(files: mergeFiles ?? [])
                .environmentObject(model)
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(6)
                    .allowsHitTesting(false)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button { Self.openFiles(model: model) } label: {
                    Label("Hinzufügen", systemImage: "plus")
                }
                Button { chooseMergeFiles() } label: {
                    Label("Zusammenfügen", systemImage: "rectangle.stack.badge.plus")
                }
                .help("Mehrere Dateien zu einer zusammenfügen")
                Button { model.clearFinished() } label: {
                    Label("Fertige entfernen", systemImage: "trash")
                }
                .disabled(model.jobs.allSatisfy { $0.status == .waiting || $0.status == .running })

                if model.isRunning {
                    Button { model.stop() } label: {
                        Label("Stopp", systemImage: "stop.fill")
                    }
                } else {
                    Button { model.start() } label: {
                        Label("Start", systemImage: "play.fill")
                    }
                    .disabled(!model.jobs.contains { $0.status == .waiting } || !model.ffmpegAvailable)
                    .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
    }

    // MARK: - Einstellungen oben

    private var settingsBar: some View {
        HStack(spacing: 16) {
            PresetPicker(title: "Preset:", selection: $model.defaultPresetID)
                .frame(maxWidth: 360)
            Button("Auf alle anwenden") { model.applyDefaultPresetToWaiting() }
                .disabled(!model.jobs.contains { $0.status == .waiting })

            Spacer()

            Text("Ziel:").foregroundStyle(.secondary)
            Text(model.outputFolder?.lastPathComponent ?? "Neben Original")
                .lineLimit(1)
                .truncationMode(.middle)
                .help(model.outputFolder?.path ?? "Die neue Datei landet im selben Ordner wie das Original.")
            Menu {
                Button("Ordner wählen …") { chooseOutputFolder() }
                Button("Neben Original speichern") { model.outputFolder = nil }
            } label: {
                Image(systemName: "folder")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var ffmpegWarning: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.yellow)
            Text("FFmpeg wurde nicht gefunden. Bitte die fertige App von GitHub verwenden oder FFmpeg mit Homebrew installieren.")
                .font(.callout)
            Spacer()
        }
        .padding(10)
        .background(.yellow.opacity(0.12))
    }

    // MARK: - Warteschlange

    @ViewBuilder
    private var queue: some View {
        if model.jobs.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.doc")
                    .font(.system(size: 48, weight: .light))
                    .foregroundStyle(.secondary)
                Text("Dateien oder Ordner hierher ziehen")
                    .font(.title3)
                Text("Audio und Video – WAV, AIFF, MP3, MOV, MP4, MXF …")
                    .foregroundStyle(.secondary)
                Button("Dateien auswählen …") { Self.openFiles(model: model) }
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                ForEach(model.jobs) { job in
                    JobRow(job: job)
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
        }
    }

    // MARK: - Aktionen

    static func openFiles(model: QueueModel) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.prompt = "Hinzufügen"
        if panel.runModal() == .OK { model.add(urls: panel.urls) }
    }

    private func chooseMergeFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.message = "Wähle die Dateien, die zusammengefügt werden sollen (z. B. alle Stücke einer Aufnahme)."
        panel.prompt = "Auswählen"
        guard panel.runModal() == .OK else { return }
        mergeFiles = panel.urls.sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }
    }

    private func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.prompt = "Als Ziel verwenden"
        if panel.runModal() == .OK { model.outputFolder = panel.url }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in model.add(urls: [url]) }
            }
        }
        return true
    }
}

struct JobRow: View {
    @ObservedObject var job: Job
    @EnvironmentObject var model: QueueModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(job.displayName)
                    .help(job.inputs.map(\.lastPathComponent).joined(separator: "\n"))
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                statusView
            }

            Spacer(minLength: 12)

            if job.status == .waiting {
                PresetPicker(title: "", selection: $job.presetID)
                    .labelsHidden()
                    .frame(width: 260)
            } else {
                Text(job.preset.name)
                    .foregroundStyle(.secondary)
                    .frame(width: 260, alignment: .trailing)
            }

            actionButtons
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusView: some View {
        switch job.status {
        case .waiting:
            Text("Wartet").font(.caption).foregroundStyle(.secondary)
        case .running:
            HStack {
                ProgressView(value: job.progress)
                Text("\(Int(job.progress * 100)) %")
                    .font(.caption.monospacedDigit())
                    .frame(width: 40, alignment: .trailing)
            }
        case .done:
            Text("Fertig → \(job.output?.lastPathComponent ?? "")")
                .font(.caption).foregroundStyle(.green).lineLimit(1)
        case .failed(let msg):
            Text(msg)
                .font(.caption).foregroundStyle(.red).lineLimit(2)
                .help(msg)
        case .cancelled:
            Text("Abgebrochen").font(.caption).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        HStack(spacing: 6) {
            if job.status == .done, let out = job.output {
                Button { NSWorkspace.shared.activateFileViewerSelecting([out]) } label: {
                    Image(systemName: "magnifyingglass")
                }
                .help("Im Finder zeigen")
            }
            if case .failed = job.status {
                Button { model.retry(job) } label: { Image(systemName: "arrow.clockwise") }
                    .help("Erneut versuchen")
            }
            if job.status != .running {
                Button { model.remove(job) } label: { Image(systemName: "xmark") }
                    .help("Entfernen")
            }
        }
        .buttonStyle(.borderless)
        .frame(width: 50, alignment: .trailing)
    }

    private var icon: String {
        switch job.status {
        case .waiting: return "clock"
        case .running: return "gearshape.2"
        case .done: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.circle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    private var iconColor: Color {
        switch job.status {
        case .done: return .green
        case .failed: return .red
        case .running: return .accentColor
        default: return .secondary
        }
    }
}
