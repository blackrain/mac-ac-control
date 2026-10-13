import GreeKit
import SwiftUI

/// Guided Wi‑Fi provisioning for a unit that isn't on the network yet.
/// The user switches the Mac's Wi‑Fi by hand; we only detect where it is.
struct WiFiSetupView: View {
    @Bindable var model: ACViewModel
    @Binding var isPresented: Bool

    private enum Step { case reset, join, credentials, rejoin }

    @State private var step: Step = .reset
    @State private var unit: DeviceInfo?
    @State private var ssid = ""
    @State private var password = ""
    @State private var isSending = false
    @State private var error: String?
    @State private var timedOut = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Set up a new AC").font(.subheadline.bold())

            switch step {
            case .reset: resetStep
            case .join: joinStep
            case .credentials: credentialsStep
            case .rejoin: rejoinStep
            }

            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Cancel") { close() }
                if step != .reset {
                    Button("Back", action: back)
                }
                Spacer()
                if step == .reset {
                    Button("Next") { step = .join }.keyboardShortcut(.defaultAction)
                } else if step == .credentials {
                    Button("Send", action: send)
                        .keyboardShortcut(.defaultAction)
                        .disabled(ssid.isEmpty || isSending)
                }
            }
        }
    }

    // MARK: Steps

    private var resetStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            instruction("1", "Turn the AC on with the remote.")
            instruction("2", "Hold **MODE + WIFI** (on some remotes just **WIFI**) for 5–10 seconds until the unit beeps.")
            instruction("3", "The AC now runs its own Wi‑Fi network for about 2 minutes.")
            Text("Already set up in Gree+? You don't need this; use Scan in settings.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var joinStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open the Wi‑Fi menu and join the AC's network. Its name is 8 letters and digits, like **c6a1b2c3**. Password: **12345678**.")
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Waiting for the AC…").font(.caption).foregroundStyle(.secondary)
            }
        }
        .task {
            while !Task.isCancelled {
                if let found = await GreeProvisioning.findSetupUnit() {
                    unit = found
                    step = .credentials
                    return
                }
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    private var credentialsStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let unit {
                Label("Found \(unit.displayName) (\(unit.mac))", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            TextField("Wi‑Fi network name", text: $ssid)
                .textFieldStyle(.roundedBorder)
            SecureField("Wi‑Fi password", text: $password)
                .textFieldStyle(.roundedBorder)
                .onSubmit(send)
            Text("The AC only supports 2.4 GHz networks. Names and passwords are case sensitive.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var rejoinStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Done. Now switch your Mac back to **\(ssid)**.")
            if timedOut {
                Text("The AC hasn't shown up on your network. Check the Wi‑Fi name and password, that the network is 2.4 GHz, and that the router doesn't isolate clients, then start again.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Looking for the AC on your network…").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .task {
            let deadline = Date().addingTimeInterval(90)
            while !Task.isCancelled, Date() < deadline {
                if let found = try? await GreeDiscovery.scan(),
                   let device = found.first(where: { $0.mac == unit?.mac && $0.ip != GreeProvisioning.setupHost }) {
                    model.connect(to: device, key: nil)
                    close()
                    return
                }
                try? await Task.sleep(for: .seconds(3))
            }
            if !Task.isCancelled { timedOut = true }
        }
    }

    private func instruction(_ number: String, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(number).font(.caption.bold()).foregroundStyle(.secondary)
            Text(text).fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Actions

    private func send() {
        guard !ssid.isEmpty, !isSending else { return }
        isSending = true
        error = nil
        Task {
            defer { isSending = false }
            do {
                try await GreeProvisioning.sendWiFi(ssid: ssid, password: password)
                password = ""
                timedOut = false
                step = .rejoin
            } catch {
                self.error = error.localizedDescription
            }
        }
    }

    private func back() {
        error = nil
        switch step {
        case .reset: break
        case .join: step = .reset
        case .credentials: step = .join
        case .rejoin: step = .credentials
        }
    }

    private func close() {
        step = .reset
        unit = nil
        ssid = ""
        password = ""
        error = nil
        timedOut = false
        isPresented = false
    }
}
