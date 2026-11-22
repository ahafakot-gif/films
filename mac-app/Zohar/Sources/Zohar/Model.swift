import Foundation
import SwiftUI

// MARK: - Attributes

enum Family: String, Codable, CaseIterable, Identifiable {
    case intensity, position, color, gobo, beam, fx
    var id: String { rawValue }
    var title: String {
        switch self {
        case .intensity: return "Intensity"
        case .position: return "Pan Tilt"
        case .color: return "Color"
        case .gobo: return "Gobo"
        case .beam: return "Beam"
        case .fx: return "FX"
        }
    }
    var key: String {
        switch self {
        case .intensity: return "I"
        case .position: return "P"
        case .color: return "C"
        case .gobo: return "G"
        case .beam: return "B"
        case .fx: return "E"
        }
    }
    var color: Color {
        switch self {
        case .intensity: return Color(red: 0.95, green: 0.30, blue: 0.30)
        case .position: return Color(red: 0.95, green: 0.45, blue: 0.55)
        case .color: return Color(red: 0.98, green: 0.78, blue: 0.25)
        case .gobo: return Color(red: 0.35, green: 0.85, blue: 0.45)
        case .beam: return Color(red: 0.95, green: 0.65, blue: 0.20)
        case .fx: return Color(red: 0.30, green: 0.75, blue: 0.95)
        }
    }
}

enum Attr: String, Codable, CaseIterable, Identifiable {
    case dimmer, dimmerFine
    case red, green, blue, white, amber, uv, cyan, magenta, yellow, cto, colorWheel
    case pan, panFine, tilt, tiltFine, ptSpeed
    case gobo, goboRot, gobo2, prism, prismRot
    case focus, zoom, iris, frost, strobe, shutter
    case control, other

    var id: String { rawValue }

    var family: Family {
        switch self {
        case .dimmer, .dimmerFine: return .intensity
        case .red, .green, .blue, .white, .amber, .uv, .cyan, .magenta, .yellow, .cto, .colorWheel: return .color
        case .pan, .panFine, .tilt, .tiltFine, .ptSpeed: return .position
        case .gobo, .goboRot, .gobo2, .prism, .prismRot: return .gobo
        case .focus, .zoom, .iris, .frost, .strobe, .shutter, .control, .other: return .beam
        }
    }

    var isFine: Bool { self == .dimmerFine || self == .panFine || self == .tiltFine }

    /// For fine channels: the attribute they belong to.
    var coarse: Attr? {
        switch self {
        case .dimmerFine: return .dimmer
        case .panFine: return .pan
        case .tiltFine: return .tilt
        default: return nil
        }
    }

    var isColorMix: Bool { [.red, .green, .blue, .white, .amber, .uv].contains(self) }

    var label: String {
        switch self {
        case .dimmer: return "Dimmer"
        case .dimmerFine: return "Dimmer fine"
        case .red: return "Red"
        case .green: return "Green"
        case .blue: return "Blue"
        case .white: return "White"
        case .amber: return "Amber"
        case .uv: return "UV"
        case .cyan: return "Cyan"
        case .magenta: return "Magenta"
        case .yellow: return "Yellow"
        case .cto: return "CTO"
        case .colorWheel: return "Color wheel"
        case .pan: return "Pan"
        case .panFine: return "Pan fine"
        case .tilt: return "Tilt"
        case .tiltFine: return "Tilt fine"
        case .ptSpeed: return "P/T speed"
        case .gobo: return "Gobo"
        case .goboRot: return "Gobo rotation"
        case .gobo2: return "Gobo 2"
        case .prism: return "Prism"
        case .prismRot: return "Prism rotation"
        case .focus: return "Focus"
        case .zoom: return "Zoom"
        case .iris: return "Iris"
        case .frost: return "Frost"
        case .strobe: return "Strobe"
        case .shutter: return "Shutter"
        case .control: return "Control"
        case .other: return "Other"
        }
    }
}

// MARK: - Fixtures

struct ChannelDef: Codable, Hashable, Identifiable {
    var id = UUID()
    var attr: Attr
    /// Default value 0…1 (shown as 0…255)
    var def: Double = 0

    init(_ attr: Attr, _ dmx: Int = 0) {
        self.attr = attr
        self.def = Double(dmx) / 255
    }
}

struct FixtureProfile: Codable, Hashable, Identifiable {
    var id: String = UUID().uuidString
    var name: String
    var channels: [ChannelDef]

    var footprint: Int { channels.count }
    var attrs: Set<Attr> { Set(channels.map { $0.attr }.filter { !$0.isFine }) }
    var hasDimmer: Bool { channels.contains { $0.attr == .dimmer } }
    var hasColorMix: Bool { channels.contains { $0.attr.isColorMix } }
}

struct Fixture: Codable, Hashable, Identifiable {
    var id: Int            // fixture number
    var name: String
    var profileID: String
    var universe: Int = 1  // 1-based
    var address: Int = 1   // 1…512
}

struct FixtureGroup: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var fixtureIDs: [Int]
    var colorIndex: Int = 0
}

typealias AttrValues = [Attr: Double]
typealias Values = [Int: AttrValues]

// MARK: - Effects

enum FXKind: String, Codable, CaseIterable, Identifiable {
    case dimSine, dimChase, dimSaw, dimFlicker, circle, panWave, tiltWave, rainbow
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dimSine: return "Dim wave"
        case .dimChase: return "Step chase"
        case .dimSaw: return "Dim saw"
        case .dimFlicker: return "Flicker"
        case .circle: return "Circle"
        case .panWave: return "Pan wave"
        case .tiltWave: return "Tilt wave"
        case .rainbow: return "Rainbow"
        }
    }
    var icon: String {
        switch self {
        case .dimSine: return "waveform.path"
        case .dimChase: return "square.grid.3x1.below.line.grid.1x2"
        case .dimSaw: return "chart.line.downtrend.xyaxis"
        case .dimFlicker: return "sparkles"
        case .circle: return "circle.dashed"
        case .panWave: return "arrow.left.and.right"
        case .tiltWave: return "arrow.up.and.down"
        case .rainbow: return "rainbow"
        }
    }
}

struct Effect: Codable, Hashable, Identifiable {
    var id = UUID()
    var kind: FXKind
    var fixtureIDs: [Int]
    var bpm: Double = 60
    var size: Double = 1
    var spread: Double = 1
    var steps: Int = 2
}

// MARK: - Cues & playbacks

struct Cue: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var values: Values = [:]
    var effects: [Effect] = []
    var fadeIn: Double = 0
}

enum ButtonMode: String, Codable, CaseIterable, Identifiable {
    case toggle, flash, go
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .toggle: return "power"
        case .flash: return "bolt.fill"
        case .go: return "forward.end.fill"
        }
    }
}

struct Cuelist: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var cues: [Cue]
    var colorIndex: Int = 0
    var mode: ButtonMode = .toggle
    var fadeOut: Double = 0
    var chase: Bool = false
    var chaseBPM: Double = 120
}

enum FaderKind: Codable, Hashable {
    case none
    case cuelist(UUID)
    case groupMaster(UUID)
    case speedMaster
    case sizeMaster
}

struct FaderSlot: Codable, Hashable {
    var kind: FaderKind = .none
    var level: Double = 0
}

// MARK: - Output

enum OutputType: String, Codable, CaseIterable, Identifiable {
    case enttecPro, openDMX, artnet
    var id: String { rawValue }
    var label: String {
        switch self {
        case .enttecPro: return "Enttec DMX USB Pro"
        case .openDMX: return "Open DMX USB (FTDI)"
        case .artnet: return "Art-Net"
        }
    }
}

struct OutputConfig: Codable, Hashable, Identifiable {
    var id = UUID()
    var universe: Int = 1
    var type: OutputType = .enttecPro
    var port: String = ""
    var ip: String = "255.255.255.255"
    var artUniverse: Int = 0
    var enabled: Bool = true
}

// MARK: - Show

struct Show: Codable {
    var name: String = "Show"
    var profiles: [FixtureProfile] = Profiles.builtins
    var fixtures: [Fixture] = []
    var groups: [FixtureGroup] = []
    var cuelists: [Cuelist] = []
    /// key = page * 1000 + slot
    var buttons: [Int: UUID] = [:]
    var faders: [FaderSlot] = Show.defaultFaders
    var outputs: [OutputConfig] = [OutputConfig()]

    static var defaultFaders: [FaderSlot] {
        var f = Array(repeating: FaderSlot(), count: 10)
        f[8] = FaderSlot(kind: .speedMaster, level: 0.5)
        f[9] = FaderSlot(kind: .sizeMaster, level: 1)
        return f
    }

    init() {}

    enum CodingKeys: String, CodingKey {
        case name, profiles, fixtures, groups, cuelists, buttons, faders, outputs
    }

    // Tolerant decoding: missing fields fall back to defaults, so older show files keep opening.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Show"
        profiles = (try? c.decode([FixtureProfile].self, forKey: .profiles)) ?? Profiles.builtins
        fixtures = (try? c.decode([Fixture].self, forKey: .fixtures)) ?? []
        groups = (try? c.decode([FixtureGroup].self, forKey: .groups)) ?? []
        cuelists = (try? c.decode([Cuelist].self, forKey: .cuelists)) ?? []
        buttons = (try? c.decode([Int: UUID].self, forKey: .buttons)) ?? [:]
        faders = (try? c.decode([FaderSlot].self, forKey: .faders)) ?? Show.defaultFaders
        outputs = (try? c.decode([OutputConfig].self, forKey: .outputs)) ?? [OutputConfig()]
        while faders.count < 10 { faders.append(FaderSlot()) }
    }
}

// MARK: - Colors for buttons / groups

enum Palette {
    static let colors: [Color] = [
        Color(red: 0.20, green: 0.75, blue: 0.80),
        Color(red: 0.30, green: 0.50, blue: 0.95),
        Color(red: 0.62, green: 0.40, blue: 0.95),
        Color(red: 0.95, green: 0.40, blue: 0.75),
        Color(red: 0.95, green: 0.30, blue: 0.30),
        Color(red: 0.98, green: 0.60, blue: 0.20),
        Color(red: 0.95, green: 0.85, blue: 0.25),
        Color(red: 0.35, green: 0.85, blue: 0.45),
    ]
    static func color(_ i: Int) -> Color { colors[((i % colors.count) + colors.count) % colors.count] }
}
