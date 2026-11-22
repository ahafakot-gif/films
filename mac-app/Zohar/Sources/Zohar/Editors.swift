import SwiftUI

// MARK: - Cuelist editor

struct CuelistEditor: View {
    @EnvironmentObject var c: Console
    @Environment(\.dismiss) private var dismiss
    let id: UUID

    var index: Int? { c.cuelistIndex(id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let i = index {
                HStack {
                    TextField(c.t("ui.name"), text: $c.show.cuelists[i].name)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                    Spacer()
                    Button(c.t("ui.done")) { dismiss() }
                        .keyboardShortcut(.defaultAction)
                }

                HStack(spacing: 18) {
                    Picker(c.t("cl.mode"), selection: $c.show.cuelists[i].mode) {
                        ForEach(ButtonMode.allCases) { Text(c.t("mode.\($0.rawValue)")).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)

                    HStack(spacing: 4) {
                        ForEach(0..<Palette.colors.count, id: \.self) { ci in
                            Circle()
                                .fill(Palette.color(ci))
                                .frame(width: 18, height: 18)
                                .overlay(Circle().strokeBorder(Color.primary, lineWidth: c.show.cuelists[i].colorIndex == ci ? 2 : 0))
                                .onTapGesture { c.show.cuelists[i].colorIndex = ci }
                        }
                    }
                }

                HStack(spacing: 18) {
                    HStack {
                        Text(c.t("cl.fadeOut"))
                        TextField("", value: $c.show.cuelists[i].fadeOut, format: .number)
                            .frame(width: 50)
                            .textFieldStyle(.roundedBorder)
                        Text(c.t("ui.sec"))
                    }
                    Toggle(c.t("cl.chase"), isOn: $c.show.cuelists[i].chase)
                    if c.show.cuelists[i].chase {
                        HStack {
                            Text("BPM")
                            Slider(value: $c.show.cuelists[i].chaseBPM, in: 10...300).frame(width: 160)
                            Text("\(Int(c.show.cuelists[i].chaseBPM))").monospacedDigit().frame(width: 34)
                        }
                    }
                }

                Divider()
                Text(c.t("cl.cues")).font(.headline)

                List {
                    ForEach(c.show.cuelists[i].cues) { cue in
                        let ci = c.show.cuelists[i].cues.firstIndex(where: { $0.id == cue.id }) ?? 0
                        HStack(spacing: 10) {
                            Text("\(ci + 1)").monospacedDigit().frame(width: 24)
                            TextField("", text: cueBinding(cue.id, \.name, ""))
                                .textFieldStyle(.roundedBorder)
                                .frame(minWidth: 140)
                            Text("\(cue.values.count) fx · \(cue.effects.count) FX")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 90)
                            Text(c.t("cl.fadeIn"))
                                .font(.caption)
                            TextField("", value: cueBinding(cue.id, \.fadeIn, 0), format: .number)
                                .frame(width: 44)
                                .textFieldStyle(.roundedBorder)
                            Spacer()
                            Button { c.jump(id, to: ci) } label: { Image(systemName: "play.fill") }
                                .help(c.t("cue.play"))
                            Button { c.loadCueToProgrammer(cue) } label: { Image(systemName: "square.and.arrow.down") }
                                .help(c.t("cue.load"))
                            Button {
                                editCue(cue.id) {
                                    $0.values = c.programmer.filter { !$0.value.isEmpty }
                                    $0.effects = c.programmerFX
                                }
                                c.flash(c.t("cue.replaced"))
                            } label: { Image(systemName: "square.and.arrow.up") }
                                .help(c.t("cue.replace"))
                                .disabled(c.programmerEmpty)
                            Button {
                                moveUp(cue.id)
                            } label: { Image(systemName: "arrow.up") }
                                .disabled(ci == 0)
                            Button(role: .destructive) {
                                removeCue(cue.id)
                            } label: { Image(systemName: "trash") }
                                .disabled(c.show.cuelists[i].cues.count <= 1)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .frame(minHeight: 220)

                HStack {
                    Text(c.t("cl.tip")).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button(c.t("cl.delete"), role: .destructive) {
                        dismiss()
                        c.deleteCuelist(id)
                    }
                }
            } else {
                Text("—")
                Button(c.t("ui.done")) { dismiss() }
            }
        }
        .padding(20)
        .frame(width: 820, height: 560)
    }

    private func cueBinding<T>(_ cueID: UUID, _ kp: WritableKeyPath<Cue, T>, _ fallback: T) -> Binding<T> {
        Binding(
            get: {
                guard let li = c.cuelistIndex(id),
                      let ci = c.show.cuelists[li].cues.firstIndex(where: { $0.id == cueID }) else { return fallback }
                return c.show.cuelists[li].cues[ci][keyPath: kp]
            },
            set: { v in editCue(cueID) { $0[keyPath: kp] = v } }
        )
    }

    private func editCue(_ cueID: UUID, _ change: (inout Cue) -> Void) {
        guard let li = c.cuelistIndex(id),
              let ci = c.show.cuelists[li].cues.firstIndex(where: { $0.id == cueID }) else { return }
        change(&c.show.cuelists[li].cues[ci])
    }

    private func moveUp(_ cueID: UUID) {
        guard let li = c.cuelistIndex(id),
              let ci = c.show.cuelists[li].cues.firstIndex(where: { $0.id == cueID }), ci > 0 else { return }
        c.show.cuelists[li].cues.swapAt(ci, ci - 1)
    }

    private func removeCue(_ cueID: UUID) {
        guard let li = c.cuelistIndex(id), c.show.cuelists[li].cues.count > 1 else { return }
        c.release(id)
        c.show.cuelists[li].cues.removeAll { $0.id == cueID }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @EnvironmentObject var c: Console
    @Environment(\.dismiss) private var dismiss
    @State private var ports: [String] = SerialPorts.list()
    @State private var nodes: [ArtNode] = []
    @State private var searching = false
    @State private var searched = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(c.t("set.title")).font(.title2.bold())
                Spacer()
                Button(c.t("ui.done")) {
                    c.applyOutputs()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }

            HStack(spacing: 24) {
                Picker(c.t("ui.language"), selection: $c.lang) {
                    ForEach(Lang.allCases) { Text($0.title).tag($0) }
                }
                .frame(width: 220)
                Picker(c.t("ui.theme"), selection: $c.theme) {
                    Text(c.t("theme.dark")).tag(Theme.dark)
                    Text(c.t("theme.light")).tag(Theme.light)
                }
                .frame(width: 220)
                TextField(c.t("set.showName"), text: $c.show.name)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }

            Divider()
            HStack {
                Text(c.t("set.outputs")).font(.headline)
                Spacer()
                Button {
                    ports = SerialPorts.list()
                } label: { Label(c.t("set.refreshPorts"), systemImage: "arrow.clockwise") }
                Button {
                    var o = OutputConfig()
                    o.universe = (c.show.outputs.map { $0.universe }.max() ?? 0) + 1
                    c.show.outputs.append(o)
                } label: { Label(c.t("set.addOutput"), systemImage: "plus") }
            }

            ScrollView {
                VStack(spacing: 10) {
                    ForEach($c.show.outputs) { $o in
                        HStack(spacing: 12) {
                            Toggle("", isOn: $o.enabled).labelsHidden()
                            Stepper("\(c.t("set.universe")) \(o.universe)", value: $o.universe, in: 1...64)
                                .frame(width: 140)
                            Picker("", selection: $o.type) {
                                ForEach(OutputType.allCases) { Text($0.label).tag($0) }
                            }
                            .labelsHidden()
                            .frame(width: 200)
                            if o.type == .artnet {
                                TextField("IP", text: $o.ip).textFieldStyle(.roundedBorder).frame(width: 140)
                                Stepper("Art-Net \(o.artUniverse)", value: $o.artUniverse, in: 0...32767).frame(width: 130)
                            } else {
                                Picker("", selection: $o.port) {
                                    Text(c.t("set.choosePort")).tag("")
                                    ForEach(Array(Set(ports + (o.port.isEmpty ? [] : [o.port]))).sorted(), id: \.self) { p in
                                        Text(p.replacingOccurrences(of: "/dev/", with: "")).tag(p)
                                    }
                                }
                                .labelsHidden()
                                .frame(width: 280)
                            }
                            Spacer()
                            Text(c.outputStatus(o.id) ?? "—")
                                .font(.caption.bold())
                                .foregroundStyle(c.outputStatus(o.id) == "OK" ? Color.green : Color.secondary)
                            Button(role: .destructive) {
                                c.show.outputs.removeAll { $0.id == o.id }
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.borderless)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.05)))
                    }
                }
            }

            Divider()
            HStack {
                Text("Art-Net").font(.headline)
                Text("Mac: " + ArtNetDiscovery.interfaces().map { "\($0.iface.name) \($0.iface.ip)" }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if searching { ProgressView().controlSize(.small) }
                Button {
                    searching = true
                    Task {
                        nodes = await ArtNetDiscovery.discover()
                        searching = false
                        searched = true
                    }
                } label: { Label(c.t("an.search"), systemImage: "antenna.radiowaves.left.and.right") }
                .disabled(searching)
            }
            if searched && nodes.isEmpty {
                Text(c.t("an.none")).font(.caption).foregroundStyle(.orange)
            }
            ForEach(nodes) { n in
                HStack(spacing: 12) {
                    Image(systemName: "network").foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(n.name.isEmpty ? "Art-Net node" : n.name)  ·  \(n.ip)").font(.callout.bold())
                        Text("\(c.t("an.universes")): \(n.universes.map(String.init).joined(separator: ", "))  \(n.longName)")
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Menu(c.t("an.create")) {
                        Button(c.t("an.createFrom0")) { makeOutputs(n, firstArt: 0) }
                        Button(c.t("an.createFrom1")) { makeOutputs(n, firstArt: 1) }
                        if !n.universes.isEmpty {
                            Button(c.t("an.createNode")) { makeOutputs(n, firstArt: nil) }
                        }
                    }
                    .frame(width: 220)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.green.opacity(0.08)))
            }

            Divider()
            HStack {
                Text("MIDI").font(.headline)
                Text(c.midiDevices.isEmpty ? c.t("midi.noDevices") : c.midiDevices.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(c.t("midi.learnGM")) { c.midiLearn = true; c.learnTarget = .grandMaster; dismiss() }
                Button(c.t("midi.learnBO")) { c.midiLearn = true; c.learnTarget = .blackout; dismiss() }
                Button { c.refreshMIDI() } label: { Image(systemName: "arrow.clockwise") }
                Button(c.t("midi.clear"), role: .destructive) { c.show.midiMaps.removeAll() }
                    .disabled(c.show.midiMaps.isEmpty)
            }
            if !c.show.midiMaps.isEmpty {
                Text(c.show.midiMaps.map { "\($0.kind == .note ? "Note" : "CC") \($0.number) → \(c.midiLabel($0.target))" }.joined(separator: "   ·   "))
                    .font(.caption)
                    .lineLimit(3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(c.t("set.help1")).font(.caption)
                Text(c.t("set.help2")).font(.caption)
                Text(c.t("set.help3")).font(.caption)
            }
            .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(width: 980, height: 760)
        .onChange(of: c.show.outputs) { _ in c.applyOutputs() }
    }

    /// Replace outputs with universes 1…8 sent to this node.
    private func makeOutputs(_ n: ArtNode, firstArt: Int?) {
        var outs: [OutputConfig] = []
        let count = max(8, n.universes.count)
        for i in 0..<count {
            var o = OutputConfig()
            o.universe = i + 1
            o.type = .artnet
            o.ip = n.ip
            if let f = firstArt {
                o.artUniverse = f + i
            } else {
                o.artUniverse = i < n.universes.count ? n.universes[i] : (n.universes.last ?? 0) + i - n.universes.count + 1
            }
            outs.append(o)
        }
        c.show.outputs = outs
        c.applyOutputs()
        c.flash(c.t("an.done"))
    }
}
