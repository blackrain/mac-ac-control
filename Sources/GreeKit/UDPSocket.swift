import Darwin
import Foundation

/// Minimal blocking IPv4 UDP socket. Blocking calls are run off the
/// cooperative thread pool via `UDPSocket.run`.
final class UDPSocket: @unchecked Sendable {
    private let fd: Int32

    init(broadcast: Bool = false) throws {
        fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard fd >= 0 else { throw GreeError.socket(errnoMessage()) }
        if broadcast {
            var yes: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))
        }
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        addr.sin_addr.s_addr = INADDR_ANY
        let rc = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard rc == 0 else {
            let msg = errnoMessage()
            close(fd)
            throw GreeError.socket(msg)
        }
    }

    deinit { close(fd) }

    func send(_ data: Data, to host: String, port: UInt16 = 7000) throws {
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        guard inet_pton(AF_INET, host, &addr.sin_addr) == 1 else {
            throw GreeError.socket("Invalid IP address \(host)")
        }
        let sent = data.withUnsafeBytes { buf in
            withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, buf.baseAddress, buf.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
        guard sent == data.count else { throw GreeError.socket(errnoMessage()) }
    }

    /// Waits up to `timeout` for a datagram. Returns nil on timeout.
    func receive(timeout: TimeInterval) throws -> (data: Data, host: String)? {
        var pfd = pollfd(fd: fd, events: Int16(POLLIN), revents: 0)
        let ready = poll(&pfd, 1, Int32(max(0, timeout) * 1000))
        if ready == 0 { return nil }
        guard ready > 0 else { throw GreeError.socket(errnoMessage()) }

        var buffer = [UInt8](repeating: 0, count: 65536)
        var from = sockaddr_in()
        var fromLen = socklen_t(MemoryLayout<sockaddr_in>.size)
        let count = withUnsafeMutablePointer(to: &from) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                recvfrom(fd, &buffer, buffer.count, 0, $0, &fromLen)
            }
        }
        guard count >= 0 else { throw GreeError.socket(errnoMessage()) }
        var hostBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &from.sin_addr, &hostBuf, socklen_t(INET_ADDRSTRLEN))
        return (Data(buffer[0..<count]), cString(hostBuf))
    }

    /// Runs blocking socket work on a GCD thread.
    static func run<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(with: Result { try work() })
            }
        }
    }

    /// IPv4 broadcast addresses of all active non-loopback interfaces.
    static func broadcastAddresses() -> [String] {
        var result: [String] = []
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return result }
        defer { freeifaddrs(ifap) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            let flags = Int32(ifa.ifa_flags)
            guard flags & IFF_UP != 0, flags & IFF_BROADCAST != 0, flags & IFF_LOOPBACK == 0,
                  let addr = ifa.ifa_addr, addr.pointee.sa_family == sa_family_t(AF_INET),
                  let bcast = ifa.ifa_dstaddr
            else { continue }
            var sin = bcast.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
            var hostBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            inet_ntop(AF_INET, &sin.sin_addr, &hostBuf, socklen_t(INET_ADDRSTRLEN))
            let host = cString(hostBuf)
            if !result.contains(host) { result.append(host) }
        }
        return result
    }
}

private func errnoMessage() -> String {
    String(validatingCString: strerror(errno)) ?? "errno \(errno)"
}

private func cString(_ buf: [CChar]) -> String {
    let bytes = buf.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return String(decoding: bytes, as: UTF8.self)
}
