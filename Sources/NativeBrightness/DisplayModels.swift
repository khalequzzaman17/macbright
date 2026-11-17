import Foundation

enum BrightnessControlMethod: String, Codable, Sendable {
    case gamma = "Software gamma"
    case ddc = "DDC/CI"
    case unavailable = "Unavailable"
}

struct DisplayInfo: Identifiable, Equatable, Sendable {
    let id: UInt32
    let persistentID: String?
    let name: String
    let isBuiltIn: Bool
    let method: BrightnessControlMethod
    var brightness: Double
    var isOnline: Bool = true

    init(
        id: UInt32,
        persistentID: String? = nil,
        name: String,
        isBuiltIn: Bool,
        method: BrightnessControlMethod,
        brightness: Double,
        isOnline: Bool = true
    ) {
        self.id = id
        self.persistentID = persistentID
        self.name = name
        self.isBuiltIn = isBuiltIn
        self.method = method
        self.brightness = brightness
        self.isOnline = isOnline
    }

    var supportDescription: String {
        switch method {
        case .gamma:
            return "Software dimming available"
        case .ddc:
            return "Hardware control available"
        case .unavailable:
            return "Brightness control unavailable"
        }
    }
}

enum BrightnessMath {
    static func clamped(_ value: Double) -> Double {
        guard value.isFinite else { return 1 }
        return min(max(value, 0), 1)
    }

    static func percentage(_ value: Double) -> Int {
        Int((clamped(value) * 100).rounded())
    }
}
