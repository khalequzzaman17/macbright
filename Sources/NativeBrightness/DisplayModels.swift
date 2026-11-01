import Foundation

enum BrightnessControlMethod: String, Codable, Sendable {
    case gamma = "Software gamma"
    case ddc = "DDC/CI"
    case unavailable = "Unavailable"
}

struct DisplayInfo: Identifiable, Equatable, Sendable {
    let id: UInt32
    let name: String
    let isBuiltIn: Bool
    let method: BrightnessControlMethod
    var brightness: Double
    var isOnline: Bool = true

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
