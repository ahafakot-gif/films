import AppKit
import SwiftUI

struct LogView: View {
    @EnvironmentObject var s: AppState

    static let timeFormat: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                PageHeader(title: s.t("nav.log"), subtitle: s.t("l.subtitle"))
                Button(s.t("l.copy")) { copy() }.disabled(s.log.isEmpty)
                Button(s.t("l.clear")) { s.log.removeAll() }.disabled(s.log.isEmpty)
            }
            if s.log.isEmpty {
                Text(s.t("l.empty"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    List(s.log) { line in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(Self.timeFormat.string(from: line.date))
                                .foregroundStyle(.tertiary)
                            Image(systemName: icon(line.kind)).foregroundStyle(color(line.kind))
                            Text(line.text)
                                .textSelection(.enabled)
                                .foregroundStyle(line.kind == .output ? .secondary : .primary)
                        }
                        .font(.system(size: 12, design: .monospaced))
                        .id(line.id)
                    }
                    .onAppear { if let last = s.log.last { proxy.scrollTo(last.id, anchor: .bottom) } }
                    .onChange(of: s.log.count) { _ in
                        if let last = s.log.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }
        }
        .padding(28)
    }

    func icon(_ k: LogLine.Kind) -> String {
        switch k {
        case .info: return "arrow.right.circle"
        case .ok: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .output: return "text.alignleft"
        }
    }

    func color(_ k: LogLine.Kind) -> Color {
        switch k {
        case .info: return .accentTeal
        case .ok: return .green
        case .error: return .orange
        case .output: return .secondary
        }
    }

    func copy() {
        let text = s.log.map { "\(Self.timeFormat.string(from: $0.date))  \($0.text)" }.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
