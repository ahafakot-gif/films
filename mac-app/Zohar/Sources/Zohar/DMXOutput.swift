import Darwin
import Foundation

// ioctl numbers that Swift can't import from the C macros.
private let IOSSIOSPEED: UInt = 0x8008_5402   // _IOW('T', 2, speed_t)
private let TIOCSBRK_: UInt = 0x2000_747B     // _IO('t', 123) set break
private let TIOCCBRK_: UInt = 0x2000_747A     // _IO('t', 122) clear break

enum SerialPorts {
    /// USB serial devices (Enttec / FTDI show up as /dev/cu.usbserial-XXXX).
    static func list() -> [String] {
        let all = (try? FileManager.default.contentsOfDirectory(atPath: "/dev")) ?? []
        return all
            .filter { $0.hasPrefix("cu.") && !$0.contains("Bluetooth") && !$0.contains("debug-console") && !$0.contains("wlan") }
            .map { "/dev/" + $0 }
            .sorted()
    }

    static func open(_ path: String, customBaud: UInt? = nil, twoStopBits: Bool = false) -> Int32 {
        let fd = Darwin.open(path, O_RDWR | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else { return -1 }
        _ = fcntl(fd, F_SETFL, 0)
        var t = termios()
        tcgetattr(fd, &t)
        cfmakeraw(&t)
        t.c_cflag |= tcflag_t(CLOCAL | CREAD | CS8)
        t.c_cflag &= ~tcflag_t(PARENB)
        if twoStopBits {
            t.c_cflag |= tcflag_t(CSTOPB)
        } else {
            t.c_cflag &= ~tcflag_t(CSTOPB)
        }
        cfsetspeed(&t, speed_t(57600))
        tcsetattr(fd, TCSANOW, &t)
        if let baud = customBaud {
            var speed = speed_t(baud)
            _ = withUnsafeMutablePointer(to: &speed) { ioctl(fd, IOSSIOSPEED, $0) }
        }
        return fd
    }
}

// MARK: - Device base

class DMXDevice {
    private let lock = NSLock()
    private var buffer = [UInt8](repeating: 0, count: 512)
    private var running = true
    private var _status = "…"
    let interval: TimeInterval

    init(interval: TimeInterval) {
        self.interval = interval
    }

    var status: String {
        lock.lock(); defer { lock.unlock() }
        return _status
    }

    func setStatus(_ s: String) {
        lock.lock(); _status = s; lock.unlock()
    }

    func start() {
        let t = Thread { [weak self] in self?.loop() }
        t.qualityOfService = .userInteractive
        t.name = "DMX output"
        t.start()
    }

    func update(_ data: [UInt8]) {
        lock.lock()
        buffer = data
        lock.unlock()
    }

    func stop() {
        lock.lock(); running = false; lock.unlock()
    }

    private var isRunning: Bool {
        lock.lock(); defer { lock.unlock() }
        return running
    }

    private func loop() {
        while isRunning {
            lock.lock()
            let data = buffer
            lock.unlock()
            sendFrame(data)
            Thread.sleep(forTimeInterval: interval)
        }
        close()
    }

    func sendFrame(_ data: [UInt8]) {}
    func close() {}
}

// MARK: - Enttec DMX USB Pro

final class EnttecProDevice: DMXDevice {
    let path: String
    private var fd: Int32 = -1
    private var lastTry = Date.distantPast

    init(path: String) {
        self.path = path
        super.init(interval: 1.0 / 40)
    }

    override func sendFrame(_ data: [UInt8]) {
        if fd < 0 {
            guard Date().timeIntervalSince(lastTry) > 2 else { return }
            lastTry = Date()
            fd = SerialPorts.open(path)
            setStatus(fd >= 0 ? "OK" : "✕ \(path)")
            if fd < 0 { return }
        }
        var pkt: [UInt8] = [0x7E, 6, UInt8(513 & 0xFF), UInt8(513 >> 8), 0]
        pkt.append(contentsOf: data.prefix(512))
        while pkt.count < 517 { pkt.append(0) }
        pkt.append(0xE7)
        let n = pkt.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        if n < 0 {
            Darwin.close(fd)
            fd = -1
            setStatus("✕ \(path)")
        }
    }

    override func close() {
        if fd >= 0 { Darwin.close(fd); fd = -1 }
    }
}

// MARK: - Open DMX USB (FTDI, timing done by the computer)

final class OpenDMXDevice: DMXDevice {
    let path: String
    private var fd: Int32 = -1
    private var lastTry = Date.distantPast

    init(path: String) {
        self.path = path
        super.init(interval: 1.0 / 33)
    }

    override func sendFrame(_ data: [UInt8]) {
        if fd < 0 {
            guard Date().timeIntervalSince(lastTry) > 2 else { return }
            lastTry = Date()
            fd = SerialPorts.open(path, customBaud: 250_000, twoStopBits: true)
            setStatus(fd >= 0 ? "OK" : "✕ \(path)")
            if fd < 0 { return }
        }
        var frame = [UInt8](repeating: 0, count: 513)
        for (i, v) in data.prefix(512).enumerated() { frame[i + 1] = v }
        _ = ioctl(fd, TIOCSBRK_)
        usleep(110)
        _ = ioctl(fd, TIOCCBRK_)
        usleep(16)
        let n = frame.withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        tcdrain(fd)
        if n < 0 {
            Darwin.close(fd)
            fd = -1
            setStatus("✕ \(path)")
        }
    }

    override func close() {
        if fd >= 0 { Darwin.close(fd); fd = -1 }
    }
}

// MARK: - Art-Net

final class ArtNetDevice: DMXDevice {
    private var sock: Int32 = -1
    private var addr = sockaddr_in()
    private var seq: UInt8 = 1
    private let artUniverse: Int

    init(ip: String, artUniverse: Int) {
        self.artUniverse = artUniverse
        super.init(interval: 1.0 / 40)
        sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        var yes: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &yes, socklen_t(MemoryLayout<Int32>.size))
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(6454).bigEndian
        if inet_pton(AF_INET, ip, &addr.sin_addr) != 1 {
            inet_pton(AF_INET, "255.255.255.255", &addr.sin_addr)
        }
        setStatus(sock >= 0 ? "OK" : "✕ socket")
    }

    override func sendFrame(_ data: [UInt8]) {
        guard sock >= 0 else { return }
        var p: [UInt8] = Array("Art-Net".utf8) + [0]
        p += [0x00, 0x50]                 // OpDmx (little endian)
        p += [0x00, 14]                   // protocol version
        p += [seq, 0]                     // sequence, physical
        p += [UInt8(artUniverse & 0xFF), UInt8((artUniverse >> 8) & 0x7F)]
        p += [0x02, 0x00]                 // length 512 (big endian)
        p += data.prefix(512)
        while p.count < 18 + 512 { p.append(0) }
        seq = seq == 255 ? 1 : seq + 1
        var a = addr
        let n = withUnsafePointer(to: &a) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                p.withUnsafeBytes { sendto(sock, $0.baseAddress, $0.count, 0, sa, socklen_t(MemoryLayout<sockaddr_in>.size)) }
            }
        }
        setStatus(n < 0 ? "✕ network" : "OK")
    }

    override func close() {
        if sock >= 0 { Darwin.close(sock); sock = -1 }
    }
}

// MARK: - Manager

final class DMXOutputManager {
    private var devices: [UUID: (config: OutputConfig, device: DMXDevice)] = [:]

    func configure(_ outputs: [OutputConfig]) {
        let wanted = Dictionary(uniqueKeysWithValues: outputs.filter { $0.enabled }.map { ($0.id, $0) })
        for (id, entry) in devices where wanted[id] != entry.config {
            entry.device.stop()
            devices[id] = nil
        }
        for (id, cfg) in wanted where devices[id] == nil {
            let dev: DMXDevice?
            switch cfg.type {
            case .enttecPro: dev = cfg.port.isEmpty ? nil : EnttecProDevice(path: cfg.port)
            case .openDMX: dev = cfg.port.isEmpty ? nil : OpenDMXDevice(path: cfg.port)
            case .artnet: dev = ArtNetDevice(ip: cfg.ip, artUniverse: cfg.artUniverse)
            }
            if let dev {
                dev.start()
                devices[id] = (cfg, dev)
            }
        }
    }

    func send(_ universes: [Int: [UInt8]]) {
        for (_, entry) in devices {
            entry.device.update(universes[entry.config.universe] ?? [UInt8](repeating: 0, count: 512))
        }
    }

    func status(_ id: UUID) -> String? { devices[id]?.device.status }

    var anyOK: Bool { devices.values.contains { $0.device.status == "OK" } }
}
