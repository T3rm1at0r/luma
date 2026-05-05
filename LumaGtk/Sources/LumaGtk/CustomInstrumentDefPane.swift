import Adw
import CGtk
import Foundation
import GLibObject
import Gtk
import LumaCore

@MainActor
final class CustomInstrumentDefPane {
    let widget: Box
    private weak var engine: Engine?
    private(set) var def: CustomInstrumentDef
    private var draftSource: String
    private let sourceEditor: MonacoEditor
    private let saveButton: Button

    init(engine: Engine, def: CustomInstrumentDef, sourceEditor: MonacoEditor) {
        self.engine = engine
        self.def = def
        self.draftSource = def.source
        self.sourceEditor = sourceEditor

        widget = Box(orientation: .vertical, spacing: 8)
        widget.hexpand = true
        widget.vexpand = true
        widget.marginStart = 24
        widget.marginEnd = 24
        widget.marginTop = 12
        widget.marginBottom = 12

        saveButton = Button(label: "Save")
        saveButton.add(cssClass: "suggested-action")
        saveButton.sensitive = false
        saveButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.commit() }
        }

        layout()
    }

    private func layout() {
        widget.append(child: header())
        widget.append(child: sourceEditorContainer())
    }

    private func header() -> Box {
        let row = Box(orientation: .horizontal, spacing: 8)
        let icon = Gtk.Image(iconName: "applications-utilities-symbolic")
        icon.pixelSize = 24
        row.append(child: icon)

        let titles = Box(orientation: .vertical, spacing: 0)
        titles.hexpand = true
        let nameLabel = Label(str: def.name)
        nameLabel.halign = .start
        nameLabel.add(cssClass: "title-3")
        titles.append(child: nameLabel)
        let subtitle = Label(str: "Custom instrument")
        subtitle.halign = .start
        subtitle.add(cssClass: "caption")
        subtitle.add(cssClass: "dim-label")
        titles.append(child: subtitle)
        row.append(child: titles)

        row.append(child: saveButton)
        return row
    }

    private func sourceEditorContainer() -> Box {
        let container = Box(orientation: .vertical, spacing: 0)
        container.hexpand = true
        container.vexpand = true
        let packages = (try? engine?.store.fetchPackagesState().packages) ?? []
        sourceEditor.setProfile(EditorProfile.fridaCustomInstrument(packages: packages, def: def))
        sourceEditor.setText(draftSource)
        sourceEditor.installInto(container)
        sourceEditor.onTextChanged = { [weak self] text in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.draftSource = text
                self.saveButton.sensitive = self.isDirty()
            }
        }
        return container
    }

    private func isDirty() -> Bool {
        draftSource != def.source
    }

    private func commit() {
        guard let engine else { return }
        var updated = def
        updated.source = draftSource
        Task { @MainActor in
            await engine.updateCustomInstrument(updated)
            self.def = updated
            self.saveButton.sensitive = false
        }
    }
}
