import Foundation
import ServiceManagement

enum StartupManager {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func ensureSingleRegistration() {
        guard isInstalledApplication else { return }

        // SMAppService.mainApp is keyed to this app's stable bundle identity.
        // Never unregister/re-register an enabled or approval-pending item:
        // doing so can create duplicate entries while macOS reconciles state.
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return
        case .notRegistered:
            registerOnce()
        case .notFound:
            return
        @unknown default:
            return
        }
    }

    private static func registerOnce() {
        do {
            try SMAppService.mainApp.register()
        } catch {
            // Registration may be denied until the user approves the login item
            // in System Settings. The app remains usable without startup mode.
        }
    }

    private static var isInstalledApplication: Bool {
        let path = Bundle.main.bundleURL.resolvingSymlinksInPath().path
        return path.hasPrefix("/Applications/") && path.hasSuffix(".app")
    }
}
