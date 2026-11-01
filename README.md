# MacBright

Native Apple Silicon macOS brightness utility written in Swift and SwiftUI.

MacBright provides a small menu-bar control for adjusting display brightness while keeping display-specific settings across restarts and login sessions.

## Features

- Native `arm64` build for Apple Silicon Macs.
- SwiftUI window and menu-bar controls.
- Active display detection through public CoreGraphics APIs.
- Built-in and external display identification.
- Separate saved brightness value for each display.
- Automatic restore of the last saved brightness after login or relaunch.
- Automatic launch at login through `SMAppService.mainApp`.
- Idempotent login-item registration to prevent new duplicate entries.
- Smooth software gamma dimming when hardware brightness is unavailable.
- Capability-aware error handling for unsupported displays.
- Light/dark macOS appearance support.
- No network access, private frameworks, Rosetta, or third-party runtime dependencies.
- MIT licensed.

## Important limitation

The current backend uses documented CoreGraphics transfer-curve APIs for software gamma dimming. Software dimming is not the same as changing a monitor's physical backlight brightness.

DDC/CI hardware control for compatible external monitors is not implemented yet. External monitors may therefore show software dimming rather than true hardware brightness control.

## Requirements

- Apple Silicon Mac: M1, M2, M3, M4, M5, or newer compatible generation.
- macOS 14.0 or newer.
- Xcode Command Line Tools or full Xcode.
- Swift compiler supplied by the installed macOS developer tools.

This project currently builds an arm64 application. Intel Macs are not a supported target.

## Clone the project

```sh
git clone https://github.com/khalequzzaman17/macbright.git
cd macbright
```

## Install build tools

Check whether the command-line tools are already installed:

```sh
xcode-select -p
swift --version
```

If `xcode-select -p` fails, install Apple's Command Line Tools:

```sh
xcode-select --install
```

After installation, reopen Terminal and verify the commands again.

## Build for the current Mac

The included script builds a native arm64 `.app` bundle, adds the application icon, applies the sandbox entitlement, and signs it with the hardened runtime.

```sh
chmod +x Scripts/build-app.sh
./Scripts/build-app.sh
```

The output is:

```text
dist/Native Brightness.app
```

Launch it:

```sh
open "dist/Native Brightness.app"
```

The script uses ad-hoc signing by default, which is suitable for local testing only.

## Install locally

After building, copy the app to Applications:

```sh
ditto "dist/Native Brightness.app" "/Applications/Native Brightness.app"
open "/Applications/Native Brightness.app"
```

The app must be installed under `/Applications` before automatic login startup can be registered. On first launch, approve it in:

`System Settings → General → Login Items`

Only one `Native Brightness` login item should be enabled. If an old development copy appears as a duplicate, remove both old entries once and relaunch the current `/Applications` copy. The current code uses one stable bundle identifier and does not unregister/re-register an enabled item during launch.

## Developer ID signing

For a distributable build, provide a Developer ID Application identity:

```sh
security find-identity -v -p codesigning
CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  ./Scripts/build-app.sh
```

Verify the signed result:

```sh
codesign --verify --deep --strict --verbose=2 \
  "dist/Native Brightness.app"

spctl --assess --type execute --verbose=2 \
  "dist/Native Brightness.app"
```

Notarization and `.dmg` creation require an Apple Developer account, signing identity, and a separate release packaging workflow. Do not distribute the ad-hoc build as a release artifact.

## Testing and verification

Run a source type-check:

```sh
swiftc -target arm64-apple-macosx14.0 -parse-as-library -typecheck \
  -framework SwiftUI \
  -framework AppKit \
  -framework CoreGraphics \
  -framework ServiceManagement \
  Sources/NativeBrightness/*.swift
```

Run the included XCTest suite when using a complete Xcode/SwiftPM environment:

```sh
swift test
```

The source package and XCTest tests are included for Xcode/SwiftPM workflows. The direct build script is used because some Command Line Tools installations fail while linking SwiftPM manifests.

## Usage

1. Launch MacBright from `/Applications`.
2. Open the sun icon in the menu bar.
3. Select the display-specific slider.
4. Move the slider to apply software dimming.
5. Quit and relaunch the app to verify saved restoration.
6. Approve automatic startup in Login Items if macOS requests it.

The app shows whether the selected display supports the current software gamma backend. A display marked unavailable is not modified.

## Project layout

```text
Sources/NativeBrightness/  SwiftUI app and display-control source
Tests/                     XCTest coverage for pure logic
Resources/                 Info.plist, entitlements, and icon
Scripts/                   Local build script
docs/                      Investigation and security documentation
```

## Compatibility status

| Target | Status |
|---|---|
| M4 arm64 | Build and UI verified on a Mac mini; physical display control verified through the active display backend |
| M1/M2/M3/M5 | Not physically tested in this environment; no Intel-only code is used |
| Built-in display | Software gamma backend implemented; hardware capability varies by Mac |
| External display | Software gamma fallback implemented; DDC/CI hardware control not implemented |

## Security

See [docs/SECURITY.md](docs/SECURITY.md) for the threat model, sandbox scope, input validation, login-item policy, and release-signing requirements.

## Reference investigation

The clean-room comparison with the installed legacy Brightness Control app is documented in [docs/INVESTIGATION.md](docs/INVESTIGATION.md).

## License

This project is released under the [MIT License](LICENSE).
