import Foundation

final class DisplayStore {
    private let defaults: UserDefaults
    private let key = "brightnessByDisplay"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func brightness(for displayID: UInt32) -> Double? {
        values[displayID].map(BrightnessMath.clamped)
    }

    func save(_ value: Double, for displayID: UInt32) {
        var updated = values
        updated[displayID] = BrightnessMath.clamped(value)
        defaults.set(updated.reduce(into: [String: Double]()) { result, entry in
            result[String(entry.key)] = entry.value
        }, forKey: key)
    }

    private var values: [UInt32: Double] {
        (defaults.dictionary(forKey: key) as? [String: Double] ?? [:]).reduce(into: [:]) {
            if let id = UInt32($1.key), $1.value.isFinite {
                $0[id] = BrightnessMath.clamped($1.value)
            }
        }
    }
}
