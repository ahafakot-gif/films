import SwiftUI

struct FaderBank: View {
    @EnvironmentObject var c: Console

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<c.show.faders.count, id: \.self) { i in
                FaderStrip(index: i)
            }
        }
        .padding(10)
        .background(Color.black.opacity(c.theme == .dark ? 0.3 : 0.04))
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct FaderStrip: View {
    @EnvironmentObject var c: Console
    let index: Int
    @State private var flashDown = false

    var slot: FaderSlot { c.show.faders[index] }

    var accent: Color {
        switch slot.kind {
        case .none: return .gray
        case .cuelist(let id): return Palette.color(c.cuelist(id)?.colorIndex ?? 0)
        case .groupMaster(let id): return Palette.color(c.group(id)?.colorIndex ?? 0)
        case .speedMaster, .sizeMaster: return Family.fx.color
        }
    }

    var cuelistID: UUID? {
        if case .cuelist(let id) = slot.kind { return id }
        return nil
    }

    var body: some View {
        let active = cuelistID.map { c.isActive($0) } ?? false
        VStack(spacing: 5) {
            HStack(spacing: 2) {
                if c.recordMode {
                    Button {
                        c.record(toFader: index)
                    } label: {
                        Text("REC \(index + 1)")
                            .font(.system(size: 10, weight: .heavy))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 3)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.red))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text(c.faderTitle(slot))
                        .font(.system(size: 10, weight: .bold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
                Menu {
                    Button(c.t("fd.none")) { c.assignFader(index, .none) }
                    Button("FX SPEED") { c.assignFader(index, .speedMaster) }
                    Button("FX SIZE") { c.assignFader(index, .sizeMaster) }
                    if !c.show.cuelists.isEmpty {
                        Menu(c.t("fd.cuelist")) {
                            ForEach(c.show.cuelists) { l in
                                Button(l.name) { c.assignFader(index, .cuelist(l.id)) }
                            }
                        }
                    }
                    if !c.show.groups.isEmpty {
                        Menu(c.t("fd.groupMaster")) {
                            ForEach(c.show.groups) { g in
                                Button(g.name) { c.assignFader(index, .groupMaster(g.id)) }
                            }
                        }
                    }
                    if let id = cuelistID {
                        Divider()
                        Button(c.t("cl.edit")) { c.sheet = .cuelist(id) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .frame(width: 18)
            }
            .frame(height: 18)

            Rectangle().fill(accent).frame(height: 3).cornerRadius(1.5)

            VerticalFader(value: Binding(get: { c.show.faders[index].level }, set: { c.setFader(index, $0) }),
                          color: accent, enabled: slot.kind != .none)

            Text(slot.kind == .speedMaster ? String(format: "×%.2f", slot.level * 2) : "\(Int(slot.level * 100))%")
                .font(.system(size: 10).monospacedDigit())
                .foregroundStyle(.secondary)

            HStack(spacing: 3) {
                Button {
                    if let id = cuelistID { c.go(id, level: slot.level > 0.004 ? slot.level : 1) }
                } label: {
                    Text("GO")
                        .font(.system(size: 10, weight: .heavy))
                        .frame(maxWidth: .infinity, minHeight: 22)
                        .background(RoundedRectangle(cornerRadius: 5).fill(active ? Color.green.opacity(0.8) : Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)

                Text("FL")
                    .font(.system(size: 10, weight: .heavy))
                    .frame(maxWidth: .infinity, minHeight: 22)
                    .background(RoundedRectangle(cornerRadius: 5).fill(flashDown ? accent : Color.primary.opacity(0.08)))
                    .gesture(DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            if !flashDown { flashDown = true; c.faderFlash(index, down: true) }
                        }
                        .onEnded { _ in
                            flashDown = false
                            c.faderFlash(index, down: false)
                        })
            }
            .disabled(cuelistID == nil)
            .opacity(cuelistID == nil ? 0.3 : 1)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(active ? 0.10 : 0.04)))
    }
}

struct VerticalFader: View {
    @Binding var value: Double
    var color: Color
    var enabled: Bool

    var body: some View {
        GeometryReader { geo in
            let h = geo.size.height
            let knob: CGFloat = 22
            let travel = max(1, h - knob)
            ZStack(alignment: .bottom) {
                Capsule().fill(Color.primary.opacity(0.10)).frame(width: 6)
                Capsule().fill(color.opacity(enabled ? 0.9 : 0.2))
                    .frame(width: 6, height: knob / 2 + CGFloat(value) * travel)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .controlColor))
                    .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(Color.primary.opacity(0.3)))
                    .overlay(Rectangle().fill(Color.primary.opacity(0.6)).frame(height: 2))
                    .frame(width: 34, height: knob)
                    .offset(y: -CGFloat(value) * travel)
                    .shadow(radius: 1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                guard enabled else { return }
                let v = 1 - (g.location.y - knob / 2) / travel
                value = Double(min(max(v, 0), 1))
            })
            .onTapGesture(count: 2) {
                if enabled { value = value > 0.5 ? 0 : 1 }
            }
        }
        .frame(minHeight: 90)
    }
}
