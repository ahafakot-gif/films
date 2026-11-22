import SwiftUI

struct ColorMatrixView: View {
    @EnvironmentObject var c: Console

    var body: some View {
        if c.show.groups.isEmpty {
            Text(c.t("cm.noGroups"))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView([.vertical, .horizontal]) {
                Grid(horizontalSpacing: 4, verticalSpacing: 4) {
                    GridRow {
                        Text("").frame(width: 110)
                        ForEach(0..<MatrixColor.all.count, id: \.self) { ci in
                            Text(MatrixColor.all[ci].name)
                                .font(.system(size: 9, weight: .semibold))
                                .frame(width: 58)
                        }
                    }
                    ForEach(c.show.groups) { g in
                        GridRow {
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2).fill(Palette.color(g.colorIndex)).frame(width: 4, height: 26)
                                Text(g.name).font(.system(size: 11, weight: .bold)).lineLimit(1)
                                Spacer(minLength: 0)
                                if c.groupColors[g.id] != nil {
                                    Button { c.groupColors[g.id] = nil } label: { Image(systemName: "xmark.circle.fill") }
                                        .buttonStyle(.borderless)
                                        .help(c.t("cm.off"))
                                }
                            }
                            .frame(width: 110)
                            ForEach(0..<MatrixColor.all.count, id: \.self) { ci in
                                let mc = MatrixColor.all[ci]
                                let on = c.groupColors[g.id] == ci
                                Button {
                                    c.toggleGroupColor(g.id, ci)
                                } label: {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(mc.color.opacity(on ? 1 : 0.35))
                                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(on ? Color.white : Color.clear, lineWidth: 3))
                                        .frame(width: 58, height: 34)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .environment(\.layoutDirection, .leftToRight)
        }
    }
}

struct BigClock: View {
    var size: CGFloat = 64
    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { ctx in
            Text(ctx.date, format: .dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
                .font(.system(size: size, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(red: 1, green: 0.2, blue: 0.15))
                .environment(\.locale, Locale(identifier: "en_GB"))
        }
    }
}
