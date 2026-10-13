import GreeKit
import SwiftUI

struct SettingsView: View {
    @Bindable var model: ACViewModel
    @Binding var isPresented: Bool
    @State private var manualIP = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Devices on network").font(.subheadline.bold())
                Spacer()
                Button("Scan") { Task { await model.discover() } }
                    .disabled(model.phase == .discovering)
            }

            if model.discovered.isEmpty {
                Text("No devices yet. Press Scan.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.discovered) { device in
                    Button {
                        model.connect(to: device, key: nil)
                        isPresented = false
                    } label: {
                        HStack {
                            Image(systemName: device.mac == model.info?.mac ? "checkmark.circle.fill" : "circle")
                            VStack(alignment: .leading) {
                                Text(device.displayName)
                                Text("\(device.ip) · \(device.mac) · \(device.cipher.rawValue.uppercased())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                TextField("AC IP address", text: $manualIP)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(connectManual)
                Button("Connect", action: connectManual)
                    .disabled(manualIP.isEmpty)
            }

            Toggle("Launch at login", isOn: $model.launchAtLogin)

            if let info = model.info {
                Text("Firmware \(info.firmware.isEmpty ? "unknown" : info.firmware)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Done") { isPresented = false }
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func connectManual() {
        let ip = manualIP.trimmingCharacters(in: .whitespaces)
        guard !ip.isEmpty else { return }
        Task {
            await model.discover(host: ip)
            if model.phase != .discovering, model.info?.ip == ip { isPresented = false }
        }
    }
}
