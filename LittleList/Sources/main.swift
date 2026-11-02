import AppKit
import SwiftUI
import ServiceManagement

struct Item: Codable, Identifiable {
    var id: String
    var title: String
    var source: String
    var detail: String
    var url: String?
    var due: String?
    var list: String?
    var category: String { list ?? (source == "Personal" || source == "Personal Gmail" || source == "WhatsApp" ? "Personal" : "School") }
}
struct Source: Codable, Identifiable {
    var id: String
    var name: String
    var status: String
    var detail: String
    var checkedAt: String?
    var url: String
}
struct Feed: Codable { var updatedAt: String; var items: [Item]; var sources: [Source] }
struct LocalState: Codable { var items: [Item] = []; var completed: Set<String> = [] }

final class Store: ObservableObject {
    @Published var feed = Feed(updatedAt: "", items: [], sources: [])
    @Published var local = LocalState()
    @Published var error: String?
    let directory: URL
    var timer: Timer?
    var onChange: ((Int) -> Void)?
    init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("LittleList")
        if let data = try? Data(contentsOf: directory.appendingPathComponent("local.json")),
           let decoded = try? JSONDecoder().decode(LocalState.self, from: data) { local = decoded }
        reload()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.reload() }
    }
    var items: [Item] { (local.items + feed.items).sorted { ($0.due ?? "9999") < ($1.due ?? "9999") } }
    var pending: [Item] { items.filter { !local.completed.contains($0.id) } }
    func reload() {
        do {
            let data = try Data(contentsOf: directory.appendingPathComponent("feed.json"))
            let result = try JSONDecoder().decode(Feed.self, from: data)
            guard Set(result.items.map(\.id)).count == result.items.count else { throw NSError(domain: "Duplicate tasks", code: 1) }
            feed = result; error = nil; onChange?(pending.count)
        } catch { self.error = "Couldn’t read the latest update. Keeping the last good list." }
    }
    func save() {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(local).write(to: directory.appendingPathComponent("local.json"), options: .atomic)
            error = nil; onChange?(pending.count)
        } catch { self.error = "Couldn’t save your changes: \(error.localizedDescription)" }
    }
    func toggle(_ item: Item) {
        if local.completed.contains(item.id) { local.completed.remove(item.id) } else { local.completed.insert(item.id) }
        save()
    }
    func add(_ text: String, list: String) {
        let title = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        local.items.append(Item(id: "local:" + UUID().uuidString, title: title, source: "Personal", detail: "Added by you", list: list))
        save()
    }
    func open(_ text: String?) {
        guard let text, let url = URL(string: text), ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return }
        NSWorkspace.shared.open(url)
    }
    func date(_ text: String?) -> Date? {
        guard let text else { return nil }
        let f = ISO8601DateFormatter()
        if let date = f.date(from: text) { return date }
        f.formatOptions.insert(.withFractionalSeconds)
        return f.date(from: text)
    }
    func freshness(_ text: String?) -> String {
        guard let date = date(text) else { return "Not synced yet" }
        let minutes = max(0, Int(Date().timeIntervalSince(date) / 60))
        return minutes < 1 ? "Updated just now" : "Updated \(minutes)m ago"
    }
}

struct Content: View {
    @ObservedObject var store: Store
    @State private var draft = ""
    @State private var tab = "To do"
    @State private var selectedList = "School"
    @State private var loginError: String?
    @State private var loginEnabled = SMAppService.mainApp.status == .enabled
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Little List").font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("A little less to keep in your head.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(store.pending.count)").font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundStyle(.teal).padding(10).background(.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            Picker("List", selection: $selectedList) {
                Text("School").tag("School")
                Text("Personal").tag("Personal")
            }.pickerStyle(.segmented)
            Picker("View", selection: $tab) {
                Text("To do").tag("To do")
                Text("Done").tag("Done")
                Text("Sources").tag("Sources")
            }.pickerStyle(.segmented)
            if tab == "Sources" { sources } else { tasks }
            if let error = store.error ?? loginError { Text(error).font(.caption).foregroundStyle(.orange) }
            Divider()
            HStack {
                Circle().fill(store.date(store.feed.updatedAt).map { Date().timeIntervalSince($0) < 1800 } == true ? Color.teal : Color.orange).frame(width: 6, height: 6)
                Text(store.freshness(store.feed.updatedAt)).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Menu {
                    Button("Reload saved feed") { store.reload() }
                    Toggle("Open at login", isOn: Binding(get: { loginEnabled }, set: { enabled in
                        do {
                            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                            loginEnabled = SMAppService.mainApp.status == .enabled
                            if SMAppService.mainApp.status == .requiresApproval { loginError = "Allow Little List in System Settings → Login Items." }
                        } catch { loginError = error.localizedDescription }
                    }))
                    Divider()
                    Button("Quit Little List") { NSApplication.shared.terminate(nil) }
                } label: { Image(systemName: "gearshape") }.menuStyle(.borderlessButton).frame(width: 24)
            }
        }.padding(20).frame(width: 390, height: 565)
    }
    var tasks: some View {
        VStack(spacing: 12) {
            if tab == "To do" {
                HStack {
                    TextField("Add a little to-do…", text: $draft).textFieldStyle(.plain).onSubmit(add)
                    Button(action: add) { Image(systemName: "plus.circle.fill").foregroundStyle(.teal) }.buttonStyle(.plain).disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                }.padding(11).background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10))
            }
            ScrollView {
                LazyVStack(spacing: 8) {
                    let visible = store.items.filter { $0.category == selectedList && store.local.completed.contains($0.id) == (tab == "Done") }
                    if visible.isEmpty {
                        VStack(spacing: 10) {
                            Image(systemName: tab == "Done" ? "checkmark.circle" : "leaf").font(.system(size: 30)).foregroundStyle(.teal)
                            Text(tab == "Done" ? "Finished tasks live here" : "Nothing on your list yet").font(.headline)
                            Text(tab == "Done" ? "You can restore a task with one click." : "Add a task or check your connected sources.").font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity).padding(.vertical, 50)
                    }
                    ForEach(visible) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Button { store.toggle(item) } label: {
                                Image(systemName: tab == "Done" ? "checkmark.circle.fill" : "circle").font(.system(size: 19)).foregroundStyle(.teal)
                            }.buttonStyle(.plain).accessibilityLabel(tab == "Done" ? "Restore \(item.title)" : "Complete \(item.title)")
                            VStack(alignment: .leading, spacing: 5) {
                                Text(item.title).font(.system(size: 13, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                                Text(item.source).font(.caption2).foregroundStyle(.teal)
                                if !item.detail.isEmpty { Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(3) }
                                if let date = store.date(item.due) { Text(date, style: .date).font(.caption2).foregroundStyle(date < Date() ? .orange : .secondary) }
                            }
                            Spacer(minLength: 0)
                            if item.url != nil { Button { store.open(item.url) } label: { Image(systemName: "arrow.up.right") }.buttonStyle(.plain).help("Open original") }
                        }.padding(12).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            Text("Checking a task off only changes this list.").font(.caption2).foregroundStyle(.secondary)
        }
    }
    var sources: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Account checks run through this Codex chat. Keep Codex open for scheduled updates.").font(.caption).foregroundStyle(.secondary)
                ForEach(store.feed.sources) { source in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(source.name).font(.system(size: 13, weight: .semibold))
                            Spacer()
                            Text(source.status).font(.caption2).foregroundStyle(source.status == "Connected" ? .teal : .orange)
                        }
                        Text(source.detail).font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text(store.freshness(source.checkedAt)).font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Button("Open") { store.open(source.url) }.font(.caption)
                        }
                    }.padding(12).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
    func add() { store.add(draft, list: selectedList); draft = "" }
}

final class ListPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class Delegate: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    let panel = ListPanel(contentRect: NSRect(x: 0, y: 0, width: 390, height: 565),
                          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    let store = Store()
    var outsideClick: Any?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Little List")
        status.button?.target = self
        status.button?.action = #selector(toggle)
        status.button?.toolTip = "Little List — your tasks"
        panel.level = .popUpMenu
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        let hosting = NSHostingView(rootView: Content(store: store).background(Color(nsColor: .windowBackgroundColor)))
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 14
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting
        outsideClick = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.panel.isVisible else { return }
            if let button = self.status.button, let window = button.window {
                let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
                if anchor.contains(NSEvent.mouseLocation) { return }
            }
            self.panel.orderOut(nil)
        }
        store.onChange = { [weak self] count in self?.status.button?.title = " \(count)" }
        store.reload()
        DispatchQueue.main.async { self.showPanel() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel(); return true
    }
    func showPanel() {
        guard let button = status.button, let window = button.window,
              let screen = window.screen ?? NSScreen.main else { return }
        store.reload()
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        let available = screen.visibleFrame
        let width: CGFloat = 390
        let height: CGFloat = min(565, available.height)
        let x = min(max(anchor.midX - width / 2, available.minX), available.maxX - width)
        // AppKit screen coordinates rise upward. Pin the panel's top to the
        // bottom of the menu bar, then extend the entire panel downward.
        let top = min(anchor.minY, available.maxY)
        let y = max(available.minY, top - height)
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc func toggle() {
        if panel.isVisible { panel.orderOut(nil) } else { showPanel() }
    }
}

let app = NSApplication.shared
let delegate = Delegate()
app.delegate = delegate
app.run()
