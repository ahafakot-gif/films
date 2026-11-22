import AppKit
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct PlaybackState: Equatable {
    var active = false
    var level: Double = 1
    var cueIndex = 0
    var activatedAt: Double = 0
    var fadeStart: Double = 0
    var fadeDuration: Double = 0
    var from: Values = [:]
    var releasing = false
    var releaseStart: Double = 0
    var releaseDuration: Double = 0
    var lastStep: Double = 0
    var flashing = false
}

enum SheetKind: Identifiable, Equatable {
    case patch, settings, cuelist(UUID)
    var id: String {
        switch self {
        case .patch: return "patch"
        case .settings: return "settings"
        case .cuelist(let u): return "cl-" + u.uuidString
        }
    }
}

enum Theme: String, CaseIterable, Identifiable {
    case dark, light
    var id: String { rawValue }
    var scheme: ColorScheme { self == .dark ? .dark : .light }
}

@MainActor
final class Console: ObservableObject {
    // Show data (saved)
    @Published var show: Show { didSet { dirty = true } }

    // Live state
    @Published var selection: [Int] = []
    @Published var programmer: Values = [:]
    @Published var programmerFX: [Effect] = []
    @Published var states: [UUID: PlaybackState] = [:]
    @Published var grandMaster: Double = 1
    @Published var blackout = false
    @Published var highlight = false
    @Published var recordMode = false
    @Published var page = 0
    @Published var message: String? = nil
    @Published var outputOK = false
    @Published var sheet: SheetKind? = nil
    @Published var secondScreenOpen = false
    @Published var secondMode = 0      // 0 = groups + programmer, 1 = playback page
    @Published var page2 = 1
    /// Color matrix: group → color index (applied above playbacks, below programmer)
    @Published var groupColors: [UUID: Int] = [:]
    @Published var midiLearn = false
    @Published var learnTarget: MIDITarget? = nil
    @Published var midiDevices: [String] = []
    private let midi = MIDIInput()

    @Published var lang: Lang { didSet { UserDefaults.standard.set(lang.rawValue, forKey: "lang") } }
    @Published var theme: Theme { didSet { UserDefaults.standard.set(theme.rawValue, forKey: "theme") } }

    static let cols = 10
    static let rows = 8
    static let pages = 10

    private(set) var lastFrame: Values = [:]
    private let output = DMXOutputManager()
    private var timer: Timer?
    private let t0 = Date()
    private var dirty = false
    private var lastSave = Date()
    private var tickCount = 0

    var now: Double { Date().timeIntervalSince(t0) }

    init() {
        let savedLang = UserDefaults.standard.string(forKey: "lang").flatMap(Lang.init(rawValue:))
        let sys = Locale.preferredLanguages.first ?? "ru"
        _ = sys
        lang = savedLang ?? .he
        theme = UserDefaults.standard.string(forKey: "theme").flatMap(Theme.init(rawValue:)) ?? .dark
        show = Console.loadAutosave() ?? Show()
        resetFaderLevels()
        dirty = false
        output.configure(show.outputs)
        let t = Timer(timeInterval: 1.0 / 40, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        midi.onMessage = { [weak self] m in
            Task { @MainActor in self?.handleMIDI(m) }
        }
        midi.start()
        midiDevices = midi.sourceNames
    }

    func t(_ key: String) -> String { Strings.get(key, lang) }

    // MARK: Lookups

    func profile(_ id: String) -> FixtureProfile? { show.profiles.first { $0.id == id } }
    func profile(of fixtureID: Int) -> FixtureProfile? {
        guard let f = show.fixtures.first(where: { $0.id == fixtureID }) else { return nil }
        return profile(f.profileID)
    }
    func cuelist(_ id: UUID) -> Cuelist? { show.cuelists.first { $0.id == id } }
    func cuelistIndex(_ id: UUID) -> Int? { show.cuelists.firstIndex { $0.id == id } }
    func group(_ id: UUID) -> FixtureGroup? { show.groups.first { $0.id == id } }

    func buttonKey(_ slot: Int, page p: Int? = nil) -> Int { (p ?? page) * 1000 + slot }
    func cuelistAt(slot: Int, page p: Int? = nil) -> Cuelist? {
        guard let id = show.buttons[buttonKey(slot, page: p)] else { return nil }
        return cuelist(id)
    }

    func isActive(_ id: UUID) -> Bool { states[id]?.active == true && states[id]?.releasing == false }

    func flash(_ text: String) {
        message = text
        let current = text
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            if self?.message == current { self?.message = nil }
        }
    }

    // MARK: Masters

    var speedMul: Double {
        if let f = show.faders.first(where: { $0.kind == .speedMaster }) { return max(0.02, f.level * 2) }
        return 1
    }
    var sizeMul: Double {
        if let f = show.faders.first(where: { $0.kind == .sizeMaster }) { return f.level }
        return 1
    }

    // MARK: Engine

    private func tick() {
        let t = now
        tickCount += 1
        advance(t)
        let frame = render(t)
        lastFrame = frame
        output.send(buildDMX(frame))
        if tickCount % 40 == 0 {
            let ok = output.anyOK
            if ok != outputOK { outputOK = ok }
            if dirty && Date().timeIntervalSince(lastSave) > 3 { autosave() }
        }
    }

    /// Chases and finished releases.
    private func advance(_ t: Double) {
        for (id, st) in states where st.active {
            if st.releasing {
                if st.releaseDuration <= 0 || t - st.releaseStart >= st.releaseDuration {
                    var s = st
                    s.active = false
                    s.releasing = false
                    states[id] = s
                }
                continue
            }
            guard let cl = cuelist(id), cl.chase, cl.cues.count > 1 else { continue }
            let interval = 60 / max(1, cl.chaseBPM * speedMul)
            if t - st.lastStep >= interval {
                transition(id, to: (st.cueIndex + 1) % cl.cues.count, level: st.level)
            }
        }
    }

    private func intensityLevel(_ st: PlaybackState, _ t: Double) -> Double {
        var lvl = st.level
        if st.releasing && st.releaseDuration > 0 {
            lvl *= max(0, 1 - (t - st.releaseStart) / st.releaseDuration)
        }
        return lvl
    }

    func render(_ t: Double) -> Values {
        var out: Values = [:]
        var profiles: [Int: FixtureProfile] = [:]
        for f in show.fixtures {
            guard let p = profile(f.profileID) else { continue }
            profiles[f.id] = p
            var a: AttrValues = [:]
            for ch in p.channels where !ch.attr.isFine { a[ch.attr] = ch.def }
            a[.dimmer] = 0
            out[f.id] = a
        }

        let active = states.filter { $0.value.active }.sorted { $0.value.activatedAt < $1.value.activatedAt }
        for (id, st) in active {
            guard let cl = cuelist(id), cl.cues.indices.contains(st.cueIndex) else { continue }
            let cue = cl.cues[st.cueIndex]
            let lvl = intensityLevel(st, t)
            let p = st.fadeDuration > 0 ? min(1, max(0, (t - st.fadeStart) / st.fadeDuration)) : 1
            let ids = Set(cue.values.keys).union(st.from.keys)
            for fid in ids {
                guard out[fid] != nil else { continue }
                let target = cue.values[fid] ?? [:]
                let from = st.from[fid] ?? [:]
                // Intensity (HTP)
                let fromDim = from[.dimmer] ?? 0
                let toDim = target[.dimmer] ?? 0
                if target[.dimmer] != nil || from[.dimmer] != nil {
                    let d = (fromDim + (toDim - fromDim) * p) * lvl
                    out[fid]![.dimmer] = max(out[fid]![.dimmer] ?? 0, d)
                }
                // Everything else (LTP)
                if st.level > 0.001 {
                    for (attr, v) in target where attr != .dimmer {
                        let f0 = from[attr] ?? v
                        out[fid]![attr] = f0 + (v - f0) * p
                    }
                }
            }
            for e in cue.effects { applyFX(e, &out, t, scale: lvl) }
        }

        // Color matrix
        for (gid, ci) in groupColors {
            guard let g = group(gid), MatrixColor.all.indices.contains(ci) else { continue }
            let mc = MatrixColor.all[ci]
            for fid in g.fixtureIDs {
                guard out[fid] != nil, let p = profiles[fid] else { continue }
                Console.applyColor(mc, to: &out[fid]!, profile: p)
            }
        }

        // Programmer
        for (fid, attrs) in programmer where out[fid] != nil {
            for (attr, v) in attrs { out[fid]![attr] = v }
        }
        for e in programmerFX { applyFX(e, &out, t, scale: 1) }

        // Highlight
        if highlight {
            for fid in selection where out[fid] != nil {
                out[fid]![.dimmer] = 1
                if let p = profiles[fid] {
                    for a in [Attr.red, .green, .blue, .white] where p.attrs.contains(a) { out[fid]![a] = 1 }
                    if p.attrs.contains(.strobe) { out[fid]![.strobe] = 0 }
                }
            }
        }

        // Group masters
        for f in show.faders {
            if case .groupMaster(let gid) = f.kind, let g = group(gid) {
                for fid in g.fixtureIDs where out[fid] != nil {
                    out[fid]![.dimmer] = (out[fid]![.dimmer] ?? 0) * f.level
                }
            }
        }

        // Grand master / blackout
        let gm = blackout ? 0 : grandMaster
        if gm < 1 {
            for fid in out.keys { out[fid]![.dimmer] = (out[fid]![.dimmer] ?? 0) * gm }
        }
        return out
    }

    private func applyFX(_ e: Effect, _ out: inout Values, _ t: Double, scale: Double) {
        guard scale > 0.0001 else { return }
        let ids = e.fixtureIDs.filter { out[$0] != nil }
        let n = max(ids.count, 1)
        let bpm = e.bpm * speedMul
        let size = min(1, e.size * sizeMul)
        let beats = t * bpm / 60
        for (i, fid) in ids.enumerated() {
            let offset = Double(i) / Double(n) * e.spread
            let ph = beats + offset
            func setDim(_ v: Double) {
                let before = out[fid]![.dimmer] ?? 0
                out[fid]![.dimmer] = before + (v - before) * scale
            }
            switch e.kind {
            case .dimSine:
                setDim((1 - size) + size * (0.5 + 0.5 * sin(2 * .pi * ph)))
            case .dimSaw:
                setDim((1 - size) + size * (1 - (ph - floor(ph))))
            case .dimChase:
                let k = max(1, e.steps)
                let step = Int(floor(beats)) % k
                setDim(i % k == step ? 1 : 1 - size)
            case .dimFlicker:
                let stepIndex = UInt64(max(0, floor(beats * 4)))
                var h = UInt64(truncatingIfNeeded: fid) &* 0x9E37_79B9_7F4A_7C15 ^ stepIndex &* 0xBF58_476D_1CE4_E5B9
                h ^= h >> 31
                setDim(h % 100 < 50 ? 1 : 1 - size)
            case .circle:
                let r = 0.15 * size * scale
                out[fid]![.pan] = (out[fid]![.pan] ?? 0.5) + cos(2 * .pi * ph) * r
                out[fid]![.tilt] = (out[fid]![.tilt] ?? 0.5) + sin(2 * .pi * ph) * r
            case .panWave:
                out[fid]![.pan] = (out[fid]![.pan] ?? 0.5) + sin(2 * .pi * ph) * 0.15 * size * scale
            case .tiltWave:
                out[fid]![.tilt] = (out[fid]![.tilt] ?? 0.5) + sin(2 * .pi * ph) * 0.15 * size * scale
            case .rainbow:
                let c = Console.hsv(h: ph - floor(ph), s: size, v: 1)
                for (a, v) in [(Attr.red, c.0), (.green, c.1), (.blue, c.2)] {
                    let before = out[fid]![a] ?? 0
                    out[fid]![a] = before + (v - before) * scale
                }
                if out[fid]![.white] != nil { out[fid]![.white] = (out[fid]![.white] ?? 0) * (1 - scale) }
            }
        }
    }

    static func applyColor(_ mc: MatrixColor, to a: inout AttrValues, profile p: FixtureProfile) {
        if p.attrs.contains(.red) {
            a[.red] = mc.r; a[.green] = mc.g; a[.blue] = mc.b
            if p.attrs.contains(.white) { a[.white] = mc.w }
            if p.attrs.contains(.amber) { a[.amber] = 0 }
            if p.attrs.contains(.uv) { a[.uv] = 0 }
        } else if p.attrs.contains(.cyan) {
            a[.cyan] = 1 - mc.r; a[.magenta] = 1 - mc.g; a[.yellow] = 1 - mc.b
        }
    }

    func toggleGroupColor(_ gid: UUID, _ ci: Int) {
        if groupColors[gid] == ci { groupColors[gid] = nil } else { groupColors[gid] = ci }
    }

    // MARK: MIDI

    func refreshMIDI() {
        midi.connectAll()
        midiDevices = midi.sourceNames
    }

    func handleMIDI(_ m: MIDIMessage) {
        if midiLearn, let target = learnTarget {
            show.midiMaps.removeAll { $0.target == target || ($0.kind == m.kind && $0.channel == m.channel && $0.number == m.number) }
            show.midiMaps.append(MIDIMap(kind: m.kind, channel: m.channel, number: m.number, target: target))
            learnTarget = nil
            flash("MIDI ✓ \(m.kind == .note ? "Note" : "CC") \(m.number)")
            return
        }
        guard let map = show.midiMaps.first(where: { $0.kind == m.kind && $0.channel == m.channel && $0.number == m.number }) else { return }
        switch map.target {
        case .button(let p, let slot):
            guard let cl = cuelistAt(slot: slot, page: p) else { return }
            if m.isOn { buttonDown(cl.id) } else { buttonUp(cl.id) }
        case .fader(let i):
            if m.kind == .cc {
                setFader(i, Double(m.value) / 127)
            } else {
                faderFlash(i, down: m.isOn)
            }
        case .grandMaster:
            if m.kind == .cc { grandMaster = Double(m.value) / 127 }
        case .blackout:
            if m.kind == .cc {
                blackout = m.isOn
            } else if m.isOn {
                blackout.toggle()
            }
        }
    }

    func midiLabel(_ target: MIDITarget) -> String {
        switch target {
        case .button(let p, let s): return "\(t("ui.page")) \(p + 1) · #\(s + 1)"
        case .fader(let i): return "Fader \(i + 1)"
        case .grandMaster: return "Grand Master"
        case .blackout: return "Blackout"
        }
    }

    static func hsv(h: Double, s: Double, v: Double) -> (Double, Double, Double) {
        let i = Int(h * 6) % 6
        let f = h * 6 - floor(h * 6)
        let p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
        switch i {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }

    func buildDMX(_ frame: Values) -> [Int: [UInt8]] {
        var u: [Int: [UInt8]] = [:]
        for f in show.fixtures {
            guard let p = profile(f.profileID), let a = frame[f.id] else { continue }
            var buf = u[f.universe] ?? [UInt8](repeating: 0, count: 512)
            let virtualDim = p.hasDimmer ? 1 : (a[.dimmer] ?? 0)
            for (i, ch) in p.channels.enumerated() {
                let addr = f.address - 1 + i
                guard addr >= 0 && addr < 512 else { continue }
                let attr = ch.attr.coarse ?? ch.attr
                var v = a[attr] ?? ch.def
                if attr.isColorMix { v *= virtualDim }
                v = min(max(v, 0), 1)
                let v16 = Int((v * 65535).rounded())
                buf[addr] = ch.attr.isFine ? UInt8(v16 & 0xFF) : UInt8(v16 >> 8)
            }
            u[f.universe] = buf
        }
        return u
    }

    // MARK: Playback control

    private func snapshot(for id: UUID, wasActive: Bool, newCue: Cue) -> Values {
        var from: Values = [:]
        var ids = Set(newCue.values.keys)
        var oldCue: Cue? = nil
        if wasActive, let st = states[id], let cl = cuelist(id), cl.cues.indices.contains(st.cueIndex) {
            oldCue = cl.cues[st.cueIndex]
            ids.formUnion(oldCue!.values.keys)
        }
        for fid in ids {
            var a = lastFrame[fid] ?? [:]
            a[.dimmer] = oldCue?.values[fid]?[.dimmer] ?? 0
            from[fid] = a
        }
        return from
    }

    func jump(_ id: UUID, to index: Int) {
        transition(id, to: index, level: states[id]?.active == true ? (states[id]?.level ?? 1) : 1)
    }

    private func transition(_ id: UUID, to index: Int, level: Double) {
        guard let cl = cuelist(id), cl.cues.indices.contains(index) else { return }
        var st = states[id] ?? PlaybackState()
        let wasActive = st.active && !st.releasing
        st.from = snapshot(for: id, wasActive: wasActive, newCue: cl.cues[index])
        if !wasActive { st.activatedAt = now }
        st.active = true
        st.releasing = false
        st.cueIndex = index
        st.level = level
        st.fadeStart = now
        st.fadeDuration = cl.cues[index].fadeIn
        st.lastStep = now
        states[id] = st
    }

    func activate(_ id: UUID, level: Double = 1) {
        guard let cl = cuelist(id), !cl.cues.isEmpty else { return }
        if isActive(id) {
            states[id]?.level = level
        } else {
            transition(id, to: 0, level: level)
        }
    }

    func go(_ id: UUID, level: Double? = nil) {
        guard let cl = cuelist(id), !cl.cues.isEmpty else { return }
        if isActive(id), let st = states[id] {
            transition(id, to: (st.cueIndex + 1) % cl.cues.count, level: level ?? st.level)
        } else {
            transition(id, to: 0, level: level ?? 1)
        }
    }

    func back(_ id: UUID) {
        guard let cl = cuelist(id), !cl.cues.isEmpty, isActive(id), let st = states[id] else { return }
        transition(id, to: (st.cueIndex - 1 + cl.cues.count) % cl.cues.count, level: st.level)
    }

    func release(_ id: UUID) {
        guard var st = states[id], st.active else { return }
        let fade = cuelist(id)?.fadeOut ?? 0
        if fade <= 0 {
            st.active = false
            st.releasing = false
        } else {
            st.releasing = true
            st.releaseStart = now
            st.releaseDuration = fade
        }
        states[id] = st
    }

    func releaseAll() {
        for id in states.keys { release(id) }
        for i in show.faders.indices {
            if case .cuelist = show.faders[i].kind { show.faders[i].level = 0 }
        }
    }

    func buttonDown(_ id: UUID) {
        guard let cl = cuelist(id) else { return }
        switch cl.mode {
        case .toggle: isActive(id) ? release(id) : activate(id)
        case .go: go(id)
        case .flash:
            activate(id, level: 1)
            states[id]?.flashing = true
        }
    }

    func buttonUp(_ id: UUID) {
        guard let cl = cuelist(id), cl.mode == .flash else { return }
        states[id]?.flashing = false
        release(id)
    }

    // Faders

    func setFader(_ i: Int, _ level: Double) {
        guard show.faders.indices.contains(i) else { return }
        show.faders[i].level = level
        if case .cuelist(let id) = show.faders[i].kind, states[id]?.flashing != true {
            if level > 0.004 {
                activate(id, level: level)
            } else if isActive(id) {
                release(id)
            }
        }
    }

    func faderFlash(_ i: Int, down: Bool) {
        guard case .cuelist(let id) = show.faders[i].kind else { return }
        if down {
            activate(id, level: 1)
            states[id]?.flashing = true
        } else {
            states[id]?.flashing = false
            let lvl = show.faders[i].level
            if lvl > 0.004 { states[id]?.level = lvl } else { release(id) }
        }
    }

    func assignFader(_ i: Int, _ kind: FaderKind) {
        guard show.faders.indices.contains(i) else { return }
        show.faders[i].kind = kind
        switch kind {
        case .groupMaster, .sizeMaster: show.faders[i].level = 1
        case .speedMaster: show.faders[i].level = 0.5
        default: show.faders[i].level = 0
        }
    }

    func faderTitle(_ f: FaderSlot) -> String {
        switch f.kind {
        case .none: return "—"
        case .cuelist(let id): return cuelist(id)?.name ?? "—"
        case .groupMaster(let id): return (group(id)?.name ?? "?") + " ●"
        case .speedMaster: return "FX SPEED"
        case .sizeMaster: return "FX SIZE"
        }
    }

    private func resetFaderLevels() {
        for i in show.faders.indices {
            if case .cuelist = show.faders[i].kind { show.faders[i].level = 0 }
        }
    }

    // MARK: Selection & programmer

    func toggleFixture(_ id: Int) {
        if let i = selection.firstIndex(of: id) { selection.remove(at: i) } else { selection.append(id) }
    }

    func selectGroup(_ g: FixtureGroup) {
        let ids = g.fixtureIDs.filter { fid in show.fixtures.contains { $0.id == fid } }
        if !ids.isEmpty && ids.allSatisfy({ selection.contains($0) }) {
            selection.removeAll { ids.contains($0) }
        } else {
            for id in ids where !selection.contains(id) { selection.append(id) }
        }
    }

    func isGroupSelected(_ g: FixtureGroup) -> Bool {
        !g.fixtureIDs.isEmpty && g.fixtureIDs.allSatisfy { selection.contains($0) }
    }

    /// Attributes present in the selected fixtures.
    var selectedAttrs: Set<Attr> {
        var s = Set<Attr>()
        for fid in selection { if let p = profile(of: fid) { s.formUnion(p.attrs) } }
        if !selection.isEmpty { s.insert(.dimmer) }
        return s
    }

    func value(_ attr: Attr) -> Double {
        for fid in selection {
            if let v = programmer[fid]?[attr] { return v }
        }
        if let fid = selection.first {
            if let v = lastFrame[fid]?[attr] { return attr == .dimmer ? v / max(0.0001, blackout ? 1 : grandMaster) : v }
        }
        return attr == .pan || attr == .tilt ? 0.5 : 0
    }

    func isProgrammed(_ attr: Attr) -> Bool {
        selection.contains { programmer[$0]?[attr] != nil }
    }

    func set(_ attr: Attr, _ v: Double) {
        let v = min(max(v, 0), 1)
        for fid in selection {
            guard let p = profile(of: fid) else { continue }
            if attr == .dimmer || p.attrs.contains(attr) {
                programmer[fid, default: [:]][attr] = v
            }
        }
    }

    func setColor(r: Double, g: Double, b: Double, w: Double = 0) {
        for fid in selection {
            guard let p = profile(of: fid) else { continue }
            if p.attrs.contains(.red) {
                programmer[fid, default: [:]][.red] = r
                programmer[fid, default: [:]][.green] = g
                programmer[fid, default: [:]][.blue] = b
                if p.attrs.contains(.white) { programmer[fid, default: [:]][.white] = w }
                if p.attrs.contains(.amber) { programmer[fid, default: [:]][.amber] = 0 }
                if p.attrs.contains(.uv) { programmer[fid, default: [:]][.uv] = 0 }
            } else if p.attrs.contains(.cyan) {
                programmer[fid, default: [:]][.cyan] = 1 - r
                programmer[fid, default: [:]][.magenta] = 1 - g
                programmer[fid, default: [:]][.yellow] = 1 - b
            }
        }
    }

    func clearFamily(_ family: Family) {
        for fid in programmer.keys {
            programmer[fid] = programmer[fid]?.filter { $0.key.family != family }
        }
        if family == .fx { programmerFX.removeAll() }
    }

    func addEffect(_ kind: FXKind, bpm: Double, size: Double, spread: Double, steps: Int) {
        guard !selection.isEmpty else { flash(t("msg.selectFirst")); return }
        programmerFX.append(Effect(kind: kind, fixtureIDs: selection, bpm: bpm, size: size, spread: spread, steps: steps))
    }

    func clearProgrammer() {
        if programmer.isEmpty && programmerFX.isEmpty {
            selection.removeAll()
        } else {
            programmer.removeAll()
            programmerFX.removeAll()
        }
        highlight = false
    }

    var programmerEmpty: Bool { programmer.values.allSatisfy { $0.isEmpty } && programmerFX.isEmpty }

    // MARK: Record

    private func newCue(number: Int) -> Cue {
        Cue(name: "Cue \(number)", values: programmer.filter { !$0.value.isEmpty }, effects: programmerFX)
    }

    /// Record into a button slot: new cuelist, or append a cue to the existing one.
    func record(toSlot slot: Int, page p: Int? = nil) {
        defer { recordMode = false }
        guard !programmerEmpty else { flash(t("msg.programmerEmpty")); return }
        let key = buttonKey(slot, page: p)
        if let id = show.buttons[key], let ci = cuelistIndex(id) {
            let n = show.cuelists[ci].cues.count + 1
            show.cuelists[ci].cues.append(newCue(number: n))
            flash("\(show.cuelists[ci].name): Cue \(n) ✓")
        } else {
            let name = suggestedName()
            let cl = Cuelist(name: name, cues: [newCue(number: 1)], colorIndex: dominantColorIndex())
            show.cuelists.append(cl)
            show.buttons[key] = cl.id
            flash("\(name) ✓")
        }
    }

    func record(toFader i: Int) {
        defer { recordMode = false }
        guard !programmerEmpty else { flash(t("msg.programmerEmpty")); return }
        if case .cuelist(let id) = show.faders[i].kind, let ci = cuelistIndex(id) {
            let n = show.cuelists[ci].cues.count + 1
            show.cuelists[ci].cues.append(newCue(number: n))
            flash("\(show.cuelists[ci].name): Cue \(n) ✓")
        } else {
            let cl = Cuelist(name: suggestedName(), cues: [newCue(number: 1)], colorIndex: dominantColorIndex())
            show.cuelists.append(cl)
            show.faders[i] = FaderSlot(kind: .cuelist(cl.id), level: 0)
            flash("\(cl.name) ✓")
        }
    }

    private func suggestedName() -> String {
        // name after the selected group if all selected fixtures form one group
        if let g = show.groups.first(where: { Set($0.fixtureIDs) == Set(selection) && !selection.isEmpty }) {
            let fam = Set(programmer.values.flatMap { $0.keys.map { $0.family } })
            let suffix = programmerFX.isEmpty ? (fam.count == 1 ? " " + fam.first!.title.uppercased() : "") : " FX"
            return g.name + suffix
        }
        return "List \(show.cuelists.count + 1)"
    }

    private func dominantColorIndex() -> Int {
        if !programmerFX.isEmpty { return 1 }
        let fams = Set(programmer.values.flatMap { $0.keys.map { $0.family } })
        if fams == [.intensity] { return 6 }
        if fams.contains(.position) { return 3 }
        if fams.contains(.color) { return 2 }
        return 0
    }

    func newGroupFromSelection() {
        guard !selection.isEmpty else { flash(t("msg.selectFirst")); return }
        let g = FixtureGroup(name: "Group \(show.groups.count + 1)", fixtureIDs: selection, colorIndex: show.groups.count)
        show.groups.append(g)
    }

    func loadCueToProgrammer(_ cue: Cue) {
        programmer = cue.values
        programmerFX = cue.effects
        selection = Array(Set(cue.values.keys).union(cue.effects.flatMap { $0.fixtureIDs })).sorted()
    }

    func deleteCuelist(_ id: UUID) {
        release(id)
        show.cuelists.removeAll { $0.id == id }
        show.buttons = show.buttons.filter { $0.value != id }
        for i in show.faders.indices where show.faders[i].kind == .cuelist(id) {
            show.faders[i] = FaderSlot()
        }
        states[id] = nil
    }

    // MARK: Patch

    func nextFreeAddress(universe: Int) -> Int {
        var end = 0
        for f in show.fixtures where f.universe == universe {
            let fp = profile(f.profileID)?.footprint ?? 1
            end = max(end, f.address - 1 + fp)
        }
        return min(512, end + 1)
    }

    func addFixtures(profileID: String, count: Int, startNumber: Int, name: String, universe: Int, address: Int, makeGroup: Bool) {
        guard let p = profile(profileID) else { return }
        var addr = address
        var num = startNumber
        var ids: [Int] = []
        for i in 0..<max(1, count) {
            while show.fixtures.contains(where: { $0.id == num }) { num += 1 }
            let label = count > 1 ? "\(name) \(i + 1)" : name
            show.fixtures.append(Fixture(id: num, name: label, profileID: profileID, universe: universe, address: addr))
            ids.append(num)
            num += 1
            addr += p.footprint
        }
        show.fixtures.sort { $0.id < $1.id }
        if makeGroup && ids.count > 0 {
            show.groups.append(FixtureGroup(name: name, fixtureIDs: ids, colorIndex: show.groups.count))
        }
    }

    func deleteFixtures(_ ids: Set<Int>) {
        show.fixtures.removeAll { ids.contains($0.id) }
        for i in show.groups.indices { show.groups[i].fixtureIDs.removeAll { ids.contains($0) } }
        selection.removeAll { ids.contains($0) }
        for id in ids { programmer[id] = nil }
    }

    /// Overlapping DMX addresses (shown in red in Patch).
    func conflicts() -> Set<Int> {
        var used: [Int: Int] = [:]
        var bad = Set<Int>()
        for f in show.fixtures {
            let fp = profile(f.profileID)?.footprint ?? 1
            for a in 0..<fp {
                let key = f.universe * 1000 + f.address + a
                if let other = used[key] { bad.insert(other); bad.insert(f.id) } else { used[key] = f.id }
            }
            if f.address + fp - 1 > 512 { bad.insert(f.id) }
        }
        return bad
    }

    // MARK: Outputs

    func applyOutputs() {
        output.configure(show.outputs)
    }

    func outputStatus(_ id: UUID) -> String? { output.status(id) }

    // MARK: Files

    static var autosaveURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Zohar", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("show.json")
    }

    static func loadAutosave() -> Show? {
        guard let data = try? Data(contentsOf: autosaveURL) else { return nil }
        return try? JSONDecoder().decode(Show.self, from: data)
    }

    func autosave() {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(show) {
            try? data.write(to: Console.autosaveURL, options: .atomic)
        }
        dirty = false
        lastSave = Date()
    }

    func newShow() {
        releaseAll()
        states.removeAll()
        programmer.removeAll()
        programmerFX.removeAll()
        selection.removeAll()
        show = Show()
        applyOutputs()
    }

    func saveAs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(show.name).zohar"
        panel.allowedContentTypes = [.json]
        panel.allowsOtherFileTypes = true
        if panel.runModal() == .OK, let url = panel.url {
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            do {
                try enc.encode(show).write(to: url, options: .atomic)
                flash(t("msg.saved"))
            } catch {
                flash(error.localizedDescription)
            }
        }
    }

    func open() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                let s = try JSONDecoder().decode(Show.self, from: data)
                releaseAll()
                states.removeAll()
                programmer.removeAll()
                programmerFX.removeAll()
                selection.removeAll()
                show = s
                resetFaderLevels()
                applyOutputs()
                autosave()
            } catch {
                flash("\(t("msg.openFailed")): \(error.localizedDescription)")
            }
        }
    }
}
