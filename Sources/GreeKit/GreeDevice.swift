import Foundation

/// A bound connection to one AC unit.
public actor GreeDevice {
    public nonisolated let info: DeviceInfo
    public private(set) var key: String?

    public init(info: DeviceInfo, key: String? = nil) {
        self.info = info
        self.key = key
    }

    /// Exchanges the generic key for the device's own key.
    @discardableResult
    public func bind() async throws -> String {
        let payload: [String: Any] = ["mac": info.mac, "t": "bind", "uid": 0]
        let reply = try await request(payload, key: info.cipher.genericKey, i: 1)
        guard reply["t"] as? String == "bindok", let newKey = reply["key"] as? String else {
            throw GreeError.badResponse("bind: \(reply)")
        }
        key = newKey
        return newKey
    }

    public func status() async throws -> DeviceState {
        let cols = GreeProp.allCases.map(\.rawValue)
        let reply = try await authorized(["cols": cols, "mac": info.mac, "t": "status"])
        guard reply["t"] as? String == "dat",
              let replyCols = reply["cols"] as? [String],
              let dat = reply["dat"] as? [Any]
        else { throw GreeError.badResponse("status: \(reply)") }
        return DeviceState(cols: replyCols, dat: dat)
    }

    public func set(_ values: [GreeProp: Int]) async throws {
        guard !values.isEmpty else { return }
        let pairs = values.sorted { $0.key.rawValue < $1.key.rawValue }
        let payload: [String: Any] = [
            "opt": pairs.map(\.key.rawValue),
            "p": pairs.map(\.value),
            "t": "cmd",
        ]
        let reply = try await authorized(payload)
        guard reply["t"] as? String == "res" else { throw GreeError.badResponse("cmd: \(reply)") }
    }

    /// Sends with the device key, binding first if needed and re-binding once if the key stopped working.
    private func authorized(_ payload: [String: Any]) async throws -> [String: Any] {
        let current: String
        if let key { current = key } else { current = try await bind() }
        do {
            return try await request(payload, key: current, i: 0)
        } catch GreeError.decryptFailed, GreeError.timeout {
            let fresh = try await bind()
            return try await request(payload, key: fresh, i: 0)
        }
    }

    private func request(_ payload: [String: Any], key: String, i: Int) async throws -> [String: Any] {
        let data = try GreeProtocol.envelope(payload, mac: info.mac, key: key, cipher: info.cipher, i: i)
        let host = info.ip
        let reply: Data = try await UDPSocket.run {
            let socket = try UDPSocket()
            for _ in 0..<3 {
                try socket.send(data, to: host, port: GreeProtocol.port)
                if let (reply, _) = try socket.receive(timeout: 2) { return reply }
            }
            throw GreeError.timeout
        }
        return try GreeProtocol.open(reply, key: key, cipher: info.cipher)
    }
}
