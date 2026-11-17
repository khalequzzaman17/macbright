import AppKit
import Foundation

@MainActor
final class NativeBrightnessModel: ObservableObject {
    @Published private(set) var displays: [DisplayInfo] = []
    @Published var errorMessage: String?

    private let backend: DisplayBackend
    private let store: DisplayStore
    private var observerTokens: [NSObjectProtocol] = []
    private var workspaceObserverTokens: [NSObjectProtocol] = []
    private var restoreWorkItems: [DispatchWorkItem] = []
    private var syncTimer: Timer?
    private var isScreenAsleep = false

    init(
        backend: DisplayBackend = GammaDisplayBackend(),
        store: DisplayStore = DisplayStore(),
        observeSystemEvents: Bool = true
    ) {
        self.backend = backend
        self.store = store
        refresh()
        if observeSystemEvents {
            startObservingSystemEvents()
            syncTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.syncIfNeeded()
                }
            }
        }
    }

    deinit {
        syncTimer?.invalidate()
        restoreWorkItems.forEach { $0.cancel() }
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        workspaceObserverTokens.forEach { workspaceCenter.removeObserver($0) }
        let defaultCenter = NotificationCenter.default
        observerTokens.forEach { defaultCenter.removeObserver($0) }
    }

    func scheduleStartupRestore() {
        // WindowServer and ColorSync may finish restoring or overriding display
        // transfer curves several seconds after login or wake. Retry in stages
        // so the saved value sticks even when the user never touches the slider.
        scheduleRestoreBurst(delays: [0.25, 0.75, 1.5, 3.0, 5.0, 8.0, 12.0])
    }

    func handleWakeOrScreenChange() {
        refresh()
        scheduleRestoreBurst(delays: [0.15, 0.5, 1.25, 2.5, 5.0, 8.0])
    }

    func syncIfNeeded() {
        guard !isScreenAsleep else { return }
        let current = backend.displays()
        if current.map(\.id) != displays.map(\.id) || current.map(\.method) != displays.map(\.method) {
            refresh()
            return
        }
        for display in displays where display.method != .unavailable {
            if backend.needsBrightnessSync(display.brightness, for: display.id) {
                try? backend.setBrightness(display.brightness, for: display.id)
            }
        }
    }

    func refresh() {
        displays = backend.displays().map { display in
            var updated = display
            if let saved = store.brightness(for: display) {
                updated.brightness = saved
                store.save(saved, for: updated)
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
            save(value, for: displayID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore(_ displayID: UInt32) {
        do {
            try backend.restore(displayID)
            update(displayID: displayID, brightness: 1)
            save(1, for: displayID)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ value: Double, for displayID: UInt32) {
        if let display = displays.first(where: { $0.id == displayID }) {
            store.save(value, for: display)
        } else {
            store.save(value, for: displayID)
        }
    }

    private func startObservingSystemEvents() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let defaultCenter = NotificationCenter.default

        workspaceObserverTokens = [
            observe(NSWorkspace.didWakeNotification, on: workspaceCenter) {
                $0.isScreenAsleep = false
                $0.handleWakeOrScreenChange()
            },
            observe(NSWorkspace.screensDidWakeNotification, on: workspaceCenter) {
                $0.isScreenAsleep = false
                $0.handleWakeOrScreenChange()
            },
            observe(NSWorkspace.screensDidSleepNotification, on: workspaceCenter) {
                $0.isScreenAsleep = true
                $0.cancelPendingRestoreWorkItems()
            },
            observe(NSWorkspace.sessionDidBecomeActiveNotification, on: workspaceCenter) {
                $0.isScreenAsleep = false
                $0.handleWakeOrScreenChange()
            }
        ]

        observerTokens = [
            observe(NSApplication.didChangeScreenParametersNotification, on: defaultCenter) {
                $0.handleWakeOrScreenChange()
            },
            observe(NSWindow.didChangeScreenProfileNotification, on: defaultCenter) {
                $0.handleWakeOrScreenChange()
            },
            observe(NSApplication.didBecomeActiveNotification, on: defaultCenter) {
                $0.syncIfNeeded()
            }
        ]
    }

    private func observe(
        _ name: Notification.Name,
        on center: NotificationCenter,
        handler: @escaping @MainActor (NativeBrightnessModel) -> Void
    ) -> NSObjectProtocol {
        center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                handler(self)
            }
        }
    }

    private func scheduleRestoreBurst(delays: [TimeInterval]) {
        cancelPendingRestoreWorkItems()
        for delay in delays {
            let item = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    guard let self, !self.isScreenAsleep else { return }
                    self.refresh()
                }
            }
            restoreWorkItems.append(item)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
        }
    }

    private func cancelPendingRestoreWorkItems() {
        restoreWorkItems.forEach { $0.cancel() }
        restoreWorkItems.removeAll()
    }

    private func update(displayID: UInt32, brightness: Double) {
        guard let index = displays.firstIndex(where: { $0.id == displayID }) else { return }
        displays[index].brightness = brightness
    }

    private func applySavedBrightness() {
        var appliedAny = false
        var lastError: Error?
        for display in displays {
            guard display.method != .unavailable else { continue }
            let target = store.brightness(for: display) ?? display.brightness
            do {
                try backend.setBrightness(target, for: display.id)
                appliedAny = true
            } catch {
                lastError = error
            }
        }
        if let lastError {
            errorMessage = lastError.localizedDescription
        } else if appliedAny {
            errorMessage = nil
        }
    }
}
