import SwiftUI

struct ContentView: View {
    @ObservedObject var model: NativeBrightnessModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Native Brightness", systemImage: "sun.max.fill")
                    .font(.headline.weight(.semibold))
                Spacer()
                Button { model.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh displays")
            }

            if model.displays.isEmpty {
                ContentUnavailableView("No active displays", systemImage: "display.2")
            } else {
                ForEach(model.displays) { display in
                    DisplayRow(display: display, model: model)
                }
            }

            if let errorMessage = model.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
                    .font(.footnote)
            }

            Divider()
            VStack(alignment: .leading, spacing: 4) {
                Text("Software gamma dimming is used when hardware control is unavailable.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Developed with ❤️ by Khalequzzaman")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(width: 360)
        .fixedSize(horizontal: false, vertical: true)
    }
}

private struct DisplayRow: View {
    let display: DisplayInfo
    @ObservedObject var model: NativeBrightnessModel

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Label(display.name, systemImage: display.isBuiltIn ? "laptopcomputer" : "display")
                    .font(.headline)
                Spacer()
                Text("\(BrightnessMath.percentage(display.brightness))%")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { display.brightness },
                set: { model.setBrightness($0, for: display.id) }
            ), in: 0...1)
            HStack {
                Text(display.supportDescription)
                    .font(.caption)
                    .foregroundStyle(display.method == .unavailable ? .orange : .secondary)
                Spacer()
                Button("Restore") { model.restore(display.id) }
                    .buttonStyle(.borderless)
                    .disabled(display.method == .unavailable)
            }
        }
        .padding(.vertical, 2)
    }
}
