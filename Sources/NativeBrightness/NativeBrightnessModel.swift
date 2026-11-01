import Foundation

@MainActor
final class NativeBrightnessModel: ObservableObject {
    @Published private(set) var displays: [DisplayInfo] = []
    @Published var errorMessage: String?

    private let backend: DisplayBackend
    private let store: DisplayStore

    init(backend: DisplayBackend = GammaDisplayBackend(), store: DisplayStore = DisplayStore()) {
        self.backend = backend
        self.store = store
        refresh()
    }

    func scheduleStartupRestore() {
        // WindowServer may finish restoring display transfer curves shortly
        // after the login item launches. Retry after that handoff so the saved
        // value affects the display even when the user never touches the slider.
        for delay in [0.35, 1.25] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.refresh()
            }
        }
    }

    func refresh() {
        displays = backend.displays().map { display in
            var updated = display
            if let saved = store.brightness(for: display.id) {
                updated.brightness = saved
            }
            return updated
        }
        applySavedBrightness()
    }

    func setBrightness(_ value: Double, for displayID: UInt32) {
        let value = BrightnessMath.clamped(value)
        do {
            try backend.setBrightness(value, for: displayID)
            update(displayID: displayID, brightness: value)
            store.save(value, for: displayID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore(_ displayID: UInt32) {
        do {
            try backend.restore(displayID)
            update(displayID: displayID, brightness: 1)
            store.save(1, for: displayID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func update(displayID: UInt32, brightness: Double) {
        guard let index = displays.firstIndex(where: { $0.id == displayID }) else { return }
        displays[index].brightness = brightness
    }

    private func applySavedBrightness() {
        for display in displays {
            guard display.method != .unavailable,
                  let saved = store.brightness(for: display.id) else { continue }
            do {
                try backend.setBrightness(saved, for: display.id)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
