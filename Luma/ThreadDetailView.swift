import LumaCore
import SwiftUI

struct ThreadDetailView: View {
    let sessionID: UUID
    let thread: LumaCore.ProcessThread
    let engine: Engine
    @Binding var selection: SidebarItemID?

    @State private var snapshot: LumaCore.ThreadSnapshot?
    @State private var loadError: String?
    @State private var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            Divider()
            content
        }
        .padding(.leading, 12)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .task(id: thread.id) {
            await reload()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(thread.name ?? "tid \(thread.id)")
                .font(.headline)
            if let snap = snapshot {
                Text(snap.state)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                Task { await reload() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .disabled(isLoading)

            let actions = engine.threadActions(sessionID: sessionID, thread: thread)
            if !actions.isEmpty {
                Menu {
                    ForEach(actions) { action in
                        Button(role: action.role == .destructive ? .destructive : nil) {
                            Task { @MainActor in
                                if let target = await action.perform() {
                                    selection = SidebarItemID(navigationTarget: target)
                                }
                            }
                        } label: {
                            if let icon = action.systemImage {
                                Label(action.title, systemImage: icon)
                            } else {
                                Text(action.title)
                            }
                        }
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                }
                .menuStyle(.borderlessButton)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let loadError {
            Text(loadError).foregroundStyle(.red)
        } else if let snap = snapshot {
            if let entry = thread.entrypoint {
                Text("Entry: \(String(format: "0x%llx", entry.routine))")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.fixed(64), alignment: .trailing),
                        GridItem(.flexible(), alignment: .leading),
                    ],
                    alignment: .leading,
                    spacing: 4
                ) {
                    ForEach(snap.registers) { reg in
                        Text(reg.name)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(.secondary)
                        registerChip(reg)
                    }
                }
                .padding(.top, 4)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func registerChip(_ reg: LumaCore.ThreadSnapshot.Register) -> some View {
        if let address = reg.pointerValue {
            Text(reg.rawValue)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 4))
                .contextMenu {
                    Button {
                        openInsight(at: address, kind: .memory)
                    } label: {
                        Label("Open Memory", systemImage: "doc.text.magnifyingglass")
                    }
                    Button {
                        openInsight(at: address, kind: .disassembly)
                    } label: {
                        Label("Open Disassembly", systemImage: "hammer")
                    }
                    let actions = engine.addressActions(
                        sessionID: sessionID,
                        address: address,
                        context: AddressContext(kind: registerKind(reg))
                    )
                    if !actions.isEmpty {
                        Divider()
                        ForEach(actions) { action in
                            Button(role: action.role == .destructive ? .destructive : nil) {
                                Task { @MainActor in
                                    if let target = await action.perform() {
                                        selection = SidebarItemID(navigationTarget: target)
                                    }
                                }
                            } label: {
                                if let icon = action.systemImage {
                                    Label(action.title, systemImage: icon)
                                } else {
                                    Text(action.title)
                                }
                            }
                        }
                    }
                }
        } else {
            Text(reg.rawValue)
                .font(.system(.body, design: .monospaced))
        }
    }

    private func registerKind(_ reg: LumaCore.ThreadSnapshot.Register) -> AddressContext.Kind {
        let n = reg.name
        if n == "pc" || n == "rip" || n == "eip" {
            return .code
        }
        return .unspecified
    }

    private func openInsight(at address: UInt64, kind: LumaCore.AddressInsight.Kind) {
        Task { @MainActor in
            do {
                let insight = try engine.getOrCreateInsight(
                    sessionID: sessionID,
                    pointer: address,
                    kind: kind
                )
                selection = .insight(sessionID, insight.id)
            } catch {
                loadError = error.localizedDescription
            }
        }
    }

    private func reload() async {
        guard let node = engine.node(forSessionID: sessionID) else {
            loadError = "Process is detached."
            return
        }
        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            snapshot = try await node.fetchThreadSnapshot(id: thread.id)
            if snapshot == nil {
                loadError = "Thread no longer exists."
            }
        } catch {
            loadError = error.localizedDescription
        }
    }
}
