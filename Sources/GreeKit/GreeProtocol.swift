import Foundation

/// JSON envelope helpers for the Gree LAN protocol (UDP port 7000).
enum GreeProtocol {
    static let port: UInt16 = 7000

    static func scanRequest() -> Data {
        Data(#"{"t":"scan"}"#.utf8)
    }

    /// Wraps an inner payload into the encrypted `pack` envelope.
    static func envelope(_ payload: [String: Any], mac: String, key: String, cipher: GreeCipher, i: Int) throws -> Data {
        let plain = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let enc = try GreeCrypto.encrypt(plain, key: key, cipher: cipher)
        var env: [String: Any] = [
            "cid": "app", "i": i, "t": "pack", "tcid": mac, "uid": 0, "pack": enc.pack,
        ]
        if let tag = enc.tag { env["tag"] = tag }
        return try JSONSerialization.data(withJSONObject: env, options: [.sortedKeys])
    }

    /// Parses an envelope and decrypts its `pack`.
    static func open(_ data: Data, key: String, cipher: GreeCipher) throws -> [String: Any] {
        let env = try jsonObject(data)
        guard let pack = env["pack"] as? String else {
            throw GreeError.badResponse(String(decoding: data, as: UTF8.self))
        }
        let plain = try GreeCrypto.decrypt(EncryptedPack(pack: pack, tag: env["tag"] as? String), key: key, cipher: cipher)
        return try jsonObject(plain)
    }

    static func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw GreeError.badResponse(String(decoding: data, as: UTF8.self))
        }
        return obj
    }
}

/// A unit found on the network.
public struct DeviceInfo: Codable, Sendable, Hashable, Identifiable {
    public var mac: String
    public var name: String
    public var ip: String
    public var firmware: String
    public var cipher: GreeCipher

    public var id: String { mac }

    public init(mac: String, name: String, ip: String, firmware: String, cipher: GreeCipher) {
        self.mac = mac
        self.name = name
        self.ip = ip
        self.firmware = firmware
        self.cipher = cipher
    }

    /// Gree+ shows units as e.g. "ACd55e" (AC + last 4 MAC hex digits) when unnamed.
    public var displayName: String {
        name.isEmpty ? "AC\(mac.suffix(4))" : name
    }
}
