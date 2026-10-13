import GreeKit
import SwiftUI

@main
struct GreeBarApp: App {
    @State private var model = ACViewModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    let model: ACViewModel

    var body: some View {
        let state = model.state
        if model.phase == .connected, state.power {
            Image(systemName: state.mode.symbol)
            if let temp = state.targetTemp {
                Text("\(temp)°")
            }
        } else {
            Image(systemName: "air.conditioner.horizontal")
        }
    }
}
