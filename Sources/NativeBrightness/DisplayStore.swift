import Foundation

final class DisplayStore {
    private let defaults: UserDefaults
    private let key = "brightnessByDisplay"
    private let persistentKey = "brightnessByPersistentDisplay"
    private let lastBrightnessKey = "lastSavedBrightness"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func brightness(for displayID: UInt32) -> Double? {
        values[displayID].map(BrightnessMath.clamped)
    }

    func brightness(for display: DisplayInfo) -> Double? {
        if let pid = display.persistentID, let persistent = persistentValues[pid] {
            return BrightnessMath.clamped(persistent)
        }
        if let legacy = values[display.id] {
            return BrightnessMath.clamped(legacy)
        }
        if let last = lastSavedBrightness {
            return last
        }
        return values.max(by: { $0.key < $1.key }).map { BrightnessMath.clamped($0.value) }
    }

    func save(_ value: Double, for displayID: UInt32) {
        let clamped = BrightnessMath.clamped(value)
        saveDisplayID(clamped, for: displayID)
        defaults.set(clamped, forKey: lastBrightnessKey)
    }

    func save(_ value: Double, for display: DisplayInfo) {
        let clamped = BrightnessMath.clamped(value)
        saveDisplayID(clamped, for: display.id)
        if let pid = display.persistentID {
            var updatedPersistent = persistentValues
            updatedPersistent[pid] = clamped
            defaults.set(updatedPersistent, forKey: persistentKey)
        }
        defaults.set(clamped, forKey: lastBrightnessKey)
    }

    private func saveDisplayID(_ clamped: Double, for displayID: UInt32) {
        var updated = values
        updated[displayID] = clamped
        defaults.set(updated.reduce(into: [String: Double]()) { result, entry in
            result[String(entry.key)] = entry.value
        }, forKey: key)
    }

    private var lastSavedBrightness: Double? {
        guard let value = defaults.object(forKey: lastBrightnessKey) as? Double,
              value.isFinite else { return nil }
        return BrightnessMath.clamped(value)
    }

    private var persistentValues: [String: Double] {
        (defaults.dictionary(forKey: persistentKey) as? [String: Double] ?? [:]).reduce(into: [:]) {
            if !$1.key.isEmpty, $1.value.isFinite {
                $0[$1.key] = BrightnessMath.clamped($1.value)
            }
        }
    }

    private var values: [UInt32: Double] {
        (defaults.dictionary(forKey: key) as? [String: Double] ?? [:]).reduce(into: [:]) {
            if let id = UInt32($1.key), $1.value.isFinite {
                $0[id] = BrightnessMath.clamped($1.value)
            }
        }
    }
}
