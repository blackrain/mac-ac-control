import Foundation

/// Puts a freshly reset unit on a Wi‑Fi network. After a Wi‑Fi reset the
/// module runs its own access point (password `12345678`) at 192.168.1.1;
/// the Mac must be joined to it while these calls run.
public enum GreeProvisioning {
    public static let setupHost = GreeProtocol.setupHost

    /// Returns the unit if the Mac is currently on its setup access point.
    public static func findSetupUnit(timeout: TimeInterval = 1) async -> DeviceInfo? {
        let found = try? await GreeDiscovery.scan(hosts: [setupHost], timeout: timeout)
        return found?.first
    }

    /// Sends the home network's credentials. Some firmware acknowledges with
    /// `{"t":"ret","r":200}`, some say nothing, so a missing reply is not an error.
    public static func sendWiFi(ssid: String, password: String, host: String = setupHost) async throws {
        let request = GreeProtocol.wlanRequest(ssid: ssid, password: password)
        try await UDPSocket.run {
            let socket = try UDPSocket()
            try socket.send(request, to: host, port: GreeProtocol.port)
            _ = try socket.receive(timeout: 2)
        }
    }
}
