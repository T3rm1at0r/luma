import Adw
import Foundation
import Gtk
import LumaCore

@MainActor
final class CustomInstrumentFeaturesDialog {
    private let engine: Engine
    private var def: CustomInstrumentDef
    private var draftFeatures: [CustomInstrumentDef.Feature]
    private let dialog: Adw.Dialog
    private let listBox: Box
    private let idEntry: Entry
    private let nameEntry: Entry

    init(engine: Engine, def: CustomInstrumentDef) {
        self.engine = engine
        self.def = def
        self.draftFeatures = def.features

        dialog = Adw.Dialog()
        dialog.set(title: "Features")
        dialog.set(contentWidth: 420)

        listBox = Box(orientation: .vertical, spacing: 4)

        idEntry = Entry()
        idEntry.placeholderText = "id"

        nameEntry = Entry()
        nameEntry.placeholderText = "Name"
        nameEntry.hexpand = true

        layout()
        rebuildList()
    }

    func present(parent: Gtk.Window) {
        Self.retain(self, dialog: dialog)
        MonacoEditor.suspendOverlays()
        dialog.onClosed { _ in
            MainActor.assumeIsolated {
                MonacoEditor.resumeOverlays()
            }
        }
        dialog.present(parent: parent)
    }

    private func layout() {
        let column = Box(orientation: .vertical, spacing: 12)
        column.marginStart = 16
        column.marginEnd = 16
        column.marginTop = 16
        column.marginBottom = 16

        let intro = Label(str: "Per-session knobs the user can configure. Each has a typed schema (boolean, number, string, regex, combo, object, array, …). Agent code reads `config.features.<id>` directly; optional features may be undefined when the user has disabled them.")
        intro.add(cssClass: "dim-label")
        intro.wrap = true
        intro.xalign = 0
        column.append(child: intro)

        column.append(child: listBox)
        column.append(child: addRow())
        column.append(child: actionsRow())

        dialog.set(child: column)
    }

    private func addRow() -> Box {
        let row = Box(orientation: .horizontal, spacing: 8)
        row.append(child: idEntry)
        row.append(child: nameEntry)
        let addButton = Button(label: "Add")
        addButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.appendFeature() }
        }
        row.append(child: addButton)
        return row
    }

    private func appendFeature() {
        let id = (idEntry.text ?? "").trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty, !draftFeatures.contains(where: { $0.id == id }) else { return }
        let typedName = (nameEntry.text ?? "").trimmingCharacters(in: .whitespaces)
        let displayName = typedName.isEmpty ? id : typedName
        draftFeatures.append(.init(id: id, name: displayName, schema: .boolean, optional: false))
        idEntry.text = ""
        nameEntry.text = ""
        rebuildList()
    }

    private func actionsRow() -> Box {
        let row = Box(orientation: .horizontal, spacing: 8)
        let spacer = Label(str: "")
        spacer.hexpand = true
        row.append(child: spacer)

        let cancelButton = Button(label: "Cancel")
        cancelButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { _ = self?.dialog.close() }
        }
        row.append(child: cancelButton)

        let saveButton = Button(label: "Save")
        saveButton.add(cssClass: "suggested-action")
        saveButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.commit() }
        }
        row.append(child: saveButton)
        return row
    }

    private func commit() {
        var updated = def
        updated.features = draftFeatures
        let engine = self.engine
        let dialog = self.dialog
        Task { @MainActor in
            await engine.updateCustomInstrument(updated)
            _ = dialog.close()
        }
    }

    private func rebuildList() {
        var child = listBox.firstChild
        while let current = child {
            child = current.nextSibling
            listBox.remove(child: current)
        }
        if draftFeatures.isEmpty {
            let empty = Label(str: "No features defined.")
            empty.add(cssClass: "dim-label")
            empty.halign = .start
            listBox.append(child: empty)
            return
        }
        for (index, feature) in draftFeatures.enumerated() {
            listBox.append(child: featureRow(feature: feature, index: index))
        }
    }

    private func featureRow(feature: CustomInstrumentDef.Feature, index: Int) -> Box {
        let column = Box(orientation: .vertical, spacing: 6)
        column.add(cssClass: "card")
        column.marginStart = 4
        column.marginEnd = 4
        column.marginTop = 4
        column.marginBottom = 4

        let header = Box(orientation: .horizontal, spacing: 8)
        let idLabel = Label(str: feature.id)
        idLabel.halign = .start
        header.append(child: idLabel)

        let dash = Label(str: "—")
        dash.add(cssClass: "dim-label")
        header.append(child: dash)

        let nameLabel = Label(str: feature.name)
        nameLabel.halign = .start
        nameLabel.hexpand = true
        header.append(child: nameLabel)

        let kindLabel = Label(str: SchemaKind(from: feature.schema).label)
        kindLabel.add(cssClass: "caption")
        kindLabel.add(cssClass: "dim-label")
        header.append(child: kindLabel)

        let removeButton = Button(label: "Remove")
        removeButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, index < self.draftFeatures.count else { return }
                self.draftFeatures.remove(at: index)
                self.rebuildList()
            }
        }
        header.append(child: removeButton)
        column.append(child: header)

        let optionalRow = Box(orientation: .horizontal, spacing: 8)
        let optionalLabel = Label(str: "Optional (user can disable)")
        optionalLabel.halign = .start
        optionalLabel.setSizeRequest(width: 220, height: -1)
        optionalRow.append(child: optionalLabel)
        let optionalToggle = Switch()
        optionalToggle.active = feature.optional
        optionalToggle.valign = .center
        optionalRow.append(child: optionalToggle)
        column.append(child: optionalRow)
        optionalRow.visible = !isBoolean(feature.schema)

        let enabledRow = Box(orientation: .horizontal, spacing: 8)
        let enabledLabel = Label(str: "Enabled by default")
        enabledLabel.halign = .start
        enabledLabel.setSizeRequest(width: 220, height: -1)
        enabledRow.append(child: enabledLabel)
        let enabledToggle = Switch()
        enabledToggle.active = feature.enabledByDefault
        enabledToggle.valign = .center
        enabledRow.append(child: enabledToggle)
        column.append(child: enabledRow)
        enabledRow.visible = feature.optional

        optionalToggle.onStateSet { [weak self] _, state in
            MainActor.assumeIsolated {
                guard let self, index < self.draftFeatures.count else { return false }
                self.draftFeatures[index].optional = state
                enabledRow.visible = state
                return false
            }
        }
        enabledToggle.onStateSet { [weak self] _, state in
            MainActor.assumeIsolated {
                guard let self, index < self.draftFeatures.count else { return false }
                self.draftFeatures[index].enabledByDefault = state
                return false
            }
        }

        let editor = CustomInstrumentSchemaEditor(schema: feature.schema) { [weak self] updated in
            MainActor.assumeIsolated {
                guard let self, index < self.draftFeatures.count else { return }
                self.draftFeatures[index].schema = updated
                kindLabel.label = SchemaKind(from: updated).label
                let nowBoolean = self.isBoolean(updated)
                optionalRow.visible = !nowBoolean
                if nowBoolean, self.draftFeatures[index].optional {
                    self.draftFeatures[index].optional = false
                    optionalToggle.active = false
                    enabledRow.visible = false
                }
            }
        }
        column.append(child: editor.widget)

        return column
    }

    private func isBoolean(_ schema: FeatureSchema) -> Bool {
        if case .boolean = schema { return true }
        return false
    }

    private static func retain(_ owner: CustomInstrumentFeaturesDialog, dialog: Adw.Dialog) {
        let key = ObjectIdentifier(dialog)
        retained[key] = owner
        dialog.onClosed { _ in
            MainActor.assumeIsolated {
                _ = retained.removeValue(forKey: key)
            }
        }
    }

    private static var retained: [ObjectIdentifier: CustomInstrumentFeaturesDialog] = [:]
}
