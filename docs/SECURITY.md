# Security hardening

## Threat model

Native Brightness is a local-only utility. It has no network client, no embedded web content, no third-party runtime dependencies, no shell execution, and no secrets. The main trust boundaries are macOS display identifiers, persisted UserDefaults values, and login-item registration.

## Controls

- Brightness values are finite and clamped to `0...1` before use or persistence.
- Persisted display IDs are parsed as unsigned integers and invalid values are ignored.
- Display writes are allowed only for IDs returned by the current active-display list.
- Gamma formulas are captured from the active display before any write, so restore cannot target an arbitrary display.
- Login-item registration is limited to a bundled app installed under `/Applications`, preventing development copies from registering themselves automatically.
- Login-item registration is idempotent and uses one stable `CFBundleIdentifier`; enabled or approval-pending items are never unregistered and re-created during launch.
- The app is sandboxed and built with the hardened runtime. Release builds should provide `CODE_SIGN_IDENTITY` for Developer ID signing.
- The app uses documented CoreGraphics APIs only and does not request network, accessibility, camera, microphone, or file-system entitlements.

## Release requirements

Build with a Developer ID identity:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" ./Scripts/build-app.sh
codesign --verify --deep --strict --verbose=2 "dist/Native Brightness.app"
spctl --assess --type execute --verbose=2 "dist/Native Brightness.app"
```

The local development build uses ad-hoc signing when `CODE_SIGN_IDENTITY` is not set. It is not a distributable release artifact until Developer ID signing and notarization succeed.
