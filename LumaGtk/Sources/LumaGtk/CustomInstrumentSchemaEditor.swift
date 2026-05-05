import Adw
import CGtk
import Foundation
import GLibObject
import Gtk
import LumaCore

@MainActor
final class CustomInstrumentSchemaEditor {
    let widget: Box
    private(set) var schema: FeatureSchema
    private let onChanged: (FeatureSchema) -> Void
    private let typeRow: Box
    private let fieldsBox: Box
    private var childEditors: [AnyObject] = []

    init(schema: FeatureSchema, onChanged: @escaping (FeatureSchema) -> Void) {
        self.schema = schema
        self.onChanged = onChanged

        widget = Box(orientation: .vertical, spacing: 6)
        widget.hexpand = true

        typeRow = Box(orientation: .horizontal, spacing: 8)
        fieldsBox = Box(orientation: .vertical, spacing: 4)

        populateTypeRow()
        widget.append(child: typeRow)
        widget.append(child: fieldsBox)
        rebuildFields()
    }

    private func populateTypeRow() {
        let label = Label(str: "Type")
        label.halign = .start
        label.setSizeRequest(width: 100, height: -1)
        typeRow.append(child: label)

        let dropdown = makeStringDropdown(
            labels: SchemaKind.allCases.map(\.label),
            selectedIndex: SchemaKind(from: schema).index,
            handler: schemaKindDropdownChanged
        )
        dropdown.hexpand = true
        typeRow.append(child: dropdown)
    }

    fileprivate func handleKindChanged(_ index: Int) {
        let kinds = SchemaKind.allCases
        guard index >= 0, index < kinds.count else { return }
        let newKind = kinds[index]
        if SchemaKind(from: schema) == newKind { return }
        schema = newKind.defaultSchema()
        rebuildFields()
        onChanged(schema)
    }

    fileprivate func handleArrayItemKindChanged(_ index: Int) {
        let kinds = ArrayItemKind.allCases
        guard index >= 0, index < kinds.count else { return }
        let newKind = kinds[index]
        if case .array(let item, _) = schema, ArrayItemKind(from: item) == newKind { return }
        schema = .array(item: newKind.defaultItemSchema(), default: [])
        rebuildFields()
        onChanged(schema)
    }

    fileprivate func handleComboDefaultChanged(_ index: Int) {
        guard case .combo(let choices, _) = schema else { return }
        let pick: String? = (index <= 0) ? nil : (index <= choices.count ? choices[index - 1] : nil)
        schema = .combo(choices: choices, default: pick)
        onChanged(schema)
    }

    private func rebuildFields() {
        clearChildren(of: fieldsBox)
        childEditors.removeAll()

        switch schema {
        case .boolean:
            break
        case .int, .uint, .double:
            appendNumericRows()
        case .string(let d):
            fieldsBox.append(child: textRow(label: "Default", value: d, monospaced: false) { [weak self] text in
                self?.applyStringDefault(text)
            })
        case .regex(let d):
            fieldsBox.append(child: textRow(label: "Default", value: d, monospaced: true) { [weak self] text in
                self?.applyRegexDefault(text)
            })
        case .combo(let choices, let def):
            appendComboFields(choices: choices, defaultChoice: def)
        case .object(let fields):
            appendObjectFields(fields: fields)
        case .array(let item, _):
            appendArrayFields(item: item)
        }
    }

    private func appendNumericRows() {
        fieldsBox.append(child: numericRow(label: "Default", initialText: numericDefaultText()) { [weak self] text in
            self?.applyNumericDefault(text)
        })
        fieldsBox.append(child: numericRow(label: "Min", initialText: numericMinText()) { [weak self] text in
            self?.applyNumericMin(text)
        })
        fieldsBox.append(child: numericRow(label: "Max", initialText: numericMaxText()) { [weak self] text in
            self?.applyNumericMax(text)
        })
    }

    private func numericRow(label labelText: String, initialText: String, onChange: @escaping (String) -> Void) -> Box {
        let row = labeledRow(labelText)
        let entry = Entry()
        entry.text = initialText
        entry.placeholderText = "(none)"
        entry.hexpand = true
        entry.onChanged { _ in
            MainActor.assumeIsolated {
                onChange(entry.text ?? "")
            }
        }
        row.append(child: entry)
        return row
    }

    private func textRow(label labelText: String, value: String, monospaced: Bool, onChange: @escaping (String) -> Void) -> Box {
        let row = labeledRow(labelText)
        let entry = Entry()
        entry.text = value
        entry.hexpand = true
        if monospaced { entry.add(cssClass: "monospace") }
        entry.onChanged { _ in
            MainActor.assumeIsolated {
                onChange(entry.text ?? "")
            }
        }
        row.append(child: entry)
        return row
    }

    private func appendComboFields(choices: [String], defaultChoice: String?) {
        let header = Label(str: "Choices")
        header.halign = .start
        header.add(cssClass: "caption")
        fieldsBox.append(child: header)

        let editor = ChoicesEditor(choices: choices) { [weak self] newChoices in
            self?.applyComboChoices(newChoices)
        }
        childEditors.append(editor)
        fieldsBox.append(child: editor.widget)

        let defaultRow = labeledRow("Default")
        let labels = ["(first)"] + choices
        let selectedIndex = defaultChoice.flatMap { choices.firstIndex(of: $0).map { $0 + 1 } } ?? 0
        let dropdown = makeStringDropdown(
            labels: labels,
            selectedIndex: selectedIndex,
            handler: comboDefaultDropdownChanged
        )
        dropdown.hexpand = true
        defaultRow.append(child: dropdown)
        fieldsBox.append(child: defaultRow)
    }

    private func appendObjectFields(fields: [ObjectField]) {
        let editor = ObjectFieldsEditor(fields: fields) { [weak self] newFields in
            self?.applyObjectFields(newFields)
        }
        childEditors.append(editor)
        fieldsBox.append(child: editor.widget)
    }

    private func appendArrayFields(item: ArrayItemSchema) {
        let row = labeledRow("Item Type")
        let dropdown = makeStringDropdown(
            labels: ArrayItemKind.allCases.map(\.label),
            selectedIndex: ArrayItemKind(from: item).index,
            handler: arrayItemDropdownChanged
        )
        dropdown.hexpand = true
        row.append(child: dropdown)
        fieldsBox.append(child: row)

        switch item {
        case .combo(let choices):
            let header = Label(str: "Item Choices")
            header.halign = .start
            header.add(cssClass: "caption")
            fieldsBox.append(child: header)
            let editor = ChoicesEditor(choices: choices) { [weak self] newChoices in
                self?.applyArrayComboChoices(newChoices)
            }
            childEditors.append(editor)
            fieldsBox.append(child: editor.widget)
        case .object(let fields):
            let editor = ObjectFieldsEditor(fields: fields) { [weak self] newFields in
                self?.applyArrayObjectFields(newFields)
            }
            childEditors.append(editor)
            fieldsBox.append(child: editor.widget)
        default:
            break
        }
    }

    private func labeledRow(_ text: String) -> Box {
        let row = Box(orientation: .horizontal, spacing: 8)
        let label = Label(str: text)
        label.halign = .start
        label.setSizeRequest(width: 100, height: -1)
        row.append(child: label)
        return row
    }

    private func applyNumericDefault(_ text: String) {
        switch schema {
        case .int(_, let lo, let hi):
            schema = .int(default: parseInt64(text) ?? 0, min: lo, max: hi)
        case .uint(_, let lo, let hi):
            schema = .uint(default: parseUInt64(text) ?? 0, min: lo, max: hi)
        case .double(_, let lo, let hi):
            schema = .double(default: parseDouble(text) ?? 0, min: lo, max: hi)
        default:
            return
        }
        onChanged(schema)
    }

    private func applyNumericMin(_ text: String) {
        switch schema {
        case .int(let d, _, let hi):
            schema = .int(default: d, min: parseInt64(text), max: hi)
        case .uint(let d, _, let hi):
            schema = .uint(default: d, min: parseUInt64(text), max: hi)
        case .double(let d, _, let hi):
            schema = .double(default: d, min: parseDouble(text), max: hi)
        default:
            return
        }
        onChanged(schema)
    }

    private func applyNumericMax(_ text: String) {
        switch schema {
        case .int(let d, let lo, _):
            schema = .int(default: d, min: lo, max: parseInt64(text))
        case .uint(let d, let lo, _):
            schema = .uint(default: d, min: lo, max: parseUInt64(text))
        case .double(let d, let lo, _):
            schema = .double(default: d, min: lo, max: parseDouble(text))
        default:
            return
        }
        onChanged(schema)
    }

    private func applyStringDefault(_ text: String) {
        schema = .string(default: text)
        onChanged(schema)
    }

    private func applyRegexDefault(_ text: String) {
        schema = .regex(default: text)
        onChanged(schema)
    }

    private func applyComboChoices(_ newChoices: [String]) {
        guard case .combo(_, let d) = schema else { return }
        let preservedDefault = d.flatMap { newChoices.contains($0) ? $0 : nil }
        schema = .combo(choices: newChoices, default: preservedDefault)
        rebuildFields()
        onChanged(schema)
    }

    private func applyArrayComboChoices(_ newChoices: [String]) {
        schema = .array(item: .combo(choices: newChoices), default: [])
        onChanged(schema)
    }

    private func applyObjectFields(_ newFields: [ObjectField]) {
        schema = .object(fields: newFields)
        onChanged(schema)
    }

    private func applyArrayObjectFields(_ newFields: [ObjectField]) {
        schema = .array(item: .object(fields: newFields), default: [])
        onChanged(schema)
    }

    private func numericDefaultText() -> String {
        switch schema {
        case .int(let d, _, _): return String(d)
        case .uint(let d, _, _): return String(d)
        case .double(let d, _, _): return String(d)
        default: return ""
        }
    }

    private func numericMinText() -> String {
        switch schema {
        case .int(_, let lo, _): return lo.map { String($0) } ?? ""
        case .uint(_, let lo, _): return lo.map { String($0) } ?? ""
        case .double(_, let lo, _): return lo.map { String($0) } ?? ""
        default: return ""
        }
    }

    private func numericMaxText() -> String {
        switch schema {
        case .int(_, _, let hi): return hi.map { String($0) } ?? ""
        case .uint(_, _, let hi): return hi.map { String($0) } ?? ""
        case .double(_, _, let hi): return hi.map { String($0) } ?? ""
        default: return ""
        }
    }

    private func parseInt64(_ s: String) -> Int64? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : Int64(trimmed)
    }

    private func parseUInt64(_ s: String) -> UInt64? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : UInt64(trimmed)
    }

    private func parseDouble(_ s: String) -> Double? {
        let trimmed = s.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : Double(trimmed)
    }

    private func clearChildren(of box: Box) {
        var child = box.firstChild
        while let current = child {
            child = current.nextSibling
            box.remove(child: current)
        }
    }

    fileprivate func makeStringDropdown(
        labels: [String],
        selectedIndex: Int,
        handler: @convention(c) @escaping (
            UnsafeMutableRawPointer,
            UnsafeMutableRawPointer?,
            UnsafeMutableRawPointer?
        ) -> Void
    ) -> DropDown {
        let cStrings = labels.map { strdup($0) }
        defer { cStrings.forEach { free($0) } }
        var ptrs = cStrings.map { UnsafePointer($0) as UnsafePointer<CChar>? }
        ptrs.append(nil)
        let widgetPtr = ptrs.withUnsafeBufferPointer { buf in
            gtk_drop_down_new_from_strings(buf.baseAddress)
        }!
        g_object_ref_sink(UnsafeMutableRawPointer(widgetPtr))
        let dropdown = DropDown(raw: UnsafeMutableRawPointer(widgetPtr))
        if selectedIndex >= 0, selectedIndex < labels.count {
            dropdown.selected = selectedIndex
        }
        let context = Unmanaged.passUnretained(self).toOpaque()
        g_signal_connect_data(
            widgetPtr,
            "notify::selected",
            unsafeBitCast(handler, to: GCallback.self),
            context,
            nil,
            GConnectFlags(rawValue: 0)
        )
        return dropdown
    }
}

private let schemaKindDropdownChanged: @convention(c) (
    UnsafeMutableRawPointer,
    UnsafeMutableRawPointer?,
    UnsafeMutableRawPointer?
) -> Void = { widget, _, userData in
    guard let userData else { return }
    let editorPtr = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: userData))!
    let widgetPtr = UnsafeMutablePointer<GtkDropDown>(OpaquePointer(bitPattern: UInt(bitPattern: widget))!)
    MainActor.assumeIsolated {
        let editor = Unmanaged<CustomInstrumentSchemaEditor>.fromOpaque(editorPtr).takeUnretainedValue()
        editor.handleKindChanged(Int(gtk_drop_down_get_selected(widgetPtr)))
    }
}

private let arrayItemDropdownChanged: @convention(c) (
    UnsafeMutableRawPointer,
    UnsafeMutableRawPointer?,
    UnsafeMutableRawPointer?
) -> Void = { widget, _, userData in
    guard let userData else { return }
    let editorPtr = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: userData))!
    let widgetPtr = UnsafeMutablePointer<GtkDropDown>(OpaquePointer(bitPattern: UInt(bitPattern: widget))!)
    MainActor.assumeIsolated {
        let editor = Unmanaged<CustomInstrumentSchemaEditor>.fromOpaque(editorPtr).takeUnretainedValue()
        editor.handleArrayItemKindChanged(Int(gtk_drop_down_get_selected(widgetPtr)))
    }
}

private let comboDefaultDropdownChanged: @convention(c) (
    UnsafeMutableRawPointer,
    UnsafeMutableRawPointer?,
    UnsafeMutableRawPointer?
) -> Void = { widget, _, userData in
    guard let userData else { return }
    let editorPtr = UnsafeMutableRawPointer(bitPattern: UInt(bitPattern: userData))!
    let widgetPtr = UnsafeMutablePointer<GtkDropDown>(OpaquePointer(bitPattern: UInt(bitPattern: widget))!)
    MainActor.assumeIsolated {
        let editor = Unmanaged<CustomInstrumentSchemaEditor>.fromOpaque(editorPtr).takeUnretainedValue()
        editor.handleComboDefaultChanged(Int(gtk_drop_down_get_selected(widgetPtr)))
    }
}

@MainActor
final class ObjectFieldsEditor {
    let widget: Box
    private var fields: [ObjectField]
    private let onChanged: ([ObjectField]) -> Void
    private let listBox: Box
    private let draftEntry: Entry
    private var fieldSchemaEditors: [CustomInstrumentSchemaEditor] = []

    init(fields: [ObjectField], onChanged: @escaping ([ObjectField]) -> Void) {
        self.fields = fields
        self.onChanged = onChanged
        widget = Box(orientation: .vertical, spacing: 4)
        listBox = Box(orientation: .vertical, spacing: 4)
        draftEntry = Entry()
        draftEntry.placeholderText = "Field name"
        draftEntry.hexpand = true

        layout()
        rebuildList()
    }

    private func layout() {
        widget.append(child: listBox)

        let addRow = Box(orientation: .horizontal, spacing: 6)
        addRow.append(child: draftEntry)
        let addButton = Button(label: "+")
        addButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.appendDraft() }
        }
        addRow.append(child: addButton)
        widget.append(child: addRow)
    }

    private func rebuildList() {
        var child = listBox.firstChild
        while let current = child {
            child = current.nextSibling
            listBox.remove(child: current)
        }
        fieldSchemaEditors.removeAll()
        if fields.isEmpty {
            let empty = Label(str: "No fields defined.")
            empty.add(cssClass: "dim-label")
            empty.halign = .start
            listBox.append(child: empty)
            return
        }
        for (index, field) in fields.enumerated() {
            listBox.append(child: fieldRow(field: field, index: index))
        }
    }

    private func fieldRow(field: ObjectField, index: Int) -> Box {
        let card = Box(orientation: .vertical, spacing: 0)
        card.add(cssClass: "card")

        let column = Box(orientation: .vertical, spacing: 4)
        column.marginStart = 10
        column.marginEnd = 10
        column.marginTop = 10
        column.marginBottom = 10
        card.append(child: column)

        let header = Box(orientation: .horizontal, spacing: 6)
        let nameEntry = Entry()
        nameEntry.text = field.name
        nameEntry.hexpand = true
        nameEntry.onChanged { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, index < self.fields.count else { return }
                self.fields[index].name = nameEntry.text ?? ""
                self.onChanged(self.fields)
            }
        }
        header.append(child: nameEntry)

        let removeButton = Button(label: "−")
        removeButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, index < self.fields.count else { return }
                self.fields.remove(at: index)
                self.rebuildList()
                self.onChanged(self.fields)
            }
        }
        header.append(child: removeButton)
        column.append(child: header)

        let optionalRow = Box(orientation: .horizontal, spacing: 8)
        let optionalLabel = Label(str: "Optional")
        optionalLabel.halign = .start
        optionalLabel.setSizeRequest(width: 160, height: -1)
        optionalRow.append(child: optionalLabel)
        let optionalToggle = Switch()
        optionalToggle.active = field.optional
        optionalToggle.valign = .center
        optionalRow.append(child: optionalToggle)
        column.append(child: optionalRow)
        optionalRow.visible = !isBoolean(field.schema)

        let enabledRow = Box(orientation: .horizontal, spacing: 8)
        let enabledLabel = Label(str: "Enabled by default")
        enabledLabel.halign = .start
        enabledLabel.setSizeRequest(width: 160, height: -1)
        enabledRow.append(child: enabledLabel)
        let enabledToggle = Switch()
        enabledToggle.active = field.enabledByDefault
        enabledToggle.valign = .center
        enabledRow.append(child: enabledToggle)
        column.append(child: enabledRow)
        enabledRow.visible = field.optional

        optionalToggle.onStateSet { [weak self] _, state in
            MainActor.assumeIsolated {
                guard let self, index < self.fields.count else { return false }
                self.fields[index].optional = state
                enabledRow.visible = state
                self.onChanged(self.fields)
                return false
            }
        }
        enabledToggle.onStateSet { [weak self] _, state in
            MainActor.assumeIsolated {
                guard let self, index < self.fields.count else { return false }
                self.fields[index].enabledByDefault = state
                self.onChanged(self.fields)
                return false
            }
        }

        let editor = CustomInstrumentSchemaEditor(schema: field.schema) { [weak self] updated in
            MainActor.assumeIsolated {
                guard let self, index < self.fields.count else { return }
                self.fields[index].schema = updated
                let nowBoolean = self.isBoolean(updated)
                optionalRow.visible = !nowBoolean
                if nowBoolean, self.fields[index].optional {
                    self.fields[index].optional = false
                    optionalToggle.active = false
                    enabledRow.visible = false
                }
                self.onChanged(self.fields)
            }
        }
        fieldSchemaEditors.append(editor)
        column.append(child: editor.widget)

        return card
    }

    private func isBoolean(_ schema: FeatureSchema) -> Bool {
        if case .boolean = schema { return true }
        return false
    }

    private func appendDraft() {
        let trimmed = (draftEntry.text ?? "").trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !fields.contains(where: { $0.name == trimmed }) else { return }
        fields.append(ObjectField(name: trimmed, schema: .boolean))
        draftEntry.text = ""
        rebuildList()
        onChanged(fields)
    }
}

@MainActor
final class ChoicesEditor {
    let widget: Box
    private var choices: [String]
    private let onChanged: ([String]) -> Void
    private let listBox: Box
    private let draftEntry: Entry

    init(choices: [String], onChanged: @escaping ([String]) -> Void) {
        self.choices = choices
        self.onChanged = onChanged
        widget = Box(orientation: .vertical, spacing: 4)
        listBox = Box(orientation: .vertical, spacing: 4)
        draftEntry = Entry()
        draftEntry.placeholderText = "Add choice"
        draftEntry.hexpand = true

        layout()
        rebuildList()
    }

    private func layout() {
        widget.append(child: listBox)

        let addRow = Box(orientation: .horizontal, spacing: 6)
        addRow.append(child: draftEntry)
        let addButton = Button(label: "+")
        addButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated { self?.appendDraft() }
        }
        addRow.append(child: addButton)
        widget.append(child: addRow)
    }

    private func rebuildList() {
        var child = listBox.firstChild
        while let current = child {
            child = current.nextSibling
            listBox.remove(child: current)
        }
        for (index, choice) in choices.enumerated() {
            listBox.append(child: choiceRow(value: choice, index: index))
        }
    }

    private func choiceRow(value: String, index: Int) -> Box {
        let row = Box(orientation: .horizontal, spacing: 6)
        let entry = Entry()
        entry.text = value
        entry.hexpand = true
        entry.onChanged { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, index < self.choices.count else { return }
                self.choices[index] = entry.text ?? ""
                self.onChanged(self.choices)
            }
        }
        row.append(child: entry)
        let removeButton = Button(label: "−")
        removeButton.onClicked { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, index < self.choices.count else { return }
                self.choices.remove(at: index)
                self.rebuildList()
                self.onChanged(self.choices)
            }
        }
        row.append(child: removeButton)
        return row
    }

    private func appendDraft() {
        let trimmed = (draftEntry.text ?? "").trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, !choices.contains(trimmed) else { return }
        choices.append(trimmed)
        draftEntry.text = ""
        rebuildList()
        onChanged(choices)
    }
}

enum SchemaKind: CaseIterable {
    case boolean, int, uint, double, string, regex, combo, object, array

    var label: String {
        switch self {
        case .boolean: return "Boolean"
        case .int: return "Integer (signed)"
        case .uint: return "Integer (unsigned)"
        case .double: return "Float"
        case .string: return "String"
        case .regex: return "Regex"
        case .combo: return "Combo"
        case .object: return "Object"
        case .array: return "Array"
        }
    }

    var index: Int {
        Self.allCases.firstIndex(of: self)!
    }

    init(from schema: FeatureSchema) {
        switch schema {
        case .boolean: self = .boolean
        case .int: self = .int
        case .uint: self = .uint
        case .double: self = .double
        case .string: self = .string
        case .regex: self = .regex
        case .combo: self = .combo
        case .object: self = .object
        case .array: self = .array
        }
    }

    func defaultSchema() -> FeatureSchema {
        switch self {
        case .boolean: return .boolean
        case .int: return .int(default: 0, min: nil, max: nil)
        case .uint: return .uint(default: 0, min: nil, max: nil)
        case .double: return .double(default: 0, min: nil, max: nil)
        case .string: return .string(default: "")
        case .regex: return .regex(default: "")
        case .combo: return .combo(choices: [], default: nil)
        case .object: return .object(fields: [])
        case .array: return .array(item: .string, default: [])
        }
    }
}

enum ArrayItemKind: CaseIterable {
    case boolean, int, uint, double, string, regex, combo, object

    var label: String {
        switch self {
        case .boolean: return "Boolean"
        case .int: return "Integer (signed)"
        case .uint: return "Integer (unsigned)"
        case .double: return "Float"
        case .string: return "String"
        case .regex: return "Regex"
        case .combo: return "Combo"
        case .object: return "Object"
        }
    }

    var index: Int {
        Self.allCases.firstIndex(of: self)!
    }

    init(from item: ArrayItemSchema) {
        switch item {
        case .boolean: self = .boolean
        case .int: self = .int
        case .uint: self = .uint
        case .double: self = .double
        case .string: self = .string
        case .regex: self = .regex
        case .combo: self = .combo
        case .object: self = .object
        }
    }

    func defaultItemSchema() -> ArrayItemSchema {
        switch self {
        case .boolean: return .boolean
        case .int: return .int
        case .uint: return .uint
        case .double: return .double
        case .string: return .string
        case .regex: return .regex
        case .combo: return .combo(choices: [])
        case .object: return .object(fields: [])
        }
    }
}
