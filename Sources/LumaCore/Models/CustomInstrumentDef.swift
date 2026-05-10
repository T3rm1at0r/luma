import Foundation
import GRDB

public struct CustomInstrumentDef: Codable, Identifiable, Sendable, Equatable, FetchableRecord, PersistableRecord {
    public static let databaseTableName = "custom_instrument_def"

    public var id: UUID
    public var name: String
    public var icon: InstrumentIcon
    public var source: String
    public var features: [Feature]
    public var widgets: [InstrumentWidget]
    public var createdAt: Date
    public var updatedAt: Date

    public struct Feature: Codable, Identifiable, Sendable, Equatable {
        public var id: String
        public var name: String
        public var schema: FeatureSchema
        public var optional: Bool
        public var enabledByDefault: Bool

        public init(
            id: String,
            name: String,
            schema: FeatureSchema = .boolean(default: true),
            optional: Bool = true,
            enabledByDefault: Bool = true
        ) {
            self.id = id
            self.name = name
            self.schema = schema
            self.optional = optional
            self.enabledByDefault = enabledByDefault
        }
    }

    public init(
        id: UUID = UUID(),
        name: String,
        icon: InstrumentIcon = .symbolic(InstrumentIconCatalog.default.id),
        source: String = CustomInstrumentDef.exampleSource,
        features: [Feature] = [],
        widgets: [InstrumentWidget] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.source = source
        self.features = features
        self.widgets = widgets
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(row: Row) throws {
        id = UUID(uuidString: row["id"])!
        name = row["name"]
        icon = InstrumentIcon.decodedJSONString(row["icon"])
        source = row["source"]
        let featuresJSON: String = row["features_json"]
        features = try JSONDecoder().decode([Feature].self, from: Data(featuresJSON.utf8))
        let widgetsJSON: String = row["widgets_json"]
        widgets = try JSONDecoder().decode([InstrumentWidget].self, from: Data(widgetsJSON.utf8))
        createdAt = row["created_at"]
        updatedAt = row["updated_at"]
    }

    public func encode(to container: inout PersistenceContainer) {
        container["id"] = id.uuidString
        container["name"] = name
        container["icon"] = icon.encodedJSONString()
        container["source"] = source
        container["features_json"] = featuresJSONString
        container["widgets_json"] = widgetsJSONString
        container["created_at"] = createdAt
        container["updated_at"] = updatedAt
    }

    public func toJSON() -> [String: Any] {
        [
            "id": id.uuidString,
            "name": name,
            "icon": icon.toJSON(),
            "source": source,
            "features": features.map(featureToJSON),
            "widgets": widgetsJSONArray,
            "created_at": ISO8601DateFormatter().string(from: createdAt),
            "updated_at": ISO8601DateFormatter().string(from: updatedAt),
        ]
    }

    public static func fromJSON(_ obj: [String: Any]) -> CustomInstrumentDef? {
        guard let idStr = obj["id"] as? String, let id = UUID(uuidString: idStr),
            let name = obj["name"] as? String,
            let icon = InstrumentIcon.fromJSON(obj["icon"]),
            let source = obj["source"] as? String
        else { return nil }
        let features = parseFeatures(obj["features"])
        let widgets = parseWidgets(obj["widgets"])
        let isoFmt = ISO8601DateFormatter()
        let createdAt = (obj["created_at"] as? String).flatMap(isoFmt.date(from:)) ?? Date()
        let updatedAt = (obj["updated_at"] as? String).flatMap(isoFmt.date(from:)) ?? Date()
        return CustomInstrumentDef(
            id: id,
            name: name,
            icon: icon,
            source: source,
            features: features,
            widgets: widgets,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    private var featuresJSONString: String {
        let data = try! JSONEncoder().encode(features)
        return String(decoding: data, as: UTF8.self)
    }

    private var widgetsJSONString: String {
        let data = try! JSONEncoder().encode(widgets)
        return String(decoding: data, as: UTF8.self)
    }

    private var widgetsJSONArray: [Any] {
        let data = try! JSONEncoder().encode(widgets)
        return try! JSONSerialization.jsonObject(with: data) as! [Any]
    }

    private static func parseFeatures(_ raw: Any?) -> [Feature] {
        guard let arr = raw as? [[String: Any]] else { return [] }
        return arr.compactMap(parseFeature)
    }

    private static func parseWidgets(_ raw: Any?) -> [InstrumentWidget] {
        guard let arr = raw as? [Any],
            let data = try? JSONSerialization.data(withJSONObject: arr),
            let widgets = try? JSONDecoder().decode([InstrumentWidget].self, from: data)
        else { return [] }
        return widgets
    }

    private static func parseFeature(_ obj: [String: Any]) -> Feature? {
        guard let id = obj["id"] as? String, let name = obj["name"] as? String else { return nil }
        let schema = parseFeatureSchema(obj["schema"]) ?? .boolean(default: false)
        let enabledByDefault = (obj["enabled_by_default"] as? Bool) ?? true
        return Feature(id: id, name: name, schema: schema, enabledByDefault: enabledByDefault)
    }

    private static func parseFeatureSchema(_ raw: Any?) -> FeatureSchema? {
        guard let obj = raw as? [String: Any] else { return nil }
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: obj)
        } catch {
            return nil
        }
        return try? JSONDecoder().decode(FeatureSchema.self, from: data)
    }

    private func featureToJSON(_ feature: Feature) -> [String: Any] {
        var out: [String: Any] = [
            "id": feature.id,
            "name": feature.name,
            "enabled_by_default": feature.enabledByDefault,
        ]
        if let data = try? JSONEncoder().encode(feature.schema),
            let schemaObj = try? JSONSerialization.jsonObject(with: data)
        {
            out["schema"] = schemaObj
        }
        return out
    }

    public mutating func normalize() {
        for i in features.indices {
            features[i].schema = CustomInstrumentDef.normalizedSchema(features[i].schema)
            if case .boolean = features[i].schema, features[i].optional {
                features[i].optional = false
            }
        }
    }

    private static func normalizedSchema(_ schema: FeatureSchema) -> FeatureSchema {
        switch schema {
        case .object(let fields):
            return .object(fields: fields.map(normalizedField))
        case .array(let item, let d):
            return .array(item: normalizedArrayItem(item), default: d)
        default:
            return schema
        }
    }

    private static func normalizedField(_ field: ObjectField) -> ObjectField {
        var copy = field
        copy.schema = normalizedSchema(field.schema)
        if case .boolean = copy.schema, copy.optional {
            copy.optional = false
        }
        return copy
    }

    private static func normalizedArrayItem(_ item: ArrayItemSchema) -> ArrayItemSchema {
        switch item {
        case .object(let fields):
            return .object(fields: fields.map(normalizedField))
        default:
            return item
        }
    }

    public static let exampleSource: String = """
        // A custom instrument is a regular Frida agent module. It runs in
        // the target process and exports an `instrument` object that the
        // host loads via the standard instrument lifecycle.
        //
        // create():    install your hooks; return updateConfig + dispose,
        //              plus onAction if you declared list widgets.
        // dispose():   undo every side effect (detach listeners, revert
        //              replacements). Save will call this and then re-create
        //              with the new source.
        //
        // Features declared in the sidebar show up on `config.features`
        // typed exactly as you defined them. Accessing a feature you have
        // not declared is a type error.
        //
        // Widgets declared in the sidebar render in the instance pane and
        // are accessed via `ctx.widget(id)`:
        //   - graph: push({ series, x, y }), clear()
        //   - list:  upsertItem({ id, title, subtitle?, accessory? }),
        //            removeItem(id), clear()
        // Per-item action buttons on a list widget invoke onAction({
        // widget, action, item }) on the handle. The `widget` and `action`
        // fields are narrowed to the ids you declared.
        //
        // The example below assumes one feature `logStack` (Boolean), one
        // graph widget `opens` with series `count`, and one list widget
        // `paths` with action `bookmark`. Until you add them, the lines
        // referencing them are type errors — add them via right-click →
        // Features… / Widgets…, or delete the corresponding lines.

        export const instrument: CustomInstrument = {
            create(ctx, config, restored) {
                let current = config;
                const listeners: InvocationListener[] = [];
                const bookmarks = new Set<string>();
                let count = restored.opens.points.length;

                const open = Module.findGlobalExportByName("open");
                if (open !== null) {
                    listeners.push(Interceptor.attach(open, {
                        onEnter(args) {
                            const path = args[0].readUtf8String() ?? "";
                            ctx.emit({ syscall: "open", path });
                            ctx.widget("opens").push({ series: "count", x: Date.now(), y: ++count });
                            ctx.widget("paths").upsertItem({ id: path, title: path });
                            // if (current.features.logStack) {
                            //     ctx.emit({ stack: this.context.sp.readByteArray(64) });
                            // }
                        }
                    }));
                }

                return {
                    updateConfig(next) {
                        current = next;
                    },
                    onAction(action) {
                        if (action.widget === "paths" && action.action === "bookmark") {
                            bookmarks.add(action.item);
                            ctx.emit({ bookmarked: action.item });
                        }
                    },
                    dispose() {
                        for (const l of listeners) {
                            l.detach();
                        }
                    }
                };
            }
        };
        """
}
