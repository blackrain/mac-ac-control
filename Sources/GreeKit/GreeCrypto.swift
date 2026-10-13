import CommonCrypto
import CryptoKit
import Foundation

/// Encryption scheme used by the Wi-Fi module. Older firmware uses AES-ECB,
/// newer (Gree+ era) firmware uses AES-GCM with a separate `tag` field.
public enum GreeCipher: String, Codable, Sendable {
    case ecb
    case gcm

    /// Key used before the device has handed out its own key (scan + bind).
    public var genericKey: String {
        switch self {
        case .ecb: "a3K8Bx%2r8Y7#xDh"
        case .gcm: "{yxAHAY_Lm6pbC/v"
        }
    }
}

public enum GreeError: Error, LocalizedError {
    case socket(String)
    case timeout
    case badKey
    case decryptFailed
    case badResponse(String)
    case notFound

    public var errorDescription: String? {
        switch self {
        case .socket(let msg): "Network error: \(msg)"
        case .timeout: "The AC did not respond"
        case .badKey: "Invalid encryption key"
        case .decryptFailed: "Could not decrypt the AC response"
        case .badResponse(let msg): "Unexpected response: \(msg)"
        case .notFound: "No AC found on the network"
        }
    }
}

public struct EncryptedPack: Sendable, Equatable {
    public var pack: String
    public var tag: String?
}

public enum GreeCrypto {
    static let gcmNonce = Data([0x54, 0x40, 0x78, 0x44, 0x49, 0x67, 0x5A, 0x51, 0x6C, 0x5E, 0x63, 0x13])
    static let gcmAAD = Data("qualcomm-test".utf8)

    public static func encrypt(_ plain: Data, key: String, cipher: GreeCipher) throws -> EncryptedPack {
        let keyData = Data(key.utf8)
        guard keyData.count == 16 else { throw GreeError.badKey }
        switch cipher {
        case .ecb:
            let out = try ecb(plain, key: keyData, operation: CCOperation(kCCEncrypt))
            return EncryptedPack(pack: out.base64EncodedString(), tag: nil)
        case .gcm:
            let box = try AES.GCM.seal(
                plain,
                using: SymmetricKey(data: keyData),
                nonce: AES.GCM.Nonce(data: gcmNonce),
                authenticating: gcmAAD
            )
            return EncryptedPack(pack: box.ciphertext.base64EncodedString(), tag: box.tag.base64EncodedString())
        }
    }

    public static func decrypt(_ pack: EncryptedPack, key: String, cipher: GreeCipher) throws -> Data {
        let keyData = Data(key.utf8)
        guard keyData.count == 16 else { throw GreeError.badKey }
        guard let encrypted = Data(base64Encoded: pack.pack) else { throw GreeError.decryptFailed }
        let plain: Data
        switch cipher {
        case .ecb:
            plain = try ecb(encrypted, key: keyData, operation: CCOperation(kCCDecrypt))
        case .gcm:
            guard let tagString = pack.tag, let tag = Data(base64Encoded: tagString) else {
                throw GreeError.decryptFailed
            }
            do {
                let box = try AES.GCM.SealedBox(nonce: AES.GCM.Nonce(data: gcmNonce), ciphertext: encrypted, tag: tag)
                plain = try AES.GCM.open(box, using: SymmetricKey(data: keyData), authenticating: gcmAAD)
            } catch {
                throw GreeError.decryptFailed
            }
        }
        // Some firmware leaves junk after the JSON object; cut at the last brace.
        guard let end = plain.lastIndex(of: UInt8(ascii: "}")) else { throw GreeError.decryptFailed }
        return plain[...end]
    }

    private static func ecb(_ input: Data, key: Data, operation: CCOperation) throws -> Data {
        var output = Data(count: input.count + kCCBlockSizeAES128)
        let outputCapacity = output.count
        var moved = 0
        let status = output.withUnsafeMutableBytes { out in
            input.withUnsafeBytes { inp in
                key.withUnsafeBytes { k in
                    CCCrypt(
                        operation,
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode | kCCOptionPKCS7Padding),
                        k.baseAddress, key.count,
                        nil,
                        inp.baseAddress, input.count,
                        out.baseAddress, outputCapacity,
                        &moved
                    )
                }
            }
        }
        guard status == kCCSuccess else { throw GreeError.decryptFailed }
        output.removeSubrange(moved...)
        return output
    }
}
