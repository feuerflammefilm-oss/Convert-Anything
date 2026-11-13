import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct ConvertAnythingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var model = QueueModel()

    var body: some Scene {
        WindowGroup("Convert Anything") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 760, minHeight: 460)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Dateien hinzufügen …") { ContentView.openFiles(model: model) }
                    .keyboardShortcut("o")
            }
        }
    }
}
