import Darwin
import Foundation

struct ArtNode: Identifiable, Hashable {
    var id: String { ip }
    let ip: String
    let name: String
    let longName: String
    var universes: [Int]
}

struct LocalInterface: Hashable {
    let name: String
    let ip: String
}

/// Finds Art-Net nodes on the network (ArtPoll → ArtPollReply).
enum ArtNetDiscovery {
    static func ipString(_ a: in_addr) -> String {
        var addr = a
        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        inet_ntop(AF_INET, &addr, &buf, socklen_t(INET_ADDRSTRLEN))
        return String(cString: buf)
    }

    /// IPv4 interfaces of this Mac with their broadcast addresses.
    static func interfaces() -> [(iface: LocalInterface, broadcast: in_addr?)] {
        var result: [(LocalInterface, in_addr?)] = []
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0 else { return [] }
        var p = addrs
        while let a = p {
            let flags = Int32(a.pointee.ifa_flags)
            if let sa = a.pointee.ifa_addr, sa.pointee.sa_family == UInt8(AF_INET),
               flags & IFF_LOOPBACK == 0, flags & IFF_UP != 0 {
                let ip = sa.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                var bcast: in_addr? = nil
                if flags & IFF_BROADCAST != 0, let d = a.pointee.ifa_dstaddr {
                    bcast = d.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee.sin_addr }
                }
                result.append((LocalInterface(name: String(cString: a.pointee.ifa_name), ip: ipString(ip)), bcast))
            }
            p = a.pointee.ifa_next
        }
        freeifaddrs(addrs)
        return result
    }

    static var pollPacket: [UInt8] {
        Array("Art-Net".utf8) + [0, 0x00, 0x20, 0, 14, 0x00, 0x00]
    }

    /// Parse one ArtPollReply. Returns nil for anything else.
    static func parseReply(_ b: [UInt8]) -> ArtNode? {
        guard b.count >= 200, Array(b[0..<8]) == Array("Art-Net".utf8) + [0],
              b[8] == 0x00, b[9] == 0x21 else { return nil }
        let ip = "\(b[10]).\(b[11]).\(b[12]).\(b[13])"
        func text(_ r: Range<Int>) -> String {
            let bytes = b[r].prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self).trimmingCharacters(in: .whitespaces)
        }
        let net = Int(b[18] & 0x7F), sub = Int(b[19] & 0x0F)
        let ports = min(4, Int(b[173]))
        var unis: [Int] = []
        for i in 0..<ports {
            let type = b[174 + i]
            let canOutput = type & 0x80 != 0
            if canOutput || type == 0 {
                unis.append(net << 8 | sub << 4 | Int(b[190 + i] & 0x0F))
            }
        }
        return ArtNode(ip: ip, name: text(26..<44), longName: text(44..<108), universes: unis)
    }

    static func discoverSync(timeout: TimeInterval = 2.5) -> [ArtNode] {
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return [] }
        defer { close(sock) }
        var yes: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(sock, SOL_SOCKET, SO_REUSEPORT, &yes, socklen_t(MemoryLayout<Int32>.size))
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))
        var tv = timeval(tv_sec: 0, tv_usec: 200_000)
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        var local = sockaddr_in()
        local.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        local.sin_family = sa_family_t(AF_INET)
        local.sin_port = in_port_t(6454).bigEndian
        local.sin_addr.s_addr = INADDR_ANY
        _ = withUnsafePointer(to: &local) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }

        var targets: [in_addr] = interfaces().compactMap { $0.broadcast }
        for s in ["255.255.255.255", "2.255.255.255", "10.255.255.255"] {
            var a = in_addr()
            if inet_pton(AF_INET, s, &a) == 1 { targets.append(a) }
        }
        let pkt = pollPacket
        for t in targets {
            var dst = sockaddr_in()
            dst.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            dst.sin_family = sa_family_t(AF_INET)
            dst.sin_port = in_port_t(6454).bigEndian
            dst.sin_addr = t
            _ = withUnsafePointer(to: &dst) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    pkt.withUnsafeBytes { sendto(sock, $0.baseAddress, $0.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size)) }
                }
            }
        }

        var nodes: [String: ArtNode] = [:]
        let deadline = Date().addingTimeInterval(timeout)
        var buf = [UInt8](repeating: 0, count: 1500)
        while Date() < deadline {
            let n = buf.withUnsafeMutableBytes { recv(sock, $0.baseAddress, $0.count, 0) }
            guard n > 0 else { continue }
            if let node = parseReply(Array(buf[0..<n])) {
                if var existing = nodes[node.ip] {
                    for u in node.universes where !existing.universes.contains(u) { existing.universes.append(u) }
                    nodes[node.ip] = existing
                } else {
                    nodes[node.ip] = node
                }
            }
        }
        return nodes.values
            .map { var n = $0; n.universes.sort(); return n }
            .sorted { $0.ip < $1.ip }
    }

    static func discover() async -> [ArtNode] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: discoverSync())
            }
        }
    }
}
