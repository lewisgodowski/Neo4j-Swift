import Foundation
import Bolt
import PackStream

public protocol ResponseItem {}

public class Node: ResponseItem {
    public var id: UInt64? = nil
    internal let instanceId: Int = UUID().uuidString.hashValue

    /// Alias used when generating queries
    public private(set) var modified: Bool = false
    public private(set) var updatedTime: Date = Date()
    public private(set) var createdTime: Date? = nil

    public private(set) var properties: [String: PackProtocol] = [:]
    public private(set) var labels: [String] = []

    internal private(set) var updatedProperties: [String: PackProtocol] = [:]
    internal private(set) var removedPropertyKeys = Set<String>()
    internal private(set) var addedLabels: [String] = []
    internal private(set) var removedLabels: [String] = []

    public convenience init(label: String, properties: [String: PackProtocol]) {
        self.init(labels: [label], properties: properties)
    }

    public convenience init() {
        self.init(labels: [], properties: [:])
    }

    public init(labels: [String], properties: [String: PackProtocol]) {
        self.labels = labels
        self.properties = properties

        self.modified = false
        self.createdTime = Date()
        self.updatedTime = Date()
    }

    init?(data: PackProtocol) {
        if let s = data as? Structure,
           s.signature == 78,
           s.items.count >= 3,
           let nodeId = s.items[0].uintValue(),
           let labelsList = s.items[1] as? List,
           let properties = (s.items[2] as? Map)?.dictionary
        {
            self.id = nodeId
            self.labels = labelsList.items.compactMap { $0 as? String }
            self.properties = properties
            self.modified = false

            self.createdTime = Date()
            self.updatedTime = Date()
        } else {
            return nil
        }
    }

    public func add(label: String) {
        labels.append(label)
        addedLabels.append(label)
        removedLabels = removedLabels.filter { $0 != label }
    }

    public func remove(label: String) {
        labels = labels.filter { $0 != label }
        removedLabels.append(label)
        addedLabels = addedLabels.filter { $0 != label }
    }


    // MARK: - Create

    public func createRequest(
        withReturnStatement: Bool = true,
        nodeAlias: String = "node"
    ) -> Request {
        let (query, properties) = createRequestQuery(
            withReturnStatement: withReturnStatement,
            nodeAlias: nodeAlias
        )
        return Request.run(statement: query, parameters: Map(dictionary: properties))
    }

    public func createRequestQuery(
        withReturnStatement: Bool = true,
        nodeAlias: String = "node",
        paramSuffix: String = "",
        withCreate: Bool = true
    ) -> (String, [String: PackProtocol]) {
        let nodeAlias = nodeAlias == "" ? nodeAlias : "`\(nodeAlias)`"
        let labels = labels.map { "`\($0)`" }.joined(separator: ":")
        let params = properties.keys.map { "`\($0)`: $\($0)\(paramSuffix)" }.joined(separator: ", ")

        var query = "\(withCreate ? "CREATE" : "") (\(nodeAlias):\(labels) { \(params) })"
        if withReturnStatement {
            query += " RETURN \(nodeAlias)"
        }

        let properties = Dictionary(
            uniqueKeysWithValues: properties.map { ("\($0.key)\(paramSuffix)", $0.value) }
        )

        return (query, properties)
    }


    // MARK: - Update

    public func updateRequest(
        withReturnStatement: Bool = true,
        nodeAlias: String = "node"
    ) -> Request {
        let (query, properties) = updateRequestQuery(
            withReturnStatement: withReturnStatement,
            nodeAlias: nodeAlias
        )
        return Request.run(statement: query, parameters: Map(dictionary: properties))
    }

    public func updateRequestQuery(
        withReturnStatement: Bool = true,
        nodeAlias: String = "node",
        paramSuffix: String = ""
    ) -> (String, [String:PackProtocol]) {
        guard let id else {
            print("Error: Cannot create update request for node without id. Did you mean to create it?")
            return ("", [:])
        }

        let nodeAlias = nodeAlias == "" ? nodeAlias : "`\(nodeAlias)`"
        var properties = [String: PackProtocol]()
        let addedLabels = addedLabels.count == 0
        ? ""
        : "\(nodeAlias):" + addedLabels.map { "`\($0)`" }.joined(separator: ":")

        properties.merge(
            updatedProperties.map { ("\($0.key)\(paramSuffix)", $0.value) },
            uniquingKeysWith: { $1 }
        )

        let updatedProperties = updatedProperties.keys
            .map { "\(nodeAlias).`\($0)` = $\($0)\(paramSuffix)" }
            .joined(separator: ", ")

        let update: String
        if addedLabels != "" && updatedProperties != "" {
            update = "SET \([addedLabels, updatedProperties].joined(separator: ", "))\n"
        } else if addedLabels != "" {
            update = "SET \(addedLabels)\n"
        } else if updatedProperties != "" {
            update = "SET \(updatedProperties)\n"
        } else {
            update = ""
        }

        let removedProperties = removedPropertyKeys.count == 0
        ? ""
        : removedPropertyKeys.map { "\(nodeAlias).`\($0)`" }.joined(separator: ", ")

        let removedLabels = removedLabels.count == 0
        ? ""
        : removedLabels.map { "\(nodeAlias):`\($0)`" }.joined(separator: ", ")

        let remove: String
        if removedLabels.count > 0 && removedProperties.count > 0 {
            remove = "REMOVE \([removedLabels, removedProperties].joined(separator: ", "))\n"
        } else if removedLabels.count > 0 {
            remove = "REMOVE \(removedLabels)\n"
        } else if removedProperties.count > 0 {
            remove = "REMOVE \(removedProperties)\n"
        } else {
            remove = ""
        }

        var query = "MATCH (\(nodeAlias))\nWHERE id(\(nodeAlias)) = \(id)\n\(update)\(remove)"
        if withReturnStatement {
            query += "RETURN \(nodeAlias)"
        }

        return (query, properties)
    }

    public func setProperty(key: String, value: PackProtocol?) {
        if let value {
            properties[key] = value
            updatedProperties[key] = value
            removedPropertyKeys.remove(key)
        } else {
            properties.removeValue(forKey: key)
            removedPropertyKeys.insert(key)
        }
        modified = true
    }

    public subscript(key: String) -> PackProtocol? {
        get {
            updatedProperties[key] ?? properties[key]
        }
        set (newValue) {
            setProperty(key: key, value: newValue)
        }
    }


    // MARK: - Delete

    public func deleteRequest(nodeAlias: String = "node") -> Request {
        Request.run(
            statement: deleteRequestQuery(nodeAlias: nodeAlias),
            parameters: Map(dictionary: [:])
        )
    }

    public func deleteRequestQuery(nodeAlias: String = "node") -> String {
        guard let id else {
            print("Error: Cannot create delete request for node without id. Did you mean to create it?")
            return ""
        }

        let nodeAlias = nodeAlias == "" ? nodeAlias : "`\(nodeAlias)`"
        return """
      MATCH (\(nodeAlias))
      WHERE id(\(nodeAlias)) = \(id)
      DETACH DELETE \(nodeAlias)
    """
    }


    // MARK: - Query

    public static func queryFor(
        labels: [String],
        andProperties properties: [String:PackProtocol],
        nodeAlias: String = "node",
        skip: UInt64 = 0,
        limit: UInt64 = 20
    ) -> Request {
        let nodeAlias = nodeAlias == "" ? nodeAlias : "`\(nodeAlias)`"

        let cleanedLabels = labels.map { label -> (String) in
            if label.contains(" ") {
                if label.contains("`") {
                    return label
                } else {
                    return "`\(label)`"
                }
            } else {
                return label
            }
        }

        var labelQuery = cleanedLabels.joined(separator: ":")
        if labelQuery != "" {
            labelQuery = ":" + labelQuery
        }

        var propertiesQuery = properties.keys
            .map { "\(nodeAlias).`\($0)`= $\($0)" }
            .joined(separator: "\nAND ")
        if propertiesQuery != "" {
            propertiesQuery = "WHERE " + propertiesQuery
        }

        let skipQuery = skip > 0 ? " SKIP \(skip)" : ""
        let limitQuery = limit > 0 ? " LIMIT \(limit)" : ""
        let query = """
      MATCH (\(nodeAlias)\(labelQuery))
      \(propertiesQuery)
      RETURN \(nodeAlias)\(skipQuery)\(limitQuery)
    """

        return Request.run(statement: query, parameters: Map(dictionary: properties))
    }
}


// MARK: - Array

extension Array where Element: Node {
    public func createRequest(withReturnStatement: Bool = true) -> Request {
        var aliases = [String]()
        var queries = [String]()
        var properties = [String: PackProtocol]()
        for i in 0..<self.count {
            let node = self[i]
            let nodeAlias = "node\(i)"
            let (query, props) = node.createRequestQuery(
                withReturnStatement: false,
                nodeAlias: nodeAlias,
                paramSuffix: "\(i)",
                withCreate: i == 0
            )
            queries.append(query)
            aliases.append(nodeAlias)
            props.forEach { properties[$0.key] = $0.value }
        }

        var query = queries.joined(separator: ", ")
        if withReturnStatement {
            query += " RETURN \(aliases.map { "`\($0)`" }.joined(separator: ","))"
        }

        return Request.run(statement: query, parameters: Map(dictionary: properties))
    }

    public func updateRequest(withReturnStatement: Bool = true) -> Request {
        var aliases = [String]()
        var idMaps = [String]()

        var addedLabels = [String]()
        var updatedProperties = [String]()
        var properties = [String: PackProtocol]()
        var removedProperties = [String]()
        var removedLabels = [String]()

        for i in 0..<self.count {
            let node = self[i]
            let nodeAlias = "`node\(i)`"
            aliases.append(nodeAlias)

            guard let nodeId = node.id else {
                print("All nodes must have been created before being updated, but found node with no id, so aborting update")
                return Request.run(statement: "", parameters: Map(dictionary: [:]))
            }

            idMaps.append("id(\(nodeAlias)) = \(nodeId)")

            for (key, value) in node.updatedProperties {
                updatedProperties.append("\(nodeAlias).`\(key)` = $\(key)\(i)")
                properties["\(key)\(i)"] = value
            }

            if !node.addedLabels.isEmpty {
                addedLabels.append(
                    nodeAlias + ":" + node.addedLabels.map { "`\($0)`" }.joined(separator: ":")
                )
            }

            if !node.removedPropertyKeys.isEmpty {
                for prop in node.removedPropertyKeys {
                    removedProperties.append("\(nodeAlias).`\(prop)`")
                }
            }

            if !node.removedLabels.isEmpty {
                for label in node.removedLabels {
                    removedLabels.append("\(nodeAlias):`\(label)`")
                }
            }
        }

        let updates = addedLabels + updatedProperties
        let remove = removedLabels + removedProperties

        var query = "MATCH " + aliases.map { "(\($0))" }.joined(separator: ", ")
        query = query + "\nWHERE " + idMaps.joined(separator: "\nAND ")
        query = query + "\nSET " + updates.joined(separator: ", ")
        query = query + "\nREMOVE " + remove.joined(separator: ", ")

        if withReturnStatement {
            query += "\nRETURN " + aliases.joined(separator: ", ")
        }

        return Request.run(statement: query, parameters: Map(dictionary: properties))
    }

    public func deleteRequest(withReturnStatement: Bool = true) -> Request {
        let ids = compactMap { $0.id }.map { "\($0)" }.joined(separator: ", ")
        let nodeAlias = "`node`"

        let query = """
      MATCH (\(nodeAlias))
      WHERE id(\(nodeAlias)) IN [\(ids)]
      DETACH DELETE \(nodeAlias)
    """

        return Request.run(statement: query, parameters: Map(dictionary: [:]))
    }
}


// MARK: - Equatable

extension Node: Equatable {
    public static func == (lhs: Node, rhs: Node) -> Bool {

        if lhs.id != rhs.id { return false }
        if lhs.labels != rhs.labels { return false }


        let lKeys = lhs.properties.keys.sorted()
        let rKeys = lhs.properties.keys.sorted()
        if lKeys  != rKeys { return false }

        for key in lKeys {
            let lVal = lhs.properties[key]
            let rVal = rhs.properties[key]
            let lType = type(of: lVal)
            let rType = type(of: rVal)
            if lType != rType {
                return false
            }

            if let l = lVal as? Bool, let r = rVal as? Bool {
                if l != r { return false }
            } else if let l = lVal as? Double, let r = rVal as? Double {
                if l != r { return false }
                //      } else if let l = lVal as? UInt8, let r = rVal as? UInt8 {
                //        if l != r { return false }
                //      } else if let l = lVal as? UInt16, let r = rVal as? UInt16 {
                //        if l != r { return false }
                //      } else if let l = lVal as? UInt32, let r = rVal as? UInt32 {
                //        if l != r { return false }
            } else if let l = lVal as? Int8, let r = rVal as? Int8 {
                if l != r { return false }
            } else if let l = lVal as? Int16, let r = rVal as? Int16 {
                if l != r { return false }
            } else if let l = lVal as? Int32, let r = rVal as? Int32 {
                if l != r { return false }
            } else if let l = lVal as? Int64, let r = rVal as? Int64 {
                if l != r { return false }
                //      } else if let l = lVal as? UInt, let r = rVal as? UInt {
                //        if l != r { return false }
            } else if let l = lVal as? Int, let r = rVal as? Int {
                if l != r { return false }
            } else if let l = lVal as? List, let r = rVal as? List {
                if l != r { return false }
            } else if let l = lVal as? Map, let r = rVal as? Map {
                if l != r { return false }
            } else if let _ = lVal as? Null, let _ = rVal as? Null {
                continue
            } else if let l = lVal as? String, let r = rVal as? String {
                if l != r { return false }
            } else if let l = lVal as? Structure, let r = rVal as? Structure {
                if l != r { return false }
            }
        }

        return true
    }
}
