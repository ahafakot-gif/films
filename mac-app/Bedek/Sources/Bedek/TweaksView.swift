import AppKit
import SwiftUI

struct Tweak: Identifiable {
    let id: String
    let icon: String
    let read: () -> Bool
    let write: (Bool) -> String

    static func boolPref(_ id: String, _ icon: String, domain: String, key: String, restart: String) -> Tweak {
        Tweak(id: id, icon: icon,
              read: { Prefs.bool(domain, key) },
              write: { on in "defaults write \(domain) \(key) -bool \(on ? "true" : "false"); killall \(restart) 2>/dev/null; true" })
    }

    static let finder: [Tweak] = [
        .boolPref("hidden", "eye.slash", domain: "com.apple.finder", key: "AppleShowAllFiles", restart: "Finder"),
        .boolPref("ext", "doc.text", domain: "NSGlobalDomain", key: "AppleShowAllExtensions", restart: "Finder"),
        .boolPref("pathbar", "folder", domain: "com.apple.finder", key: "ShowPathbar", restart: "Finder"),
        .boolPref("statusbar", "info.circle", domain: "com.apple.finder", key: "ShowStatusBar", restart: "Finder"),
        Tweak(id: "dsstore", icon: "externaldrive.connected.to.line.below",
              read: { Prefs.bool("com.apple.desktopservices", "DSDontWriteNetworkStores") },
              write: { on in
                  let v = on ? "true" : "false"
                  return "defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool \(v); defaults write com.apple.desktopservices DSDontWriteUSBStores -bool \(v)"
              }),
    ]

    static let dock: [Tweak] = [
        .boolPref("dockAutohide", "dock.rectangle", domain: "com.apple.dock", key: "autohide", restart: "Dock"),
        Tweak(id: "dockFast", icon: "hare",
              read: { Prefs.double("com.apple.dock", "autohide-delay") == 0 },
              write: { on in
                  on ? "defaults write com.apple.dock autohide-delay -float 0; defaults write com.apple.dock autohide-time-modifier -float 0.3; killall Dock; true"
                     : "defaults delete com.apple.dock autohide-delay 2>/dev/null; defaults delete com.apple.dock autohide-time-modifier 2>/dev/null; killall Dock; true"
              }),
    ]

    static let shots: [Tweak] = [
        .boolPref("shotShadow", "macwindow", domain: "com.apple.screencapture", key: "disable-shadow", restart: "SystemUIServer"),
    ]
}

struct TweaksView: View {
    @EnvironmentObject var s: AppState
    @State private var values: [String: Bool] = [:]
    @State private var format: String = Prefs.string("com.apple.screencapture", "type") ?? "png"
    @State private var folder: String = Prefs.string("com.apple.screencapture", "location")
        ?? (NSHomeDirectory() + "/Desktop")

    let formats = ["png", "jpg", "heic", "pdf"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(title: s.t("nav.tweaks"), subtitle: s.t("w.subtitle"))
                section(s.t("w.finder"), "folder", Tweak.finder)
                section(s.t("w.dock"), "dock.rectangle", Tweak.dock)

                Card {
                    Label(s.t("w.shots"), systemImage: "camera.viewfinder").font(.headline)
                    ForEach(Tweak.shots) { t in
                        Divider()
                        row(t)
                    }
                    Divider()
                    HStack {
                        Image(systemName: "photo").foregroundStyle(Color.accentTeal).frame(width: 22)
                        Text(s.t("w.shotFormat"))
                        Spacer()
                        Picker("", selection: $format) {
                            ForEach(formats, id: \.self) { Text($0.uppercased()).tag($0) }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 260)
                        .onChange(of: format) { newValue in
                            apply("defaults write com.apple.screencapture type -string \(newValue); killall SystemUIServer; true")
                        }
                    }
                    Divider()
                    HStack {
                        Image(systemName: "folder.badge.gearshape").foregroundStyle(Color.accentTeal).frame(width: 22)
                        Text(s.t("w.shotFolder"))
                        Spacer()
                        Text((folder as NSString).abbreviatingWithTildeInPath)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button(s.t("b.choose")) { chooseShotFolder() }
                    }
                }
            }
            .padding(28)
        }
        .onAppear(perform: load)
    }

    func load() {
        for t in Tweak.finder + Tweak.dock + Tweak.shots {
            values[t.id] = t.read()
        }
    }

    func section(_ title: String, _ icon: String, _ tweaks: [Tweak]) -> some View {
        Card {
            Label(title, systemImage: icon).font(.headline)
            ForEach(tweaks) { t in
                Divider()
                row(t)
            }
        }
    }

    func row(_ t: Tweak) -> some View {
        HStack(spacing: 12) {
            Image(systemName: t.icon).foregroundStyle(Color.accentTeal).frame(width: 22)
            Text(s.t("w.\(t.id)"))
            Spacer()
            Toggle("", isOn: Binding(
                get: { values[t.id] ?? false },
                set: { on in
                    values[t.id] = on
                    apply(t.write(on))
                }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .tint(.accentTeal)
        }
    }

    func apply(_ command: String) {
        Task {
            let r = await Shell.run(command)
            if r.ok {
                s.add("\(s.t("w.applied")): \(command)", .ok)
            } else {
                s.add(result: r)
            }
        }
    }

    func chooseShotFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = URL(fileURLWithPath: folder)
        if panel.runModal() == .OK, let url = panel.url {
            folder = url.path
            apply("defaults write com.apple.screencapture location -string \(Shell.q(url.path)); killall SystemUIServer; true")
        }
    }
}
