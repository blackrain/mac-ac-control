import Foundation
import GreeKit

// Debug CLI:
//   greectl scan [ip]
//   greectl status [mac-suffix|ip]
//   greectl set Pow=1 SetTem=24 [--device mac-suffix|ip]

func pickDevice(_ selector: String?) async throws -> DeviceInfo {
    let isIP = selector?.contains(".") == true
    let devices = try await GreeDiscovery.scan(hosts: isIP ? [selector!] : nil)
    if let selector, !isIP {
        guard let match = devices.first(where: { $0.mac.lowercased().hasSuffix(selector.lowercased()) }) else {
            throw GreeError.notFound
        }
        return match
    }
    guard let first = devices.first else {
        throw GreeError.notFound
    }
    return first
}

func describe(_ d: DeviceInfo) -> String {
    "\(d.displayName)  mac=\(d.mac)  ip=\(d.ip)  fw=\(d.firmware)  cipher=\(d.cipher.rawValue)"
}

var args = Array(CommandLine.arguments.dropFirst())
let command = args.isEmpty ? "scan" : args.removeFirst()

do {
    switch command {
    case "scan":
        let devices = try await GreeDiscovery.scan(hosts: args.first.map { [$0] })
        if devices.isEmpty { print("No devices found.") }
        devices.forEach { print(describe($0)) }

    case "status":
        let info = try await pickDevice(args.first)
        print(describe(info))
        let device = GreeDevice(info: info)
        let key = try await device.bind()
        print("key=\(key)")
        let state = try await device.status()
        for prop in GreeProp.allCases {
            print("  \(prop.rawValue.padding(toLength: 11, withPad: " ", startingAt: 0)) \(state[prop].map(String.init) ?? "-")")
        }
        if let room = state.roomTemp { print("  room temperature: \(room) °C") }

    case "set":
        var selector: String?
        var values: [GreeProp: Int] = [:]
        var iter = args.makeIterator()
        while let arg = iter.next() {
            if arg == "--device" { selector = iter.next(); continue }
            let parts = arg.split(separator: "=")
            guard parts.count == 2, let prop = GreeProp(rawValue: String(parts[0])), let v = Int(parts[1]) else {
                print("Bad argument: \(arg)"); exit(2)
            }
            values[prop] = v
        }
        let device = GreeDevice(info: try await pickDevice(selector))
        try await device.set(values)
        print("OK")

    default:
        print("usage: greectl scan [ip] | status [mac-suffix|ip] | set Col=Val ... [--device mac-suffix|ip]")
        exit(2)
    }
} catch {
    print("Error: \(error.localizedDescription)")
    exit(1)
}
