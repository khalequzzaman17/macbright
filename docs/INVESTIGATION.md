# Reference Application Investigation

The installed reference was `/Applications/Brightness Control.app`.

- Bundle ID: `com.splasm.brightnesscontrol`
- Version: 1.1 (110)
- Architecture: x86_64 only; runs under Rosetta 2 on Apple Silicon
- Minimum macOS: 10.11
- UI: a single slider, Smooth toggle, Restore, 0%, 100%, and Escape-to-restore behavior
- Persistence: `interpolateGamma = true`
- Display API evidence: `CGGetActiveDisplayList`, `CGGetDisplayTransferByFormula`, and `CGSetDisplayTransferByFormula`
- No IOKit, DDC/CI, DisplayServices, or CoreDisplay linkage was found

The reference therefore performs gamma-based software dimming rather than guaranteed hardware brightness control. Native Brightness is a clean-room replacement with a modular backend boundary so DDC/CI can be added without coupling it to the SwiftUI UI.
