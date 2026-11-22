import AppKit
import SwiftUI

// MARK: - Shell

struct ShellResult {
    let code: Int32
    let output: String
    var ok: Bool { code == 0 }
}

enum Shell {
    /// Run a program with arguments in the background.
    static func runArgs(_ path: String, _ args: [String]) async -> ShellResult {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: runArgsSync(path, args))
            }
        }
    }

    static func runArgsSync(_ path: String, _ args: [String]) -> ShellResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        do {
            try p.run()
        } catch {
            return ShellResult(code: -1, output: error.localizedDescription)
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return ShellResult(code: p.terminationStatus, output: String(decoding: data, as: UTF8.self))
    }

    /// Run a zsh command line.
    static func run(_ command: String) async -> ShellResult {
        await runArgs("/bin/zsh", ["-c", command])
    }

    /// Run a command as administrator (macOS asks for the password once).
    static func runAsAdmin(_ command: String) async -> ShellResult {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = "do shell script \"\(escaped)\" with administrator privileges"
        return await runArgs("/usr/bin/osascript", ["-e", script])
    }

    /// Quote a string for zsh.
    static func q(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}

// MARK: - Preferences of other apps (Finder, Dock …)

enum Prefs {
    private static func value(_ domain: String, _ key: String) -> Any? {
        let app: CFString = domain == "NSGlobalDomain" ? kCFPreferencesAnyApplication : domain as CFString
        CFPreferencesAppSynchronize(app)
        return CFPreferencesCopyAppValue(key as CFString, app)
    }

    static func bool(_ domain: String, _ key: String) -> Bool {
        let v = value(domain, key)
        if let b = v as? Bool { return b }
        if let n = v as? NSNumber { return n.intValue != 0 }
        if let s = v as? String { return ["1", "yes", "true"].contains(s.lowercased()) }
        return false
    }

    static func double(_ domain: String, _ key: String) -> Double? {
        let v = value(domain, key)
        if let n = v as? NSNumber { return n.doubleValue }
        if let s = v as? String { return Double(s) }
        return nil
    }

    static func string(_ domain: String, _ key: String) -> String? {
        value(domain, key) as? String
    }
}

// MARK: - Formatting

enum Fmt {
    static func bytes(_ n: Int64) -> String {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f.string(fromByteCount: n)
    }

    static func duration(_ seconds: TimeInterval, lang: Lang) -> String {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = seconds >= 86400 ? [.day, .hour] : [.hour, .minute]
        var cal = Calendar.current
        cal.locale = Locale(identifier: lang.localeID)
        f.calendar = cal
        return f.string(from: seconds) ?? "—"
    }

    static func date(_ d: Date?, lang: Lang) -> String {
        guard let d else { return "—" }
        let f = DateFormatter()
        f.locale = Locale(identifier: lang.localeID)
        f.dateStyle = .medium
        f.timeStyle = .none
        return f.string(from: d)
    }
}

// MARK: - Disk & system info

enum DiskSpace {
    static func freeAndTotal() -> (free: Int64, total: Int64) {
        let url = URL(fileURLWithPath: "/")
        let v = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey, .volumeTotalCapacityKey])
        let free = v?.volumeAvailableCapacityForImportantUsage ?? 0
        let total = Int64(v?.volumeTotalCapacity ?? 0)
        return (free, total)
    }
}

struct SystemInfo {
    var macOS: String
    var model: String
    var cpu: String
    var memory: Int64
    var uptime: TimeInterval
    var diskFree: Int64
    var diskTotal: Int64

    static func sysctl(_ name: String) -> String {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return "—" }
        var buf = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return "—" }
        return String(cString: buf)
    }

    static func current() -> SystemInfo {
        let pi = ProcessInfo.processInfo
        let v = pi.operatingSystemVersion
        let disk = DiskSpace.freeAndTotal()
        return SystemInfo(
            macOS: "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)",
            model: sysctl("hw.model"),
            cpu: sysctl("machdep.cpu.brand_string"),
            memory: Int64(pi.physicalMemory),
            uptime: pi.systemUptime,
            diskFree: disk.free,
            diskTotal: disk.total
        )
    }
}

// MARK: - App state

enum Theme: String, CaseIterable, Identifiable {
    case light, dark, system
    var id: String { rawValue }
    var scheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

struct LogLine: Identifiable {
    enum Kind { case info, ok, error, output }
    let id = UUID()
    let date = Date()
    let text: String
    let kind: Kind
}

@MainActor
final class AppState: ObservableObject {
    @Published var lang: Lang {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: "lang") }
    }
    @Published var theme: Theme {
        didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") }
    }
    @Published var log: [LogLine] = []

    init() {
        let savedLang = UserDefaults.standard.string(forKey: "lang").flatMap(Lang.init(rawValue:))
        let sys = Locale.preferredLanguages.first ?? "ru"
        let guess: Lang = sys.hasPrefix("he") ? .he : (sys.hasPrefix("en") ? .en : .ru)
        lang = savedLang ?? guess
        theme = UserDefaults.standard.string(forKey: "theme").flatMap(Theme.init(rawValue:)) ?? .light
    }

    func t(_ key: String) -> String { Strings.get(key, lang) }

    func add(_ text: String, _ kind: LogLine.Kind = .info) {
        log.append(LogLine(text: text, kind: kind))
        if log.count > 2000 { log.removeFirst(log.count - 2000) }
    }

    func add(result r: ShellResult) {
        let out = r.output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !out.isEmpty {
            let lines = out.split(separator: "\n").prefix(200)
            add(lines.joined(separator: "\n"), r.ok ? .output : .error)
        }
    }
}
