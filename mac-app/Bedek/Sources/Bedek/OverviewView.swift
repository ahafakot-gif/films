import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var s: AppState
    @State private var info = SystemInfo.current()
    @State private var smart: String = "…"
    @State private var verifying = false
    @State private var verifyOK: Bool? = nil

    var usedFraction: Double {
        guard info.diskTotal > 0 else { return 0 }
        return Double(info.diskTotal - info.diskFree) / Double(info.diskTotal)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top) {
                    PageHeader(title: s.t("nav.overview"), subtitle: s.t("ov.subtitle"))
                    Button {
                        info = SystemInfo.current()
                        Task { await loadSmart() }
                    } label: {
                        Label(s.t("ov.refresh"), systemImage: "arrow.clockwise")
                    }
                }

                Card {
                    HStack {
                        Label(s.t("ov.disk"), systemImage: "internaldrive").font(.headline)
                        Spacer()
                        Text("\(Fmt.bytes(info.diskFree)) \(s.t("ov.free")) \(s.t("ov.of")) \(Fmt.bytes(info.diskTotal))")
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: usedFraction)
                        .tint(usedFraction > 0.9 ? .red : (usedFraction > 0.75 ? .orange : .accentTeal))
                    if usedFraction > 0.9 {
                        Label(s.t("ov.lowSpace"), systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
                    InfoTile(icon: "desktopcomputer", title: s.t("ov.macos"), value: info.macOS)
                    InfoTile(icon: "laptopcomputer", title: s.t("ov.model"), value: info.model)
                    InfoTile(icon: "cpu", title: s.t("ov.cpu"), value: info.cpu)
                    InfoTile(icon: "memorychip", title: s.t("ov.memory"), value: Fmt.bytes(info.memory))
                    InfoTile(icon: "clock", title: s.t("ov.uptime"), value: Fmt.duration(info.uptime, lang: s.lang))
                    InfoTile(icon: "heart.text.square", title: s.t("ov.smart"),
                             value: smart == "Verified" ? s.t("ov.smartOK") : smart,
                             valueColor: smart == "Verified" ? .green : (smart == "…" ? .primary : .orange))
                }

                Card {
                    HStack(alignment: .center, spacing: 14) {
                        Image(systemName: "stethoscope")
                            .font(.system(size: 26))
                            .foregroundStyle(Color.accentTeal)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(s.t("ov.verify")).font(.headline)
                            Text(s.t("ov.verifyHint")).font(.callout).foregroundStyle(.secondary)
                            if verifying {
                                Text(s.t("ov.verifying")).font(.callout)
                            } else if let ok = verifyOK {
                                Label(ok ? s.t("ov.verifyOK") : s.t("ov.verifyFail"),
                                      systemImage: ok ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                    .foregroundStyle(ok ? .green : .orange)
                            }
                        }
                        Spacer()
                        if verifying { ProgressView().controlSize(.small) }
                        Button(s.t("ov.verify")) { Task { await verify() } }
                            .buttonStyle(.borderedProminent)
                            .tint(.accentTeal)
                            .disabled(verifying)
                    }
                }
            }
            .padding(28)
        }
        .task { await loadSmart() }
    }

    func loadSmart() async {
        let r = await Shell.run("diskutil info disk0 | awk -F: '/SMART Status/ {sub(/^ +/, \"\", $2); print $2}'")
        let v = r.output.trimmingCharacters(in: .whitespacesAndNewlines)
        smart = v.isEmpty ? "—" : v
    }

    func verify() async {
        verifying = true
        verifyOK = nil
        s.add(s.t("ov.verifying"))
        let r = await Shell.runArgs("/usr/sbin/diskutil", ["verifyVolume", "/"])
        s.add(result: r)
        verifyOK = r.ok
        s.add(r.ok ? s.t("ov.verifyOK") : s.t("ov.verifyFail"), r.ok ? .ok : .error)
        verifying = false
    }
}

struct InfoTile: View {
    let icon: String
    let title: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        Card {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(Color.accentTeal)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.caption).foregroundStyle(.secondary)
                    Text(value).font(.system(size: 15, weight: .semibold)).foregroundStyle(valueColor)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
    }
}
