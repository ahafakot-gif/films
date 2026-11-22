import SwiftUI

struct PatchView: View {
    @EnvironmentObject var c: Console
    @Environment(\.dismiss) private var dismiss
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Patch").font(.title2.bold())
                Picker("", selection: $tab) {
                    Text(c.t("patch.fixtures")).tag(0)
                    Text(c.t("patch.profiles")).tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 260)
                Spacer()
                Button(c.t("ui.done")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
            Divider()
            if tab == 0 { FixturePatch() } else { ProfileEditor() }
        }
        .frame(width: 1040, height: 680)
    }
}

// MARK: - Fixtures

struct FixturePatch: View {
    @EnvironmentObject var c: Console
    @State private var selected: Set<Int> = []

    // add form
    @State private var profileID = Profiles.builtins[5].id
    @State private var count = 1
    @State private var startNumber = 1
    @State private var name = "Spot"
    @State private var universe = 1
    @State private var address = 1
    @State private var makeGroup = true

    var body: some View {
        let conflicts = c.conflicts()
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                Table(c.show.fixtures, selection: $selected) {
                    TableColumn("#") { f in
                        Text("\(f.id)").monospacedDigit()
                            .foregroundStyle(conflicts.contains(f.id) ? Color.red : Color.primary)
                    }
                    .width(44)
                    TableColumn(c.t("ui.name")) { f in Text(f.name) }
                    TableColumn(c.t("patch.profile")) { f in Text(c.profile(f.profileID)?.name ?? "?").foregroundStyle(.secondary) }
                    TableColumn("U") { f in Text("\(f.universe)").monospacedDigit() }.width(30)
                    TableColumn(c.t("patch.address")) { f in
                        let fp = c.profile(f.profileID)?.footprint ?? 1
                        Text("\(f.address)–\(f.address + fp - 1)")
                            .monospacedDigit()
                            .foregroundStyle(conflicts.contains(f.id) ? Color.red : Color.primary)
                    }
                    .width(80)
                }
                HStack {
                    if !conflicts.isEmpty {
                        Label(c.t("patch.conflict"), systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.caption)
                    }
                    Spacer()
                    Text("\(c.show.fixtures.count) \(c.t("patch.count"))").font(.caption).foregroundStyle(.secondary)
                    Button(role: .destructive) {
                        c.deleteFixtures(selected)
                        selected.removeAll()
                    } label: { Label(c.t("patch.delete"), systemImage: "trash") }
                    .disabled(selected.isEmpty)
                }
            }
            .padding(16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if selected.count == 1, let fid = selected.first, let fi = c.show.fixtures.firstIndex(where: { $0.id == fid }) {
                        Text(c.t("patch.edit")).font(.headline)
                        TextField(c.t("ui.name"), text: $c.show.fixtures[fi].name).textFieldStyle(.roundedBorder)
                        Picker(c.t("patch.profile"), selection: $c.show.fixtures[fi].profileID) {
                            ForEach(c.show.profiles) { Text($0.name).tag($0.id) }
                        }
                        Stepper("\(c.t("set.universe")): \(c.show.fixtures[fi].universe)", value: $c.show.fixtures[fi].universe, in: 1...64)
                        Stepper("\(c.t("patch.address")): \(c.show.fixtures[fi].address)", value: $c.show.fixtures[fi].address, in: 1...512)
                        Divider()
                    }

                    Text(c.t("patch.add")).font(.headline)
                    Picker(c.t("patch.profile"), selection: $profileID) {
                        ForEach(c.show.profiles) { p in Text("\(p.name)").tag(p.id) }
                    }
                    TextField(c.t("ui.name"), text: $name).textFieldStyle(.roundedBorder)
                    Stepper("\(c.t("patch.howMany")): \(count)", value: $count, in: 1...128)
                    Stepper("\(c.t("patch.startNumber")): \(startNumber)", value: $startNumber, in: 1...9999)
                    Stepper("\(c.t("set.universe")): \(universe)", value: $universe, in: 1...64)
                    HStack {
                        Stepper("\(c.t("patch.address")): \(address)", value: $address, in: 1...512)
                        Button(c.t("patch.nextFree")) { address = c.nextFreeAddress(universe: universe) }
                            .controlSize(.small)
                    }
                    if let p = c.profile(profileID) {
                        Text("\(p.footprint) \(c.t("patch.channels")) · \(address)–\(address + p.footprint * count - 1)")
                            .font(.caption)
                            .foregroundStyle(address + p.footprint * count - 1 > 512 ? Color.red : Color.secondary)
                    }
                    Toggle(c.t("patch.makeGroup"), isOn: $makeGroup)
                    Button {
                        c.addFixtures(profileID: profileID, count: count, startNumber: startNumber, name: name,
                                      universe: universe, address: address, makeGroup: makeGroup)
                        startNumber = (c.show.fixtures.map { $0.id }.max() ?? 0) + 1
                        address = c.nextFreeAddress(universe: universe)
                    } label: {
                        Label(c.t("patch.addButton"), systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .padding(16)
            }
            .frame(width: 340)
        }
        .onAppear {
            startNumber = (c.show.fixtures.map { $0.id }.max() ?? 0) + 1
            address = c.nextFreeAddress(universe: universe)
        }
    }
}

// MARK: - Profiles

struct ProfileEditor: View {
    @EnvironmentObject var c: Console
    @State private var selectedID: String? = nil

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                List(selection: $selectedID) {
                    ForEach(c.show.profiles) { p in
                        HStack {
                            Text(p.name)
                            Spacer()
                            Text("\(p.footprint)ch").font(.caption).foregroundStyle(.secondary)
                        }
                        .tag(p.id)
                    }
                }
                HStack {
                    Button {
                        let p = FixtureProfile(name: "New fixture", channels: [ChannelDef(.dimmer)])
                        c.show.profiles.append(p)
                        selectedID = p.id
                    } label: { Label(c.t("prof.new"), systemImage: "plus") }
                    Button {
                        guard let id = selectedID, let p = c.profile(id) else { return }
                        var copy = p
                        copy.id = UUID().uuidString
                        copy.name = p.name + " copy"
                        c.show.profiles.append(copy)
                        selectedID = copy.id
                    } label: { Label(c.t("prof.duplicate"), systemImage: "plus.square.on.square") }
                    .disabled(selectedID == nil)
                    Spacer()
                    Button(role: .destructive) {
                        guard let id = selectedID else { return }
                        c.show.profiles.removeAll { $0.id == id }
                        selectedID = nil
                    } label: { Image(systemName: "trash") }
                    .disabled(selectedID == nil || c.show.fixtures.contains { $0.profileID == selectedID })
                    .help(c.t("prof.inUse"))
                }
            }
            .padding(16)
            .frame(width: 340)

            Divider()

            if let id = selectedID, let pi = c.show.profiles.firstIndex(where: { $0.id == id }) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField(c.t("ui.name"), text: $c.show.profiles[pi].name)
                        .textFieldStyle(.roundedBorder)
                        .font(.title3)
                    Text(c.t("prof.hint")).font(.caption).foregroundStyle(.secondary)
                    List {
                        ForEach(c.show.profiles[pi].channels) { ch in
                            let ci = c.show.profiles[pi].channels.firstIndex(where: { $0.id == ch.id }) ?? 0
                            HStack(spacing: 10) {
                                Text("\(ci + 1)").monospacedDigit().frame(width: 26)
                                Picker("", selection: chBinding(id, ch.id, \.attr, .other)) {
                                    ForEach(Attr.allCases) { a in Text(a.label).tag(a) }
                                }
                                .labelsHidden()
                                .frame(width: 170)
                                Text(c.t("prof.default")).font(.caption)
                                TextField("", value: Binding(
                                    get: { Int((chBinding(id, ch.id, \.def, 0).wrappedValue * 255).rounded()) },
                                    set: { chBinding(id, ch.id, \.def, 0).wrappedValue = Double(min(max($0, 0), 255)) / 255 }
                                ), format: .number)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                                Spacer()
                                Button {
                                    editProfile(id) { p in
                                        if let k = p.channels.firstIndex(where: { $0.id == ch.id }), k > 0 { p.channels.swapAt(k, k - 1) }
                                    }
                                } label: { Image(systemName: "arrow.up") }
                                .disabled(ci == 0)
                                Button {
                                    editProfile(id) { p in
                                        if p.channels.count > 1 { p.channels.removeAll { $0.id == ch.id } }
                                    }
                                } label: { Image(systemName: "minus.circle") }
                                .disabled(c.show.profiles[pi].channels.count <= 1)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    HStack {
                        Button {
                            c.show.profiles[pi].channels.append(ChannelDef(.other))
                        } label: { Label(c.t("prof.addChannel"), systemImage: "plus") }
                        Spacer()
                        Text("\(c.show.profiles[pi].footprint) \(c.t("patch.channels"))").foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            } else {
                Text(c.t("prof.select"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

extension ProfileEditor {
    func editProfile(_ pid: String, _ change: (inout FixtureProfile) -> Void) {
        guard let pi = c.show.profiles.firstIndex(where: { $0.id == pid }) else { return }
        change(&c.show.profiles[pi])
    }

    func chBinding<T>(_ pid: String, _ chID: UUID, _ kp: WritableKeyPath<ChannelDef, T>, _ fallback: T) -> Binding<T> {
        Binding(
            get: {
                guard let pi = c.show.profiles.firstIndex(where: { $0.id == pid }),
                      let k = c.show.profiles[pi].channels.firstIndex(where: { $0.id == chID }) else { return fallback }
                return c.show.profiles[pi].channels[k][keyPath: kp]
            },
            set: { v in editProfile(pid) { p in
                if let k = p.channels.firstIndex(where: { $0.id == chID }) { p.channels[k][keyPath: kp] = v }
            } }
        )
    }
}
