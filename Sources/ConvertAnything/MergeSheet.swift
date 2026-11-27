import AppKit
import SwiftUI

/// Fenster zum Zusammenfügen mehrerer Dateien (z. B. 512-MB-Stücke eines Mikrofons) zu einer.
struct MergeSheet: View {
    @EnvironmentObject var model: QueueModel
    @Environment(\.dismiss) private var dismiss
    @State var files: [URL]
    @State private var presetID = "copy"
    /// nil = wird noch geprüft
    @State private var identical: Bool?
    @State private var selection: URL?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Dateien zusammenfügen").font(.title2.weight(.semibold))
            Text("Die Dateien werden in dieser Reihenfolge nahtlos hintereinandergehängt. Mit „Original-Format beibehalten“ geht das verlustfrei und in Sekunden – die Dateien müssen dafür aus demselben Gerät mit denselben Einstellungen stammen.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List(selection: $selection) {
                ForEach(Array(files.enumerated()), id: \.element) { i, url in
                    HStack {
                        Text("\(i + 1).").foregroundStyle(.secondary).monospacedDigit().frame(width: 28, alignment: .trailing)
                        Text(url.lastPathComponent).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(size(of: url)).foregroundStyle(.secondary).font(.caption)
                    }
                    .tag(url)
                }
                .onMove { files.move(fromOffsets: $0, toOffset: $1) }
            }
            .frame(minHeight: 200)
            .onDeleteCommand { if let s = selection { files.removeAll { $0 == s } } }

            HStack {
                Button { move(-1) } label: { Image(systemName: "arrow.up") }
                    .disabled(!canMove(-1))
                    .help("Nach oben")
                Button { move(1) } label: { Image(systemName: "arrow.down") }
                    .disabled(!canMove(1))
                    .help("Nach unten")
                Button("Nach Namen sortieren") {
                    files.sort { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
                }
                Button("Weitere hinzufügen …") { addMore() }
                Button("Entfernen") { files.removeAll { $0 == selection } }
                    .disabled(selection == nil)
            }

            PresetPicker(title: "Ausgabe:", selection: $presetID)
            if identical == nil {
                HStack { ProgressView().controlSize(.small); Text("Dateien werden geprüft …").foregroundStyle(.secondary) }
            } else if identical == false {
                Label(presetID == "copy"
                      ? "Achtung: Die Dateien haben unterschiedliche Formate (z. B. Bitrate oder Abtastrate). Verlustfreies Aneinanderhängen funktioniert dann nicht sauber – bitte ein Preset wie MP3 oder WAV wählen."
                      : "Die Dateien haben unterschiedliche Formate und werden deshalb neu kodiert.",
                      systemImage: presetID == "copy" ? "exclamationmark.triangle.fill" : "info.circle")
                    .foregroundStyle(presetID == "copy" ? .orange : .secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Zur Warteschlange hinzufügen") {
                    model.addMerge(urls: files, presetID: presetID)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(files.count < 2)
            }
        }
        .padding(22)
        .frame(width: 560)
        .task(id: files) { await checkFormats() }
    }

    /// Prüft, ob alle Dateien dasselbe Format haben. Wenn nicht: passendes Preset zum Neu-Kodieren wählen.
    private func checkFormats() async {
        identical = nil
        let list = files
        let same = await Task.detached { () -> Bool in
            let sigs = list.map { Tools.signature(of: $0) }
            guard let first = sigs.first, first != nil else { return false }
            return sigs.allSatisfy { $0 == first }
        }.value
        identical = same
        if !same && presetID == "copy" {
            presetID = Self.reencodePreset(for: list.first?.pathExtension.lowercased() ?? "")
        }
    }

    static func reencodePreset(for ext: String) -> String {
        switch ext {
        case "wav": return "wav-24"
        case "aif", "aiff": return "aiff-24"
        case "m4a", "aac": return "aac-256"
        case "flac": return "flac"
        case "mov", "mp4", "m4v", "mxf": return "prores-422"
        default: return "mp3-320"
        }
    }

    private func canMove(_ d: Int) -> Bool {
        guard let s = selection, let i = files.firstIndex(of: s) else { return false }
        return files.indices.contains(i + d)
    }

    private func move(_ d: Int) {
        guard let s = selection, let i = files.firstIndex(of: s), files.indices.contains(i + d) else { return }
        files.swapAt(i, i + d)
    }

    private func addMore() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.prompt = "Hinzufügen"
        if panel.runModal() == .OK {
            files += panel.urls.filter { !files.contains($0) }
        }
    }

    private func size(of url: URL) -> String {
        let bytes = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
