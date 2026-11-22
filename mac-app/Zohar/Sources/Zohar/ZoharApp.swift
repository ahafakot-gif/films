import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var console: Console?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.environment["ZOHAR_SELFTEST"] == "1" {
            exit(SelfTest.run())
        }
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func applicationWillTerminate(_ notification: Notification) {
        AppDelegate.console?.autosave()
    }
}

@main
struct ZoharApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var console = Console()

    var body: some Scene {
        Window("Zohar", id: "main") {
            MainView()
                .environmentObject(console)
                .environment(\.layoutDirection, console.lang == .he ? .rightToLeft : .leftToRight)
                .preferredColorScheme(console.theme.scheme)
                .frame(minWidth: 1200, minHeight: 760)
                .onAppear { AppDelegate.console = console }
        }
        .defaultSize(width: 1500, height: 920)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(console.t("menu.new")) { console.newShow() }
                Button(console.t("menu.open")) { console.open() }
                    .keyboardShortcut("o")
                Button(console.t("menu.saveAs")) { console.saveAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
            }
        }
    }
}

// MARK: - Main layout

struct MainView: View {
    @EnvironmentObject var c: Console

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
            Divider()
            HStack(spacing: 0) {
                PlaybackGrid()
                    .frame(minWidth: 640, maxWidth: .infinity)
                Divider()
                SidePanel()
                    .frame(minWidth: 500, idealWidth: 580, maxWidth: 680)
            }
            Divider()
            FaderBank()
                .frame(height: 220)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(item: $c.sheet) { kind in
            switch kind {
            case .patch: PatchView().environmentObject(c)
            case .settings: SettingsView().environmentObject(c)
            case .cuelist(let id): CuelistEditor(id: id).environmentObject(c)
            }
        }
    }
}

// MARK: - Top bar

struct TopBar: View {
    @EnvironmentObject var c: Console

    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 28, height: 28)
            Text("ZOHAR").font(.system(size: 15, weight: .heavy)).tracking(2)

            Divider().frame(height: 26)

            HStack(spacing: 6) {
                Text("GM").font(.caption.bold())
                Slider(value: $c.grandMaster, in: 0...1).frame(width: 110)
                Text("\(Int(c.grandMaster * 100))%").font(.caption.monospacedDigit()).frame(width: 36, alignment: .leading)
            }

            BarButton(title: "Blackout", icon: "moon.fill", on: c.blackout, color: .red) { c.blackout.toggle() }
                .keyboardShortcut("b", modifiers: [.command])
            BarButton(title: "Highlight", icon: "lightbulb.fill", on: c.highlight, color: .yellow) { c.highlight.toggle() }
            BarButton(title: "Record", icon: "record.circle", on: c.recordMode, color: .red) { c.recordMode.toggle() }
                .keyboardShortcut("r", modifiers: [.command])
            BarButton(title: "Clear", icon: "xmark.circle", on: !c.programmerEmpty, color: .orange) { c.clearProgrammer() }
                .keyboardShortcut(.escape, modifiers: [])
            BarButton(title: "Release", icon: "stop.circle", on: false, color: .gray) { c.releaseAll() }

            Spacer(minLength: 8)

            if let m = c.message {
                Text(m)
                    .font(.callout.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.25)))
                    .transition(.opacity)
            } else if c.recordMode {
                Text(c.t("rec.hint"))
                    .font(.callout.bold())
                    .foregroundStyle(.red)
            }

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                Button { c.page = (c.page - 1 + Console.pages) % Console.pages } label: { Image(systemName: "chevron.left") }
                Text("\(c.t("ui.page")) \(c.page + 1)").font(.callout.bold()).frame(minWidth: 70)
                Button { c.page = (c.page + 1) % Console.pages } label: { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.borderless)

            Divider().frame(height: 26)

            HStack(spacing: 5) {
                Circle().fill(c.outputOK ? Color.green : Color.red).frame(width: 9, height: 9)
                Text("DMX").font(.caption.bold())
            }
            .help(c.outputOK ? c.t("out.ok") : c.t("out.none"))

            Button { c.sheet = .patch } label: { Label("Patch", systemImage: "cable.connector") }
            Button { c.sheet = .settings } label: { Image(systemName: "gearshape") }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .animation(.easeInOut(duration: 0.2), value: c.message)
    }
}

struct BarButton: View {
    let title: String
    let icon: String
    let on: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(RoundedRectangle(cornerRadius: 7).fill(on ? color.opacity(0.85) : Color.primary.opacity(0.07)))
                .foregroundStyle(on ? Color.white : Color.primary)
        }
        .buttonStyle(.plain)
    }
}
