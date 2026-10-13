import GreeKit
import SwiftUI

struct PopoverView: View {
    @Bindable var model: ACViewModel
    @State private var showSettings = false
    @State private var showWiFiSetup = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            Divider()
            // All pages stay in the layout so the panel never changes height:
            // MenuBarExtra windows mis-position themselves when their content resizes.
            ZStack(alignment: .topLeading) {
                page(visible: !showSettings && !showWiFiSetup && model.info != nil) {
                    VStack(alignment: .leading, spacing: 14) {
                        controls
                        ExtrasView(model: model)
                    }
                }
                page(visible: !showSettings && !showWiFiSetup && model.info == nil) {
                    ContentUnavailableView {
                        Label("No AC selected", systemImage: "air.conditioner.horizontal")
                    } description: {
                        Text(statusText)
                    } actions: {
                        Button("Set up…") { showSettings = true }
                        Button("Set up a new AC…") { showWiFiSetup = true }
                    }
                }
                page(visible: showSettings && !showWiFiSetup) {
                    SettingsView(model: model, isPresented: $showSettings, showWiFiSetup: $showWiFiSetup)
                }
                page(visible: showWiFiSetup) {
                    WiFiSetupView(model: model, isPresented: $showWiFiSetup)
                }
            }
            Divider()
            footer
        }
        .padding(16)
        .frame(width: 340)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(model.info?.displayName ?? "Gree AC")
                    .font(.headline)
                if let room = model.state.roomTemp {
                    Label("Room \(room)°C", systemImage: "thermometer.medium")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("Power", isOn: Binding(get: { model.state.power }, set: { model.setPower($0) }))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(model.info == nil)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { adjustTemp(-1) } label: { Image(systemName: "minus") }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                Spacer()
                Text(model.state.targetTemp.map { "\($0)°" } ?? "–")
                    .font(.system(size: 44, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.state.targetTemp)
                Spacer()
                Button { adjustTemp(1) } label: { Image(systemName: "plus") }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
            }
            .disabled(model.state.mode == .fan)

            Picker("Mode", selection: Binding(get: { model.state.mode }, set: { model.setMode($0) })) {
                ForEach(ACMode.allCases) { mode in
                    Image(systemName: mode.symbol).help(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text(model.state.mode.label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            LabeledContent("Fan") {
                Picker("Fan", selection: Binding(get: { model.state.fanSpeed }, set: { model.setFan($0) })) {
                    ForEach(FanSpeed.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
        }
        .opacity(model.state.power ? 1 : 0.6)
    }

    private var footer: some View {
        HStack {
            Text(statusText)
                .font(.caption)
                .foregroundStyle(isError ? .red : .secondary)
                .lineLimit(2)
            Spacer()
            if model.isBusy || model.phase == .discovering || model.phase == .connecting {
                ProgressView().controlSize(.small)
            }
            Button { Task { await model.refresh() } } label: { Image(systemName: "arrow.clockwise") }
                .help("Refresh")
            Button { showSettings.toggle(); showWiFiSetup = false } label: { Image(systemName: "gearshape") }
                .help("Settings")
            Button { NSApplication.shared.terminate(nil) } label: { Image(systemName: "power") }
                .help("Quit")
        }
        .buttonStyle(.borderless)
    }

    private func page<Content: View>(visible: Bool, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .opacity(visible ? 1 : 0)
            .allowsHitTesting(visible)
            .accessibilityHidden(!visible)
    }

    private var isError: Bool {
        if case .failed = model.phase { true } else { false }
    }

    private var statusText: String {
        switch model.phase {
        case .idle: "Not connected"
        case .discovering: "Searching…"
        case .connecting: "Connecting…"
        case .connected:
            if let date = model.lastUpdate { "Updated \(date.formatted(date: .omitted, time: .shortened))" } else { "Connected" }
        case .failed(let msg): msg
        }
    }

    private func adjustTemp(_ delta: Int) {
        model.setTemperature((model.state.targetTemp ?? 24) + delta)
    }
}
