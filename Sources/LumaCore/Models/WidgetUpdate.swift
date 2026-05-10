import Foundation

public struct WidgetUpdate: Sendable, Identifiable {
    public let id: UUID
    public let instanceID: UUID
    public let widget: String
    public let kind: Kind

    public init(id: UUID = UUID(), instanceID: UUID, widget: String, kind: Kind) {
        self.id = id
        self.instanceID = instanceID
        self.widget = widget
        self.kind = kind
    }

    public enum Kind: Sendable {
        case graphPoint(WidgetGraphPoint)
        case listUpsert(WidgetListItem)
        case listRemove(itemID: String)
        case clear
    }

    public func toWireJSON() -> [String: Any] {
        var obj: [String: Any] = [
            "instance_id": instanceID.uuidString,
            "widget": widget,
        ]
        switch kind {
        case .graphPoint(let point):
            obj["kind"] = "graph-point"
            obj["point"] = ["series": point.series, "x": point.x, "y": point.y]
        case .listUpsert(let item):
            obj["kind"] = "list-upsert"
            var itemObj: [String: Any] = ["id": item.id, "title": item.title]
            if let s = item.subtitle { itemObj["subtitle"] = s }
            if let a = item.accessory { itemObj["accessory"] = a }
            obj["item"] = itemObj
        case .listRemove(let itemID):
            obj["kind"] = "list-remove"
            obj["item"] = itemID
        case .clear:
            obj["kind"] = "clear"
        }
        return obj
    }

    public static func fromWireJSON(_ obj: [String: Any]) -> WidgetUpdate? {
        guard let instanceIDStr = obj["instance_id"] as? String,
            let instanceID = UUID(uuidString: instanceIDStr),
            let widget = obj["widget"] as? String,
            let kindStr = obj["kind"] as? String
        else { return nil }
        let kind: Kind
        switch kindStr {
        case "graph-point":
            guard let pointObj = obj["point"] as? [String: Any],
                let series = pointObj["series"] as? String,
                let x = (pointObj["x"] as? NSNumber).map({ $0.doubleValue }),
                let y = (pointObj["y"] as? NSNumber).map({ $0.doubleValue })
            else { return nil }
            kind = .graphPoint(WidgetGraphPoint(series: series, x: x, y: y))
        case "list-upsert":
            guard let itemObj = obj["item"] as? [String: Any],
                let id = itemObj["id"] as? String,
                let title = itemObj["title"] as? String
            else { return nil }
            kind = .listUpsert(WidgetListItem(
                id: id,
                title: title,
                subtitle: itemObj["subtitle"] as? String,
                accessory: itemObj["accessory"] as? String
            ))
        case "list-remove":
            guard let itemID = obj["item"] as? String else { return nil }
            kind = .listRemove(itemID: itemID)
        case "clear":
            kind = .clear
        default:
            return nil
        }
        return WidgetUpdate(instanceID: instanceID, widget: widget, kind: kind)
    }
}

public struct WidgetGraphPoint: Codable, Sendable, Equatable {
    public let series: String
    public let x: Double
    public let y: Double

    public init(series: String, x: Double, y: Double) {
        self.series = series
        self.x = x
        self.y = y
    }
}

public struct WidgetListItem: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public var title: String
    public var subtitle: String?
    public var accessory: String?

    public init(id: String, title: String, subtitle: String? = nil, accessory: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }
}

public struct WidgetStateSnapshot: Sendable {
    public let sessionID: UUID
    public let instanceID: UUID
    public let widget: String
    public let state: WidgetState

    public init(sessionID: UUID, instanceID: UUID, widget: String, state: WidgetState) {
        self.sessionID = sessionID
        self.instanceID = instanceID
        self.widget = widget
        self.state = state
    }

    public static func fromWireJSON(_ obj: [String: Any]) -> WidgetStateSnapshot? {
        guard let sessionStr = obj["session_id"] as? String,
            let sessionID = UUID(uuidString: sessionStr),
            let instanceStr = obj["instance_id"] as? String,
            let instanceID = UUID(uuidString: instanceStr),
            let widget = obj["widget"] as? String,
            let stateObj = obj["state"] as? [String: Any]
        else { return nil }

        var graphSeries: [String: [WidgetGraphPoint]] = [:]
        if let pts = stateObj["points"] as? [[String: Any]] {
            for p in pts {
                guard let series = p["series"] as? String,
                    let x = (p["x"] as? NSNumber).map({ $0.doubleValue }),
                    let y = (p["y"] as? NSNumber).map({ $0.doubleValue })
                else { continue }
                graphSeries[series, default: []].append(WidgetGraphPoint(series: series, x: x, y: y))
            }
        }

        var listItems: [WidgetListItem] = []
        if let items = stateObj["items"] as? [[String: Any]] {
            for it in items {
                guard let id = it["id"] as? String, let title = it["title"] as? String else { continue }
                listItems.append(WidgetListItem(
                    id: id,
                    title: title,
                    subtitle: it["subtitle"] as? String,
                    accessory: it["accessory"] as? String
                ))
            }
        }

        return WidgetStateSnapshot(
            sessionID: sessionID,
            instanceID: instanceID,
            widget: widget,
            state: WidgetState(graphSeries: graphSeries, listItems: listItems)
        )
    }
}

public struct WidgetState: Codable, Sendable, Equatable {
    public var graphSeries: [String: [WidgetGraphPoint]]
    public var listItems: [WidgetListItem]

    public init(
        graphSeries: [String: [WidgetGraphPoint]] = [:],
        listItems: [WidgetListItem] = []
    ) {
        self.graphSeries = graphSeries
        self.listItems = listItems
    }

    public mutating func apply(_ kind: WidgetUpdate.Kind) {
        switch kind {
        case .graphPoint(let point):
            graphSeries[point.series, default: []].append(point)
        case .listUpsert(let item):
            if let index = listItems.firstIndex(where: { $0.id == item.id }) {
                listItems[index] = item
            } else {
                listItems.append(item)
            }
        case .listRemove(let id):
            listItems.removeAll { $0.id == id }
        case .clear:
            graphSeries.removeAll()
            listItems.removeAll()
        }
    }
}
