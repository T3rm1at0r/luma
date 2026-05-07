import Adw
import CGtk
import Foundation
import Gdk
import Gtk
import LumaCore

@MainActor
final class ModuleSymbolsPane {
    let widget: Box

    private weak var engine: Engine?
    private let sessionID: UUID
    private let module: LumaCore.ProcessModule

    private let header: Label
    private let toggleBar: Box
    private let exportsButton: ToggleButton
    private let importsButton: ToggleButton
    private let symbolsButton: ToggleButton
    private let listContainer: Box

    private var bundle: LumaCore.ModuleSymbolBundle?
    private var loadTask: Task<Void, Never>?
    private var tab: Tab = .exports

    enum Tab {
        case exports
        case imports
        case symbols
    }

    init(engine: Engine, sessionID: UUID, module: LumaCore.ProcessModule) {
        self.engine = engine
        self.sessionID = sessionID
        self.module = module

        widget = Box(orientation: .vertical, spacing: 8)
        widget.hexpand = true

        header = Label(str: "\(module.name) — loading…")
        header.halign = .start
        header.add(cssClass: "heading")

        exportsButton = ToggleButton()
        exportsButton.label = "Exports"
        exportsButton.active = true

        importsButton = ToggleButton()
        importsButton.label = "Imports"
        importsButton.set(group: exportsButton)

        symbolsButton = ToggleButton()
        symbolsButton.label = "Symbols"
        symbolsButton.set(group: exportsButton)

        toggleBar = Box(orientation: .horizontal, spacing: 0)
        toggleBar.add(cssClass: "linked")
        toggleBar.append(child: exportsButton)
        toggleBar.append(child: importsButton)
        toggleBar.append(child: symbolsButton)

        listContainer = Box(orientation: .vertical, spacing: 0)
        listContainer.hexpand = true
        listContainer.vexpand = true

        widget.append(child: header)
        widget.append(child: toggleBar)
        widget.append(child: listContainer)

        exportsButton.onToggled { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.exportsButton.active else { return }
                self.tab = .exports
                self.renderCurrent()
            }
        }
        importsButton.onToggled { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.importsButton.active else { return }
                self.tab = .imports
                self.renderCurrent()
            }
        }
        symbolsButton.onToggled { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.symbolsButton.active else { return }
                self.tab = .symbols
                self.renderCurrent()
            }
        }

        load()
    }

    deinit {
        loadTask?.cancel()
    }

    private func load() {
        loadTask?.cancel()
        guard let engine, let node = engine.node(forSessionID: sessionID) else {
            header.setText(str: "\(module.name) — process detached")
            return
        }

        let moduleName = module.name
        loadTask = Task { @MainActor [weak self] in
            do {
                let result = try await node.enumerateModuleSymbols(name: moduleName)
                guard let self else { return }
                self.bundle = result
                self.updateTabLabels()
                self.renderCurrent()
            } catch {
                guard let self else { return }
                self.header.setText(str: "\(moduleName) — \(error.localizedDescription)")
            }
        }
    }

    private func updateTabLabels() {
        guard let bundle else { return }
        header.setText(str: module.name)
        exportsButton.label = "Exports (\(bundle.exports.count))"
        importsButton.label = "Imports (\(bundle.imports.count))"
        symbolsButton.label = "Symbols (\(bundle.symbols.count))"
    }

    private func renderCurrent() {
        clear(listContainer)
        guard let bundle else { return }

        let scroll = ScrolledWindow()
        scroll.hexpand = true
        scroll.vexpand = true
        scroll.setSizeRequest(width: -1, height: 280)

        let list = ListBox()
        list.selectionMode = .none
        list.add(cssClass: "boxed-list")
        scroll.set(child: list)

        switch tab {
        case .exports:
            for export in bundle.exports {
                list.append(child: makeRow(
                    title: export.name,
                    typeLabel: export.kind.rawValue,
                    address: export.address,
                    context: addressContext(for: export.kind)
                ))
            }
        case .imports:
            for imp in bundle.imports {
                let typeLabel = [imp.kind?.rawValue, imp.module].compactMap { $0 }.joined(separator: " · ")
                let context = imp.kind.map(addressContext(for:)) ?? AddressContext()
                list.append(child: makeRow(
                    title: imp.name,
                    typeLabel: typeLabel.isEmpty ? "import" : typeLabel,
                    address: imp.address,
                    context: context
                ))
            }
        case .symbols:
            for sym in bundle.symbols {
                let typeLabel = [sym.type, sym.sectionID].compactMap { $0 }.joined(separator: " · ")
                list.append(child: makeRow(
                    title: sym.name,
                    typeLabel: typeLabel,
                    address: sym.address,
                    context: addressContext(for: sym)
                ))
            }
        }

        listContainer.append(child: scroll)
    }

    private func makeRow(title: String, typeLabel: String, address: UInt64?, context: AddressContext) -> ListBoxRow {
        let row = ListBoxRow()
        row.selectable = false

        let body = Box(orientation: .horizontal, spacing: 12)
        body.marginStart = 12
        body.marginEnd = 12
        body.marginTop = 6
        body.marginBottom = 6

        let nameLabel = Label(str: title)
        nameLabel.halign = .start
        nameLabel.hexpand = true
        nameLabel.xalign = 0
        nameLabel.ellipsize = .end

        let typeChip = Label(str: typeLabel)
        typeChip.halign = .end
        typeChip.add(cssClass: "dim-label")
        typeChip.add(cssClass: "caption")

        let addrLabel = Label(str: address.map { String(format: "0x%llx", $0) } ?? "—")
        addrLabel.halign = .end
        addrLabel.add(cssClass: "monospace")

        body.append(child: nameLabel)
        body.append(child: typeChip)
        body.append(child: addrLabel)
        row.set(child: body)

        guard let address, let engine else { return row }

        let click = GestureClick()
        click.set(button: 1)
        click.onPressed { [weak self] _, nPress, _, _ in
            MainActor.assumeIsolated {
                guard Int(nPress) == 2, let self else { return }
                AddressActionMenu.openInsight(
                    engine: engine,
                    sessionID: self.sessionID,
                    address: address,
                    kind: context.kind == .data ? .memory : .disassembly,
                    failureLabel: "Can\u{2019}t open"
                )
            }
        }
        row.install(controller: click)

        AddressActionMenu.attach(to: row, engine: engine, sessionID: sessionID, address: address, context: context)

        return row
    }

    private func clear(_ box: Box) {
        var child = box.firstChild
        while let current = child {
            child = current.nextSibling
            box.remove(child: current)
        }
    }
}

private func addressContext(for kind: LumaCore.ModuleSymbolBundle.SymbolKind) -> AddressContext {
    switch kind {
    case .function: return AddressContext(kind: .function, typeHint: "function")
    case .variable: return AddressContext(kind: .data, typeHint: "variable")
    }
}

private func addressContext(for symbol: LumaCore.ModuleSymbolBundle.Symbol) -> AddressContext {
    if symbol.isCode { return AddressContext(kind: .function, typeHint: symbol.type) }
    if symbol.isData { return AddressContext(kind: .data, typeHint: symbol.type) }
    return AddressContext(kind: .unspecified, typeHint: symbol.type)
}
