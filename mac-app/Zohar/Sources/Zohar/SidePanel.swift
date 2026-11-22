import SwiftUI

struct SidePanel: View {
    @EnvironmentObject var c: Console
    @State private var tab = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Picker("", selection: $tab) {
                    Text(c.t("side.groups")).tag(0)
                    Text(c.t("side.fixtures")).tag(1)
                    Text(c.t("side.colors")).tag(2)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 320)
                Spacer()
                Text(c.selection.isEmpty ? c.t("sel.none") : "\(c.t("sel.count")): \(c.selection.count)")
                    .font(.caption.bold())
                    .foregroundStyle(c.selection.isEmpty ? Color.secondary : Color.accentColor)
                Button(c.t("sel.clear")) { c.selection.removeAll() }
                    .controlSize(.small)
                    .disabled(c.selection.isEmpty)
            }
            .padding(10)

            Group {
                if tab == 0 { GroupsGrid() } else if tab == 1 { FixturesGrid() } else { ColorMatrixView() }
            }
            .frame(height: 250)

            Divider()
            ProgrammerView()
        }
    }
}

// MARK: - Groups

struct GroupsGrid: View {
    @EnvironmentObject var c: Console

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 6)], spacing: 6) {
                ForEach(c.show.groups) { g in
                    GroupTile(group: g)
                }
                Button {
                    c.newGroupFromSelection()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "plus")
                        Text(c.t("grp.new")).font(.system(size: 10)).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(RoundedRectangle(cornerRadius: 8).strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4])).foregroundStyle(.secondary))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 10)
        }
    }
}

struct GroupTile: View {
    @EnvironmentObject var c: Console
    let group: FixtureGroup
    @State private var renaming = false

    var body: some View {
        let selected = c.isGroupSelected(group)
        let color = Palette.color(group.colorIndex)
        Button {
            c.selectGroup(group)
        } label: {
            VStack(spacing: 2) {
                Text(group.name)
                    .font(.system(size: 11, weight: .bold))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text("\(group.fixtureIDs.count)")
                    .font(.system(size: 9))
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? color.opacity(0.85) : color.opacity(0.14))
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(height: 4).padding(.horizontal, 6).padding(.top, 3)
            }
            .foregroundStyle(selected ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $renaming) {
            TextField(c.t("ui.name"), text: Binding(
                get: { c.group(group.id)?.name ?? "" },
                set: { v in if let i = c.show.groups.firstIndex(where: { $0.id == group.id }) { c.show.groups[i].name = v } }
            ))
            .textFieldStyle(.roundedBorder)
            .frame(width: 200)
            .padding()
            .onSubmit { renaming = false }
        }
        .contextMenu {
            Button(c.t("grp.rename")) { renaming = true }
            Button(c.t("grp.update")) {
                if let i = c.show.groups.firstIndex(where: { $0.id == group.id }), !c.selection.isEmpty {
                    c.show.groups[i].fixtureIDs = c.selection
                }
            }
            .disabled(c.selection.isEmpty)
            Menu(c.t("cl.color")) {
                ForEach(0..<Palette.colors.count, id: \.self) { ci in
                    Button("● \(ci + 1)") {
                        if let i = c.show.groups.firstIndex(where: { $0.id == group.id }) { c.show.groups[i].colorIndex = ci }
                    }
                }
            }
            Menu(c.t("grp.master")) {
                ForEach(0..<10, id: \.self) { i in
                    Button("Fader \(i + 1)") { c.assignFader(i, .groupMaster(group.id)) }
                }
            }
            Divider()
            Button(c.t("grp.delete"), role: .destructive) {
                c.show.groups.removeAll { $0.id == group.id }
            }
        }
    }
}

// MARK: - Fixtures

struct FixturesGrid: View {
    @EnvironmentObject var c: Console

    var body: some View {
        if c.show.fixtures.isEmpty {
            VStack(spacing: 8) {
                Text(c.t("fx.noFixtures")).foregroundStyle(.secondary)
                Button(c.t("fx.openPatch")) { c.sheet = .patch }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 74), spacing: 5)], spacing: 5) {
                    ForEach(c.show.fixtures) { f in
                        let sel = c.selection.contains(f.id)
                        Button {
                            c.toggleFixture(f.id)
                        } label: {
                            VStack(spacing: 1) {
                                Text("\(f.id)").font(.system(size: 13, weight: .bold).monospacedDigit())
                                Text(f.name).font(.system(size: 9)).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(RoundedRectangle(cornerRadius: 6).fill(sel ? Color.accentColor.opacity(0.85) : Color.primary.opacity(0.06)))
                            .foregroundStyle(sel ? Color.white : Color.primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
    }
}

// MARK: - Programmer

struct ProgrammerView: View {
    @EnvironmentObject var c: Console
    @State private var family: Family = .intensity

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                ForEach(Family.allCases) { f in
                    let programmed = f == .fx ? !c.programmerFX.isEmpty : c.programmer.values.contains { $0.keys.contains { $0.family == f } }
                    Button {
                        family = f
                    } label: {
                        HStack(spacing: 4) {
                            Text(f.key)
                                .font(.system(size: 11, weight: .heavy))
                                .frame(width: 18, height: 18)
                                .background(RoundedRectangle(cornerRadius: 4).fill(f.color))
                                .foregroundStyle(.black)
                            Text(f.title).font(.system(size: 11, weight: .semibold))
                            if programmed { Circle().fill(f.color).frame(width: 6, height: 6) }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 7).fill(family == f ? f.color.opacity(0.28) : Color.primary.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
            .padding(10)

            Divider()

            if c.selection.isEmpty && family != .fx {
                Text(c.t("prog.selectHint"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        switch family {
                        case .intensity: IntensityPane()
                        case .position: PositionPane()
                        case .color: ColorPane()
                        case .gobo: AttrList(attrs: [.gobo, .goboRot, .gobo2, .prism, .prismRot])
                        case .beam: AttrList(attrs: [.shutter, .strobe, .zoom, .focus, .iris, .frost, .control, .other])
                        case .fx: FXPane()
                        }
                        HStack {
                            Spacer()
                            Button(c.t("prog.clearFamily") + " " + family.title) { c.clearFamily(family) }
                                .controlSize(.small)
                        }
                    }
                    .padding(14)
                }
            }
        }
    }
}

struct AttrSlider: View {
    @EnvironmentObject var c: Console
    let attr: Attr

    var body: some View {
        let v = c.value(attr)
        HStack(spacing: 10) {
            Circle()
                .fill(c.isProgrammed(attr) ? attr.family.color : Color.clear)
                .overlay(Circle().strokeBorder(attr.family.color.opacity(0.6)))
                .frame(width: 8, height: 8)
            Text(attr.label).font(.system(size: 12)).frame(width: 96, alignment: .leading)
            Slider(value: Binding(get: { c.value(attr) }, set: { c.set(attr, $0) }), in: 0...1)
            Text("\(Int((v * 255).rounded()))")
                .font(.system(size: 11).monospacedDigit())
                .frame(width: 30, alignment: .trailing)
            Stepper("", onIncrement: { c.set(attr, v + 1.0 / 255) }, onDecrement: { c.set(attr, v - 1.0 / 255) })
                .labelsHidden()
        }
    }
}

struct AttrList: View {
    @EnvironmentObject var c: Console
    let attrs: [Attr]

    var body: some View {
        let present = attrs.filter { c.selectedAttrs.contains($0) }
        if present.isEmpty {
            Text(c.t("prog.noAttrs")).foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(present) { AttrSlider(attr: $0) }
            }
        }
    }
}

struct IntensityPane: View {
    @EnvironmentObject var c: Console
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AttrSlider(attr: .dimmer)
            HStack(spacing: 6) {
                ForEach([0, 10, 25, 50, 75, 100], id: \.self) { p in
                    Button("\(p)%") { c.set(.dimmer, Double(p) / 100) }
                        .frame(maxWidth: .infinity)
                }
            }
            .controlSize(.large)
            if c.selectedAttrs.contains(.strobe) || c.selectedAttrs.contains(.shutter) {
                AttrList(attrs: [.shutter, .strobe])
            }
        }
    }
}

struct PositionPane: View {
    @EnvironmentObject var c: Console
    var body: some View {
        if !c.selectedAttrs.contains(.pan) && !c.selectedAttrs.contains(.tilt) {
            Text(c.t("prog.noAttrs")).foregroundStyle(.secondary)
        } else {
            HStack(alignment: .top, spacing: 16) {
                XYPad(
                    x: Binding(get: { c.value(.pan) }, set: { c.set(.pan, $0) }),
                    y: Binding(get: { c.value(.tilt) }, set: { c.set(.tilt, $0) })
                )
                .frame(width: 190, height: 190)
                VStack(alignment: .leading, spacing: 8) {
                    AttrList(attrs: [.pan, .tilt, .ptSpeed])
                    Button(c.t("pos.center")) { c.set(.pan, 0.5); c.set(.tilt, 0.5) }
                }
            }
        }
    }
}

struct XYPad: View {
    @Binding var x: Double
    @Binding var y: Double

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.primary.opacity(0.06))
                Path { p in
                    p.move(to: CGPoint(x: w / 2, y: 0)); p.addLine(to: CGPoint(x: w / 2, y: h))
                    p.move(to: CGPoint(x: 0, y: h / 2)); p.addLine(to: CGPoint(x: w, y: h / 2))
                }
                .stroke(Color.primary.opacity(0.15))
                Circle()
                    .fill(Family.position.color)
                    .frame(width: 18, height: 18)
                    .shadow(radius: 3)
                    .position(x: x * w, y: (1 - y) * h)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let nx = Double(g.location.x / w)
                let ny = 1.0 - Double(g.location.y / h)
                x = min(max(nx, 0), 1)
                y = min(max(ny, 0), 1)
            })
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct ColorPane: View {
    @EnvironmentObject var c: Console

    let swatches: [(String, Double, Double, Double, Double)] = [
        ("Red", 1, 0, 0, 0), ("Orange", 1, 0.45, 0, 0), ("Yellow", 1, 0.85, 0, 0),
        ("Green", 0, 1, 0, 0), ("Cyan", 0, 1, 1, 0), ("Blue", 0, 0, 1, 0),
        ("Lavender", 0.55, 0.35, 1, 0), ("Magenta", 1, 0, 1, 0), ("Pink", 1, 0.3, 0.55, 0),
        ("White", 1, 1, 1, 1), ("Warm", 1, 0.7, 0.35, 0.6), ("Cold", 0.7, 0.85, 1, 1),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 6), spacing: 6) {
                ForEach(0..<swatches.count, id: \.self) { i in
                    let s = swatches[i]
                    Button {
                        c.setColor(r: s.1, g: s.2, b: s.3, w: s.4)
                    } label: {
                        VStack(spacing: 3) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(red: s.1, green: s.2, blue: s.3))
                                .frame(height: 30)
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.2)))
                            Text(s.0).font(.system(size: 9))
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            AttrList(attrs: [.red, .green, .blue, .white, .amber, .uv, .cyan, .magenta, .yellow, .cto, .colorWheel])
        }
    }
}

struct FXPane: View {
    @EnvironmentObject var c: Console
    @State private var kind: FXKind = .dimSine
    @State private var bpm: Double = 60
    @State private var size: Double = 1
    @State private var spread: Double = 1
    @State private var steps: Int = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                ForEach(FXKind.allCases) { k in
                    Button {
                        kind = k
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: k.icon).font(.system(size: 15))
                            Text(k.label).font(.system(size: 10, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .background(RoundedRectangle(cornerRadius: 7).fill(kind == k ? Family.fx.color.opacity(0.4) : Color.primary.opacity(0.06)))
                    }
                    .buttonStyle(.plain)
                }
            }
            row("BPM", value: $bpm, range: 5...300, text: "\(Int(bpm))")
            row(c.t("fx.size"), value: $size, range: 0...1, text: "\(Int(size * 100))%")
            row(c.t("fx.spread"), value: $spread, range: 0...1, text: "\(Int(spread * 100))%")
            if kind == .dimChase {
                Stepper("\(c.t("fx.steps")): \(steps)", value: $steps, in: 1...16)
            }
            Button {
                c.addEffect(kind, bpm: bpm, size: size, spread: spread, steps: steps)
            } label: {
                Label(c.t("fx.add"), systemImage: "plus.circle.fill").frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .disabled(c.selection.isEmpty)

            if !c.programmerFX.isEmpty {
                Divider()
                ForEach(c.programmerFX) { e in
                    HStack {
                        Image(systemName: e.kind.icon).foregroundStyle(Family.fx.color)
                        Text("\(e.kind.label) · \(e.fixtureIDs.count) fx · \(Int(e.bpm)) BPM · \(Int(e.size * 100))%")
                            .font(.callout)
                        Spacer()
                        Button {
                            c.programmerFX.removeAll { $0.id == e.id }
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    func row(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, text: String) -> some View {
        HStack {
            Text(title).frame(width: 90, alignment: .leading)
            Slider(value: value, in: range)
            Text(text).font(.callout.monospacedDigit()).frame(width: 44, alignment: .trailing)
        }
    }
}
