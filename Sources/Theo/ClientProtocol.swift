import Bolt
import Foundation
import PackStream

public protocol ClientProtocol: AnyObject {
    // MARK: - Connect/Disconnect

    func connect() async throws
    func disconnect()


    // MARK: - Execute

    func executeR(
        request: Request,
        completionBlock: ((Result<(Bool, QueryResult), Error>) -> ())?
    )

    @discardableResult
    func execute(request: Request) async throws -> QueryResult

    @discardableResult
    func executeCypher(_ query: String, params: [String: PackProtocol]) async throws -> QueryResult

    func executeAsTransaction(
        mode: Request.TransactionMode,
        operations: @escaping (_ transaction: Transaction) async throws -> ()
    ) async throws


    // MARK: - Reset

    func reset() async throws


    // MARK: - Other

    func pullAll(partialQueryResult: QueryResult) async throws -> QueryResult


    // MARK: - Create Node(s)

    @discardableResult
    func create(node: Node) async throws -> Node

    @discardableResult
    func create(nodes: [Node]) async throws -> [Node]


    // MARK: - Get Node(s)

    func get(nodeID: UInt64) async throws -> Node?
    func get(customNodeID: NodeID) async throws -> Node?
    func get(
        labels: [String],
        properties: [String: PackProtocol],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Node]


    // MARK: - Update Node(s)

    @discardableResult
    func update(node: Node) async throws -> Node

    @discardableResult
    func update(nodes: [Node]) async throws -> [Node]


    // MARK: - Delete Node(s)

    func delete(node: Node) async throws
    func delete(nodes: [Node]) async throws


    // MARK: - Relate Nodes

    func relate(
        node: Node,
        to: Node,
        type: String,
        properties: [String: PackProtocol]
    ) async throws -> Relationship


    // MARK: - Create Relationship(s)

    @discardableResult
    func create(relationship: Relationship) async throws -> Relationship

    @discardableResult
    func create(relationships: [Relationship]) async throws -> [Relationship]


    // MARK: - Get Relationship(s)

    func get(
        type: String,
        properties: [String: PackProtocol],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Relationship]


    // MARK: - Update Relationship(s)

    @discardableResult
    func update(relationship: Relationship) async throws -> Relationship

    @discardableResult
    func update(relationships: [Relationship]) async throws -> [Relationship]


    // MARK: - Delete Relationship(s)

    func delete(relationship: Relationship) async throws
    func delete(relationships: [Relationship]) async throws
}


// MARK: - Default Values

extension ClientProtocol {
    public func executeCypher(
        _ query: String,
        params: [String: PackProtocol] = [:]
    ) async throws -> QueryResult {
        try await executeCypher(query, params: params)
    }

    public func executeAsTransaction(
        mode: Request.TransactionMode = .readonly,
        operations: @escaping (_ transaction: Transaction) async throws -> ()
    ) async throws {
        try await executeAsTransaction(mode: mode, operations: operations)
    }

    public func get(
        labels: [String] = [],
        properties: [String: PackProtocol] = [:],
        skip: UInt64 = 0,
        limit: UInt64 = 25
    ) async throws -> [Node] {
        try await get(labels: labels, properties: properties, skip: skip, limit: limit)
    }

    public func relate(
        node: Node,
        to: Node,
        type: String,
        properties: [String: PackProtocol] = [:]
    ) async throws -> Relationship {
        try await relate(node: node, to: to, type: type, properties: properties)
    }

    public func get(
        type: String,
        properties: [String: PackProtocol] = [:],
        skip: UInt64 = 0,
        limit: UInt64 = 25
    ) async throws -> [Relationship] {
        try await get(type: type, properties: properties, skip: skip, limit: limit)
    }
}
