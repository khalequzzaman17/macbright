import AppKit
import CoreGraphics
import Foundation

protocol DisplayBackend: AnyObject {
    func displays() -> [DisplayInfo]
    func setBrightness(_ value: Double, for displayID: UInt32) throws
    func restore(_ displayID: UInt32) throws
    func needsBrightnessSync(_ value: Double, for displayID: UInt32) -> Bool
}

extension DisplayBackend {
    func needsBrightnessSync(_ value: Double, for displayID: UInt32) -> Bool {
        false
    }
}

enum DisplayBackendError: LocalizedError {
    case unableToReadDisplayList
    case unsupportedDisplay(UInt32)
    case gammaReadFailed(UInt32, CGError)
    case gammaWriteFailed(UInt32, CGError)

    var errorDescription: String? {
        switch self {
        case .unableToReadDisplayList:
            return "Active displays could not be read."
        case let .unsupportedDisplay(id):
            return "Display \(id) does not expose software brightness control."
        case let .gammaReadFailed(id, error):
            return "Could not read the transfer curve for display \(id) (error \(error.rawValue))."
        case let .gammaWriteFailed(id, error):
            return "Could not change display \(id) (error \(error.rawValue))."
        }
    }
}

final class GammaDisplayBackend: DisplayBackend {
    private struct TransferFormula {
        var redMin: CGGammaValue
        var redMax: CGGammaValue
        var redGamma: CGGammaValue
        var greenMin: CGGammaValue
        var greenMax: CGGammaValue
        var greenGamma: CGGammaValue
        var blueMin: CGGammaValue
        var blueMax: CGGammaValue
        var blueGamma: CGGammaValue
    }

    private var originalFormulas: [UInt32: TransferFormula] = [:]

    func displays() -> [DisplayInfo] {
        let ids = activeDisplayIDs()
        return ids.map { id in
            let name = displayName(for: id)
            let method: BrightnessControlMethod = formula(for: id) == nil ? .unavailable : .gamma
            return DisplayInfo(
                id: id,
                persistentID: persistentDisplayID(for: id),
                name: name,
                isBuiltIn: CGDisplayIsBuiltin(id) != 0,
                method: method,
                brightness: 1
            )
        }
    }

    func setBrightness(_ value: Double, for displayID: UInt32) throws {
        guard activeDisplayIDs().contains(displayID) else {
            throw DisplayBackendError.unsupportedDisplay(displayID)
        }
        guard let formula = formula(for: displayID) else {
            throw DisplayBackendError.unsupportedDisplay(displayID)
        }

        let level = CGGammaValue(BrightnessMath.clamped(value))
        let error = CGSetDisplayTransferByFormula(
            displayID,
            formula.redMin, max(formula.redMin + 0.0001, formula.redMax * level), formula.redGamma,
            formula.greenMin, max(formula.greenMin + 0.0001, formula.greenMax * level), formula.greenGamma,
            formula.blueMin, max(formula.blueMin + 0.0001, formula.blueMax * level), formula.blueGamma
        )
        guard error == .success else {
            throw DisplayBackendError.gammaWriteFailed(displayID, error)
        }
    }

    func restore(_ displayID: UInt32) throws {
        guard activeDisplayIDs().contains(displayID) else {
            throw DisplayBackendError.unsupportedDisplay(displayID)
        }
        guard let formula = formula(for: displayID) else {
            throw DisplayBackendError.unsupportedDisplay(displayID)
        }
        let error = CGSetDisplayTransferByFormula(
            displayID,
            formula.redMin, formula.redMax, formula.redGamma,
            formula.greenMin, formula.greenMax, formula.greenGamma,
            formula.blueMin, formula.blueMax, formula.blueGamma
        )
        guard error == .success else {
            throw DisplayBackendError.gammaWriteFailed(displayID, error)
        }
    }

    func needsBrightnessSync(_ value: Double, for displayID: UInt32) -> Bool {
        guard activeDisplayIDs().contains(displayID),
              let base = formula(for: displayID),
              let live = readFormula(for: displayID) else {
            return false
        }
        let level = CGGammaValue(BrightnessMath.clamped(value))
        let expectedRedMax = max(base.redMin + 0.0001, base.redMax * level)
        let expectedGreenMax = max(base.greenMin + 0.0001, base.greenMax * level)
        let expectedBlueMax = max(base.blueMin + 0.0001, base.blueMax * level)
        return abs(live.redMax - expectedRedMax) > 0.015
            || abs(live.greenMax - expectedGreenMax) > 0.015
            || abs(live.blueMax - expectedBlueMax) > 0.015
    }

    private func formula(for id: UInt32) -> TransferFormula? {
        if let existing = originalFormulas[id] { return existing }
        guard let rawFormula = readFormula(for: id) else { return nil }
        let normalized = Self.normalizedBaseline(rawFormula)
        originalFormulas[id] = normalized
        return normalized
    }

    private static func normalizedBaseline(_ raw: TransferFormula) -> TransferFormula {
        func clampMin(_ value: CGGammaValue) -> CGGammaValue {
            guard value.isFinite else { return 0.0 }
            return min(max(value, 0.0), 0.5)
        }

        func sanitizeGamma(_ value: CGGammaValue) -> CGGammaValue {
            guard value.isFinite, value > 0.05 else { return 1.0 }
            return value
        }

        let rRaw = raw.redMax.isFinite ? max(raw.redMax, 0) : 0
        let gRaw = raw.greenMax.isFinite ? max(raw.greenMax, 0) : 0
        let bRaw = raw.blueMax.isFinite ? max(raw.blueMax, 0) : 0
        let peak = max(rRaw, max(gRaw, bRaw))

        let rMax: CGGammaValue
        let gMax: CGGammaValue
        let bMax: CGGammaValue
        if !peak.isFinite || peak <= 0.05 {
            rMax = 1.0
            gMax = 1.0
            bMax = 1.0
        } else if peak < 1.0 {
            rMax = rRaw / peak
            gMax = gRaw / peak
            bMax = bRaw / peak
        } else {
            rMax = rRaw
            gMax = gRaw
            bMax = bRaw
        }

        return TransferFormula(
            redMin: clampMin(raw.redMin),
            redMax: rMax,
            redGamma: sanitizeGamma(raw.redGamma),
            greenMin: clampMin(raw.greenMin),
            greenMax: gMax,
            greenGamma: sanitizeGamma(raw.greenGamma),
            blueMin: clampMin(raw.blueMin),
            blueMax: bMax,
            blueGamma: sanitizeGamma(raw.blueGamma)
        )
    }

    private func persistentDisplayID(for id: UInt32) -> String {
        if let uuid = CGDisplayCreateUUIDFromDisplayID(id)?.takeRetainedValue(),
           let uuidString = CFUUIDCreateString(nil, uuid) as String?,
           !uuidString.isEmpty {
            return "uuid:\(uuidString)"
        }
        let builtInFlag = CGDisplayIsBuiltin(id) != 0 ? 1 : 0
        return "hw:\(builtInFlag)-\(CGDisplayVendorNumber(id))-\(CGDisplayModelNumber(id))-\(CGDisplaySerialNumber(id))-\(CGDisplayUnitNumber(id))"
    }

    private func readFormula(for id: UInt32) -> TransferFormula? {
        var redMin: CGGammaValue = 0
        var redMax: CGGammaValue = 0
        var redGamma: CGGammaValue = 0
        var greenMin: CGGammaValue = 0
        var greenMax: CGGammaValue = 0
        var greenGamma: CGGammaValue = 0
        var blueMin: CGGammaValue = 0
        var blueMax: CGGammaValue = 0
        var blueGamma: CGGammaValue = 0
        let error = CGGetDisplayTransferByFormula(
            id, &redMin, &redMax, &redGamma,
            &greenMin, &greenMax, &greenGamma,
            &blueMin, &blueMax, &blueGamma
        )
        guard error == .success else { return nil }
        return TransferFormula(
            redMin: redMin, redMax: redMax, redGamma: redGamma,
            greenMin: greenMin, greenMax: greenMax, greenGamma: greenGamma,
            blueMin: blueMin, blueMax: blueMax, blueGamma: blueGamma
        )
    }

    private func activeDisplayIDs() -> [UInt32] {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return [] }
        var ids = Array(repeating: CGDirectDisplayID(0), count: Int(count))
        guard CGGetActiveDisplayList(count, &ids, &count) == .success else { return [] }
        return ids.map { UInt32($0) }
    }

    private func displayName(for id: UInt32) -> String {
        if let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == id
        }), !screen.localizedName.isEmpty {
            return screen.localizedName
        }
        return CGDisplayIsBuiltin(id) != 0 ? "Built-in Display" : "External Display"
    }
}
