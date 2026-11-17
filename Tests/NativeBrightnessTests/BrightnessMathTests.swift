import XCTest
@testable import NativeBrightness

private final class MockDisplayBackend: DisplayBackend {
    var stubDisplays: [DisplayInfo]
    var appliedBrightness: [(displayID: UInt32, value: Double)] = []
    var syncNeededByDisplay: [UInt32: Bool] = [:]

    init(displays: [DisplayInfo]) {
        self.stubDisplays = displays
    }

    func displays() -> [DisplayInfo] {
        stubDisplays
    }

    func setBrightness(_ value: Double, for displayID: UInt32) throws {
        appliedBrightness.append((displayID, value))
    }

    func restore(_ displayID: UInt32) throws {
        appliedBrightness.append((displayID, 1.0))
    }

    func needsBrightnessSync(_ value: Double, for displayID: UInt32) -> Bool {
        syncNeededByDisplay[displayID] ?? false
    }
}

final class BrightnessMathTests: XCTestCase {
    func testClampsBrightnessToSafeRange() {
        XCTAssertEqual(BrightnessMath.clamped(-0.2), 0)
        XCTAssertEqual(BrightnessMath.clamped(1.2), 1)
        XCTAssertEqual(BrightnessMath.clamped(0.42), 0.42)
        XCTAssertEqual(BrightnessMath.clamped(.infinity), 1)
        XCTAssertEqual(BrightnessMath.clamped(.nan), 1)
    }

    func testRoundsPercentageForDisplay() {
        XCTAssertEqual(BrightnessMath.percentage(0.0), 0)
        XCTAssertEqual(BrightnessMath.percentage(0.504), 50)
        XCTAssertEqual(BrightnessMath.percentage(0.995), 100)
    }

    func testStoreRestoresBrightnessAcrossDisplayIDChangeViaPersistentID() {
        let suiteName = "com.nativebrightness.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DisplayStore(defaults: defaults)
        let beforeSleep = DisplayInfo(
            id: 1,
            persistentID: "uuid:08298D9D-DDFE-4408-8654-783980B5A564",
            name: "External Display",
            isBuiltIn: false,
            method: .gamma,
            brightness: 1.0
        )
        store.save(0.45, for: beforeSleep)

        let afterWake = DisplayInfo(
            id: 2,
            persistentID: "uuid:08298D9D-DDFE-4408-8654-783980B5A564",
            name: "External Display",
            isBuiltIn: false,
            method: .gamma,
            brightness: 1.0
        )
        let restored = store.brightness(for: afterWake)
        XCTAssertNotNil(restored)
        XCTAssertEqual(restored ?? 0, 0.45, accuracy: 0.0001)
    }

    @MainActor
    func testModelSyncIfNeededReappliesBrightnessWhenWindowServerResetsGamma() {
        let suiteName = "com.nativebrightness.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DisplayStore(defaults: defaults)
        let display = DisplayInfo(
            id: 2,
            persistentID: "uuid:ABC",
            name: "External Display",
            isBuiltIn: false,
            method: .gamma,
            brightness: 1.0
        )
        store.save(0.55, for: display)

        let backend = MockDisplayBackend(displays: [display])
        let model = NativeBrightnessModel(backend: backend, store: store, observeSystemEvents: false)
        XCTAssertEqual(backend.appliedBrightness.count, 1)
        XCTAssertEqual(backend.appliedBrightness.last?.value ?? 0, 0.55, accuracy: 0.0001)

        backend.appliedBrightness.removeAll()
        backend.syncNeededByDisplay[2] = false
        model.syncIfNeeded()
        XCTAssertTrue(backend.appliedBrightness.isEmpty)

        backend.syncNeededByDisplay[2] = true
        model.syncIfNeeded()
        XCTAssertEqual(backend.appliedBrightness.count, 1)
        XCTAssertEqual(backend.appliedBrightness.last?.displayID, 2)
        XCTAssertEqual(backend.appliedBrightness.last?.value ?? 0, 0.55, accuracy: 0.0001)
    }

    @MainActor
    func testModelHandleWakeOrScreenChangeRefreshesAndReappliesSavedBrightness() {
        let suiteName = "com.nativebrightness.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = DisplayStore(defaults: defaults)
        let initialDisplay = DisplayInfo(
            id: 1,
            persistentID: "uuid:MONITOR-1",
            name: "Studio Display",
            isBuiltIn: false,
            method: .gamma,
            brightness: 1.0
        )
        store.save(0.62, for: initialDisplay)

        let backend = MockDisplayBackend(displays: [initialDisplay])
        let model = NativeBrightnessModel(backend: backend, store: store, observeSystemEvents: false)
        backend.appliedBrightness.removeAll()

        // Simulate macOS assigning a new CGDirectDisplayID upon wake.
        backend.stubDisplays = [
            DisplayInfo(
                id: 3,
                persistentID: "uuid:MONITOR-1",
                name: "Studio Display",
                isBuiltIn: false,
                method: .gamma,
                brightness: 1.0
            )
        ]

        model.handleWakeOrScreenChange()

        XCTAssertEqual(model.displays.first?.id, 3)
        XCTAssertEqual(model.displays.first?.brightness ?? 0, 0.62, accuracy: 0.0001)
        XCTAssertEqual(backend.appliedBrightness.count, 1)
        XCTAssertEqual(backend.appliedBrightness.last?.displayID, 3)
        XCTAssertEqual(backend.appliedBrightness.last?.value ?? 0, 0.62, accuracy: 0.0001)
    }
}
