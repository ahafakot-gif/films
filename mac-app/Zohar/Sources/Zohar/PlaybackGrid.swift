import SwiftUI

struct PlaybackGrid: View {
    @EnvironmentObject var c: Console

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: Console.cols)
        ScrollView {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(0..<(Console.cols * Console.rows), id: \.self) { slot in
                    SlotButton(slot: slot)
                }
            }
            .padding(10)
        }
        .background(Color.black.opacity(c.theme == .dark ? 0.25 : 0.03))
    }
}

struct SlotButton: View {
    @EnvironmentObject var c: Console
    let slot: Int
    @State private var pressed = false

    var body: some View {
        let cl = c.cuelistAt(slot: slot)
        let active = cl.map { c.isActive($0.id) } ?? false
        let color = cl.map { Palette.color($0.colorIndex) } ?? Color.gray
        let st = cl.flatMap { c.states[$0.id] }

        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(cl == nil ? Color.primary.opacity(0.04) : (active ? color.opacity(0.9) : color.opacity(0.16)))
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(c.recordMode ? Color.red.opacity(0.7) : (active ? Color.white.opacity(0.7) : color.opacity(cl == nil ? 0.15 : 0.5)),
                              lineWidth: active ? 2 : 1)
            if let cl {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Image(systemName: cl.mode.icon).font(.system(size: 8))
                        if cl.chase { Image(systemName: "repeat").font(.system(size: 8)) }
                        Spacer()
                        Text(cl.cues.count > 1 ? "\((st?.cueIndex ?? 0) + 1)/\(cl.cues.count)" : "")
                            .font(.system(size: 9).monospacedDigit())
                    }
                    .opacity(0.8)
                    Spacer(minLength: 0)
                    Text(cl.name)
                        .font(.system(size: 11, weight: .bold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Spacer(minLength: 0)
                }
                .padding(6)
                .foregroundStyle(active ? Color.white : Color.primary)
            } else {
                Text("\(slot + 1)")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(5)
            }
        }
        .frame(height: 62)
        .scaleEffect(pressed ? 0.96 : 1)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !pressed {
                        pressed = true
                        down(cl)
                    }
                }
                .onEnded { _ in
                    pressed = false
                    if let cl { c.buttonUp(cl.id) }
                }
        )
        .contextMenu {
            if let cl {
                Button(c.t("cl.edit")) { c.sheet = .cuelist(cl.id) }
                Menu(c.t("cl.mode")) {
                    ForEach(ButtonMode.allCases) { m in
                        Button(c.t("mode.\(m.rawValue)")) { update(cl.id) { $0.mode = m } }
                    }
                }
                Menu(c.t("cl.color")) {
                    ForEach(0..<Palette.colors.count, id: \.self) { i in
                        Button("● \(i + 1)") { update(cl.id) { $0.colorIndex = i } }
                    }
                }
                Menu(c.t("cl.toFader")) {
                    ForEach(0..<10, id: \.self) { i in
                        Button("Fader \(i + 1)") { c.assignFader(i, .cuelist(cl.id)) }
                    }
                }
                Divider()
                Button(c.t("cl.release")) { c.release(cl.id) }
                Button(c.t("cl.removeButton")) { c.show.buttons[c.buttonKey(slot)] = nil }
                Button(c.t("cl.delete"), role: .destructive) { c.deleteCuelist(cl.id) }
            } else {
                Button(c.t("cl.recordHere")) { c.record(toSlot: slot) }
                    .disabled(c.programmerEmpty)
                if !c.show.cuelists.isEmpty {
                    Menu(c.t("cl.placeExisting")) {
                        ForEach(c.show.cuelists) { l in
                            Button(l.name) { c.show.buttons[c.buttonKey(slot)] = l.id }
                        }
                    }
                }
            }
        }
    }

    private func down(_ cl: Cuelist?) {
        if c.recordMode {
            c.record(toSlot: slot)
        } else if let cl {
            c.buttonDown(cl.id)
        }
    }

    private func update(_ id: UUID, _ change: (inout Cuelist) -> Void) {
        guard let i = c.cuelistIndex(id) else { return }
        change(&c.show.cuelists[i])
    }
}
