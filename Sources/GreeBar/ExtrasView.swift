import GreeKit
import SwiftUI

struct ExtrasView: View {
    let model: ACViewModel

    private static let toggles: [(GreeProp, String, String)] = [
        (.turbo, "Turbo", "hare"),
        (.quiet, "Quiet", "speaker.slash"),
        (.sleepSwitch, "Sleep", "moon.zzz"),
        (.light, "Light", "lightbulb"),
        (.health, "Health", "leaf"),
        (.xFan, "X-Fan", "wind"),
        (.freshAir, "Fresh air", "aqi.low"),
        (.energySaving, "Eco", "bolt.badge.checkmark"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LabeledContent("Swing ↕") {
                Picker("Vertical swing", selection: Binding(
                    get: { model.state.verticalSwing },
                    set: { model.setVerticalSwing($0) }
                )) {
                    ForEach(VerticalSwing.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            LabeledContent("Swing ↔") {
                Picker("Horizontal swing", selection: Binding(
                    get: { model.state.horizontalSwing },
                    set: { model.setHorizontalSwing($0) }
                )) {
                    ForEach(HorizontalSwing.allCases) { Text($0.label).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(Self.toggles, id: \.0) { prop, title, symbol in
                    Toggle(isOn: Binding(get: { model.state.flag(prop) }, set: { _ in model.toggle(prop) })) {
                        VStack(spacing: 3) {
                            Image(systemName: symbol)
                            Text(title).font(.caption2).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, minHeight: 34)
                    }
                    .toggleStyle(.button)
                    .help(title)
                }
            }
        }
        .opacity(model.state.power ? 1 : 0.6)
    }
}
