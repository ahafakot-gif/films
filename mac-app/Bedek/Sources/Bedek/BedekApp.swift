import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

@main
struct BedekApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var state = AppState()

    var body: some Scene {
        Window("Bedek", id: "main") {
            ContentView()
                .environmentObject(state)
                .environment(\.layoutDirection, state.lang == .he ? .rightToLeft : .leftToRight)
                .environment(\.locale, Locale(identifier: state.lang.localeID))
                .preferredColorScheme(state.theme.scheme)
                .frame(minWidth: 900, minHeight: 600)
        }
        .defaultSize(width: 1040, height: 700)
    }
}

// MARK: - Main window

enum Page: String, CaseIterable, Identifiable {
    case overview, maintenance, bigfiles, tweaks, log
    var id: Self { self }
    var icon: String {
        switch self {
        case .overview: return "gauge.medium"
        case .maintenance: return "wand.and.stars"
        case .bigfiles: return "externaldrive.badge.minus"
        case .tweaks: return "slider.horizontal.3"
        case .log: return "list.bullet.rectangle"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var s: AppState
    @State private var page: Page? = .overview

    var body: some View {
        NavigationSplitView {
            List(selection: $page) {
                ForEach(Page.allCases) { p in
                    Label(s.t("nav.\(p.rawValue)"), systemImage: p.icon)
                        .padding(.vertical, 3)
                        .tag(p)
                }
            }
            .safeAreaInset(edge: .top) { SidebarHeader() }
            .safeAreaInset(edge: .bottom) { SidebarFooter() }
            .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 280)
        } detail: {
            switch page ?? .overview {
            case .overview: OverviewView()
            case .maintenance: MaintenanceView()
            case .bigfiles: BigFilesView()
            case .tweaks: TweaksView()
            case .log: LogView()
            }
        }
    }
}

struct SidebarHeader: View {
    @EnvironmentObject var s: AppState
    var body: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 1) {
                Text("Bedek").font(.headline)
                Text(s.t("app.tagline")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

struct SidebarFooter: View {
    @EnvironmentObject var s: AppState
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            Picker(s.t("ui.language"), selection: $s.lang) {
                ForEach(Lang.allCases) { Text($0.title).tag($0) }
            }
            Picker(s.t("ui.theme"), selection: $s.theme) {
                ForEach(Theme.allCases) { Text(s.t("theme.\($0.rawValue)")).tag($0) }
            }
            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .pickerStyle(.menu)
        .controlSize(.small)
        .padding(12)
    }
}

// MARK: - Shared pieces

struct PageHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 26, weight: .bold))
            Text(subtitle).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            )
    }
}

extension Color {
    static let accentTeal = Color(red: 0.12, green: 0.62, blue: 0.70)
}
