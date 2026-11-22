import SwiftUI

struct MaintTask: Identifiable {
    let id: String
    let icon: String
    let admin: Bool
    let recommended: Bool
    let command: String

    static let all: [MaintTask] = [
        // No password
        MaintTask(id: "userCaches", icon: "archivebox", admin: false, recommended: true,
                  command: "find \"$HOME/Library/Caches\" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null; true"),
        MaintTask(id: "userLogs", icon: "doc.plaintext", admin: false, recommended: true,
                  command: "find \"$HOME/Library/Logs\" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null; true"),
        MaintTask(id: "quicklook", icon: "eye", admin: false, recommended: true,
                  command: "qlmanage -r cache >/dev/null 2>&1; qlmanage -r >/dev/null 2>&1; true"),
        MaintTask(id: "fonts", icon: "textformat", admin: false, recommended: false,
                  command: "atsutil databases -removeUser; atsutil server -shutdown; atsutil server -ping; true"),
        MaintTask(id: "launchServices", icon: "square.stack.3d.up", admin: false, recommended: false,
                  command: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -kill -r -domain local -domain system -domain user >/dev/null 2>&1; true"),
        MaintTask(id: "trash", icon: "trash", admin: false, recommended: false,
                  command: "osascript -e 'tell application \"Finder\" to empty trash' 2>&1; true"),
        MaintTask(id: "restartFinder", icon: "arrow.triangle.2.circlepath", admin: false, recommended: true,
                  command: "killall Dock; killall Finder; true"),
        // Administrator
        MaintTask(id: "dns", icon: "network", admin: true, recommended: true,
                  command: "dscacheutil -flushcache; killall -HUP mDNSResponder; true"),
        MaintTask(id: "purge", icon: "memorychip", admin: true, recommended: false,
                  command: "purge"),
        MaintTask(id: "systemCaches", icon: "archivebox.fill", admin: true, recommended: false,
                  command: "find /Library/Caches -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null; true"),
        MaintTask(id: "diagReports", icon: "exclamationmark.bubble", admin: true, recommended: false,
                  command: "find /Library/Logs/DiagnosticReports -mindepth 1 -delete 2>/dev/null; true"),
        MaintTask(id: "spotlight", icon: "magnifyingglass", admin: true, recommended: false,
                  command: "mdutil -E / >/dev/null 2>&1; true"),
    ]
}

struct MaintenanceView: View {
    @EnvironmentObject var s: AppState
    @State private var selected: Set<String> = Set(MaintTask.all.filter { $0.recommended }.map { $0.id })
    @State private var running = false
    @State private var current: Set<String> = []
    @State private var done: Set<String> = []
    @State private var freed: Int64? = nil

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PageHeader(title: s.t("nav.maintenance"), subtitle: s.t("m.subtitle"))

                    HStack(spacing: 8) {
                        Button(s.t("m.recommended")) {
                            selected = Set(MaintTask.all.filter { $0.recommended }.map { $0.id })
                        }
                        Button(s.t("m.all")) { selected = Set(MaintTask.all.map { $0.id }) }
                        Button(s.t("m.none")) { selected = [] }
                    }
                    .controlSize(.small)
                    .disabled(running)

                    group(title: s.t("m.groupUser"), icon: "person", tasks: MaintTask.all.filter { !$0.admin })
                    group(title: s.t("m.groupAdmin"), icon: "lock", tasks: MaintTask.all.filter { $0.admin })
                }
                .padding(28)
            }

            Divider()
            HStack(spacing: 12) {
                if running {
                    ProgressView().controlSize(.small)
                    Text(s.t("m.running"))
                } else if let freed {
                    Label("\(s.t("m.done")) · \(s.t("m.freed")): \(Fmt.bytes(freed))", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                Spacer()
                Button {
                    Task { await run() }
                } label: {
                    Label(s.t("m.run"), systemImage: "play.fill").padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentTeal)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
                .disabled(running || selected.isEmpty)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
        }
    }

    @ViewBuilder
    func group(title: String, icon: String, tasks: [MaintTask]) -> some View {
        Card {
            Label(title, systemImage: icon).font(.headline)
            ForEach(tasks) { task in
                Divider()
                row(task)
            }
        }
    }

    func row(_ task: MaintTask) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Toggle("", isOn: Binding(
                get: { selected.contains(task.id) },
                set: { on in
                    if on { selected.insert(task.id) } else { selected.remove(task.id) }
                }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .disabled(running)

            Image(systemName: task.icon)
                .foregroundStyle(Color.accentTeal)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(s.t("t.\(task.id)")).font(.system(size: 13, weight: .medium))
                Text(s.t("d.\(task.id)")).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if current.contains(task.id) {
                ProgressView().controlSize(.small)
            } else if done.contains(task.id) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .contentShape(Rectangle())
    }

    func run() async {
        running = true
        done = []
        freed = nil
        let before = DiskSpace.freeAndTotal().free
        let tasks = MaintTask.all.filter { selected.contains($0.id) }

        // Admin tasks first, in one password prompt.
        let adminTasks = tasks.filter { $0.admin }
        if !adminTasks.isEmpty {
            current = Set(adminTasks.map { $0.id })
            s.add(adminTasks.map { s.t("t.\($0.id)") }.joined(separator: ", "))
            let joined = adminTasks.map { "( \($0.command) )" }.joined(separator: "; ")
            let r = await Shell.runAsAdmin(joined)
            if r.ok {
                done.formUnion(current)
                s.add(s.t("m.done"), .ok)
            } else if r.output.contains("-128") {
                s.add(s.t("m.cancelled"), .error)
            } else {
                s.add(result: r)
            }
            current = []
        }

        // Then user tasks in list order (restart Finder is last).
        for task in tasks where !task.admin {
            current = [task.id]
            s.add(s.t("t.\(task.id)"))
            let r = await Shell.run(task.command)
            if !r.output.isEmpty && !r.ok { s.add(result: r) }
            done.insert(task.id)
            current = []
        }

        let after = DiskSpace.freeAndTotal().free
        freed = max(0, after - before)
        s.add("\(s.t("m.done")) · \(s.t("m.freed")): \(Fmt.bytes(freed ?? 0))", .ok)
        running = false
    }
}
