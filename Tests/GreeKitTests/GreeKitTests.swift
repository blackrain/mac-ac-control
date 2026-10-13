import Foundation
import Testing
@testable import GreeKit

@Test(arguments: [GreeCipher.ecb, .gcm])
func cryptoRoundTrip(cipher: GreeCipher) throws {
    let plain = Data(#"{"mac":"c8f742a1d55e","t":"bind","uid":0}"#.utf8)
    let enc = try GreeCrypto.encrypt(plain, key: cipher.genericKey, cipher: cipher)
    #expect((enc.tag != nil) == (cipher == .gcm))
    let dec = try GreeCrypto.decrypt(enc, key: cipher.genericKey, cipher: cipher)
    #expect(dec == plain)
}

@Test func ecbKnownVector() throws {
    // AES-128-ECB/PKCS7 of `{"t":"scan"}` under the generic key, cross-checked with openssl.
    let enc = try GreeCrypto.encrypt(Data(#"{"t":"scan"}"#.utf8), key: GreeCipher.ecb.genericKey, cipher: .ecb)
    #expect(enc.pack == "VT6PQOWv+8FeevjTXFZdyQ==")
}

@Test func gcmRejectsTamperedTag() throws {
    var enc = try GreeCrypto.encrypt(Data("{}".utf8), key: GreeCipher.gcm.genericKey, cipher: .gcm)
    enc.tag = Data(repeating: 0, count: 16).base64EncodedString()
    #expect(throws: GreeError.self) { try GreeCrypto.decrypt(enc, key: GreeCipher.gcm.genericKey, cipher: .gcm) }
}

@Test func scanReplyParsing() throws {
    for cipher in [GreeCipher.ecb, .gcm] {
        let inner = #"{"t":"dev","cid":"c8f742a1d55e","mac":"c8f742a1d55e","name":"","ver":"V3.0.0"}"#
        let enc = try GreeCrypto.encrypt(Data(inner.utf8), key: cipher.genericKey, cipher: cipher)
        var env: [String: Any] = ["t": "pack", "i": 1, "uid": 0, "cid": "c8f742a1d55e", "tcid": "", "pack": enc.pack]
        if let tag = enc.tag { env["tag"] = tag }
        let data = try JSONSerialization.data(withJSONObject: env)
        let info = try #require(GreeDiscovery.parseScanReply(data, host: "192.168.1.50"))
        #expect(info.mac == "c8f742a1d55e")
        #expect(info.cipher == cipher)
        #expect(info.displayName == "ACd55e")
        #expect(info.ip == "192.168.1.50")
    }
}

@Test func stateMapping() {
    let state = DeviceState(
        cols: ["Pow", "Mod", "SetTem", "WdSpd", "TemSen", "SwUpDn", "Unknown", "Lig"],
        dat: [1, 1, 23, 3, 64, 1, 9, "1"]
    )
    #expect(state.power)
    #expect(state.mode == .cool)
    #expect(state.targetTemp == 23)
    #expect(state.fanSpeed == .medium)
    #expect(state.roomTemp == 24)
    #expect(state.verticalSwing == .full)
    #expect(state.flag(.light))
}

@Test func roomTempNormalization() {
    #expect(DeviceState.normalizeRoomTemp(65) == 25)
    #expect(DeviceState.normalizeRoomTemp(25) == 25)
    #expect(DeviceState(cols: ["TemSen"], dat: [0]).roomTemp == nil)
}
