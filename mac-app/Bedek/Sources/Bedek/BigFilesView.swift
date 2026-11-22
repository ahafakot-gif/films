import AppKit
import SwiftUI

struct BigFile: Identifiable {
    let url: URL
    let size: Int64
    let date: Date?
    var id: URL { url }
}

enum BigFileScanner {
    static func scanSync(root: URL, minSize: Int64) -> [BigFile] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey, .contentModificationDateKey]
        guard let en = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles],
            errorHandler: { _, _ in true }
        ) else { return [] }
        var result: [BigFile] = []
        let keySet = Set(keys)
        while let item = en.nextObject() {
            guard let url = item as? URL,
                  let v = try? url.resourceValues(forKeys: keySet),
                  v.isRegularFile == true else { continue }
            let size = Int64(v.totalFileAllocatedSize ?? v.fileSize ?? 0)
            if size >= minSize {
                result.append(BigFile(url: url, size: size, date: v.contentModificationDate))
            }
        }
        result.sort { $0.size > $1.size }
        return Array(result.prefix(500))
    }

    static func scan(root: URL, minSize: Int64) async -> [BigFile] {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                cont.resume(returning: scanSync(root: root, minSize: minSize))
            }
        }
    }
}

struct BigFilesView: View {
    @EnvironmentObject var s: AppState
    @State private var root = FileManager.default.homeDirectoryForCurrentUser
    @State private var minGB: Double = 1
    @State private var files: [BigFile] = []
    @State private var selection: Set<URL> = []
    @State private var scanning = false
    @State private var scanned = false
    @State private var confirmTrash = false

    let sizes: [Double] = [0.1, 0.5, 1, 2, 5, 10]

    var total: Int64 { files.reduce(0) { $0 + $1.size } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            PageHeader(title: s.t("nav.bigfiles"), subtitle: s.t("b.subtitle"))

            HStack(spacing: 10) {
                Text(s.t("b.folder"))
                Text(root.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.06)))
                Button(s.t("b.choose")) { chooseFolder() }
                Spacer()
                Picker(s.t("b.minSize"), selection: $minGB) {
                    ForEach(sizes, id: \.self) { gb in
                        Text(Fmt.bytes(Int64(gb * 1_000_000_000))).tag(gb)
                    }
                }
                .frame(width: 190)
                Button {
                    Task { await scan() }
                } label: {
                    Label(scanning ? s.t("b.scanning") : s.t("b.scan"), systemImage: "magnifyingglass")
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentTeal)
                .disabled(scanning)
            }
            .disabled(scanning)

            if scanning {
                HStack { ProgressView().controlSize(.small); Text(s.t("b.scanning")) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !scanned {
                VStack(spacing: 10) {
                    Image(systemName: "externaldrive.badge.questionmark")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text(s.t("b.empty")).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Table(files, selection: $selection) {
                    TableColumn(s.t("b.name")) { f in
                        HStack(spacing: 6) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: f.url.path))
                                .resizable()
                                .frame(width: 16, height: 16)
                            Text(f.url.lastPathComponent).lineLimit(1)
                        }
                    }
                    .width(min: 200, ideal: 300)
                    TableColumn(s.t("b.size")) { f in
                        Text(Fmt.bytes(f.size)).monospacedDigit()
                    }
                    .width(90)
                    TableColumn(s.t("b.date")) { f in
                        Text(Fmt.date(f.date, lang: s.lang))
                    }
                    .width(110)
                    TableColumn(s.t("b.where")) { f in
                        Text(f.url.deletingLastPathComponent().path
                            .replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                .contextMenu(forSelectionType: URL.self) { urls in
                    Button(s.t("b.reveal")) { reveal(urls) }
                    Button(s.t("b.trash"), role: .destructive) {
                        selection = urls
                        confirmTrash = true
                    }
                } primaryAction: { urls in
                    reveal(urls)
                }

                HStack {
                    Text("\(s.t("b.found")): \(files.count) · \(s.t("b.total")) \(Fmt.bytes(total))")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(s.t("b.reveal")) { reveal(selection) }
                        .disabled(selection.isEmpty)
                    Button(role: .destructive) {
                        confirmTrash = true
                    } label: {
                        Label(s.t("b.trash"), systemImage: "trash")
                    }
                    .disabled(selection.isEmpty)
                }
            }
        }
        .padding(28)
        .alert(s.t("b.confirm"), isPresented: $confirmTrash) {
            Button(s.t("b.trash"), role: .destructive) { trash(selection) }
            Button(s.t("c.cancel"), role: .cancel) {}
        } message: {
            Text(s.t("b.confirmHint"))
        }
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = root
        if panel.runModal() == .OK, let url = panel.url {
            root = url
        }
    }

    func scan() async {
        scanning = true
        selection = []
        s.add("\(s.t("b.scanning")) \(root.path)")
        files = await BigFileScanner.scan(root: root, minSize: Int64(minGB * 1_000_000_000))
        s.add("\(s.t("b.found")): \(files.count) · \(Fmt.bytes(total))", .ok)
        scanned = true
        scanning = false
    }

    func reveal(_ urls: Set<URL>) {
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(Array(urls))
    }

    func trash(_ urls: Set<URL>) {
        for url in urls {
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                files.removeAll { $0.url == url }
                s.add("\(s.t("b.trash")): \(url.path)", .ok)
            } catch {
                s.add("\(s.t("c.error")): \(url.lastPathComponent) — \(error.localizedDescription)", .error)
            }
        }
        selection = []
    }
}
