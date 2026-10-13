import Foundation

public enum GreeDiscovery {
    /// Sends a scan to every broadcast address (or to `hosts`, if given) and
    /// collects replies for `timeout` seconds.
    public static func scan(hosts: [String]? = nil, timeout: TimeInterval = 3) async throws -> [DeviceInfo] {
        let targets = hosts ?? (UDPSocket.broadcastAddresses() + ["255.255.255.255"])
        return try await UDPSocket.run {
            let socket = try UDPSocket(broadcast: true)
            for target in targets {
                try? socket.send(GreeProtocol.scanRequest(), to: target, port: GreeProtocol.port)
            }
            var found: [String: DeviceInfo] = [:]
            let deadline = Date().addingTimeInterval(timeout)
            while true {
                let remaining = deadline.timeIntervalSinceNow
                guard remaining > 0, let (data, host) = try socket.receive(timeout: remaining) else { break }
                if let info = parseScanReply(data, host: host) {
                    found[info.mac] = info
                }
            }
            return found.values.sorted { $0.mac < $1.mac }
        }
    }

    static func parseScanReply(_ data: Data, host: String) -> DeviceInfo? {
        guard let env = try? GreeProtocol.jsonObject(data), env["pack"] is String else { return nil }
        let cipher: GreeCipher = env["tag"] != nil ? .gcm : .ecb
        // Fall back to the other cipher in case the module doesn't follow the tag convention.
        for c in [cipher, cipher == .gcm ? .ecb : .gcm] {
            guard let pack = try? GreeProtocol.open(data, key: c.genericKey, cipher: c),
                  pack["t"] as? String == "dev"
            else { continue }
            let mac = (pack["mac"] as? String) ?? (env["cid"] as? String) ?? ""
            guard !mac.isEmpty else { return nil }
            return DeviceInfo(
                mac: mac,
                name: pack["name"] as? String ?? "",
                ip: host,
                firmware: pack["ver"] as? String ?? "",
                cipher: c
            )
        }
        return nil
    }
}
