import SwiftUI

@main
struct NativeBrightnessApp: App {
    @StateObject private var model: NativeBrightnessModel
    @Environment(\.openWindow) private var openWindow

    init() {
        StartupManager.ensureSingleRegistration()
        let model = NativeBrightnessModel()
        _model = StateObject(wrappedValue: model)
        model.scheduleStartupRestore()
    }

    private func showMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let window = NSApplication.shared.windows.first(where: { $0.title == "Native Brightness" }) {
            window.deminiaturize(nil)
            window.makeKeyAndOrderFront(nil)
            return
        }

        openWindow(id: "main")
        DispatchQueue.main.async {
            NSApplication.shared.windows
                .first(where: { $0.title == "Native Brightness" })?
                .makeKeyAndOrderFront(nil)
        }
    }

    var body: some Scene {
        WindowGroup("Native Brightness", id: "main") {
            ContentView(model: model)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Native Brightness", systemImage: "sun.max.fill") {
            ForEach(model.displays) { display in
                Section(display.name) {
                    Slider(value: Binding(
                        get: { display.brightness },
                        set: { model.setBrightness($0, for: display.id) }
                    ), in: 0...1) {
                        Text("Brightness")
                    }
                    Text("\(BrightnessMath.percentage(display.brightness))% · \(display.method.rawValue)")
                    Button("Restore") { model.restore(display.id) }
                }
            }
            Divider()
            Button("Open Native Brightness", action: showMainWindow)
            Button("Refresh Displays") { model.refresh() }
            Text(StartupManager.isEnabled ? "Starts automatically at login" : "Startup approval required")
                .font(.caption)
            Button("Quit Native Brightness") { NSApplication.shared.terminate(nil) }
        }
        .menuBarExtraStyle(.menu)
    }
}
