import Foundation
import Bolt
import PackStream

public protocol ClientProtocol: AnyObject {
    // MARK: - Connect

    func connect(completionBlock: ((Result<Bool, Error>) -> ())?)
    func connectSync() -> Result<Bool, Error>


    // MARK: - Disconnect

    func disconnect()


    // MARK: - Execute

    @discardableResult
    func execute(request: Request) async throws -> QueryResult

    @discardableResult
    func executeCypher(_ query: String, params: [String: PackProtocol]) async throws -> QueryResult

    func executeAsTransaction(
        mode: Request.TransactionMode,
        bookmark: String?,
        transactionBlock: @escaping (_ tx: Transaction) throws -> (),
        transactionCompleteBlock: ((Bool) -> ())?
    ) throws


    // MARK: - Reset

    func reset() async throws


    // MARK: - Other

    func rollback(transaction: Transaction) async throws
    func pullAll(partialQueryResult: QueryResult) async throws -> QueryResult
    func getBookmark() -> String?


    // MARK: - Create Node(s)

    @discardableResult
    func create(node: Node) async throws -> Node

    @discardableResult
    func create(nodes: [Node]) async throws -> [Node]


    // MARK: - Read Node(s)

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


    // MARK: - Read Relationship(s)

    func get(
        type: String,
        properties: [String: PackProtocol],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Relationship]


    // MARK: - Update Relationship(s)

    @discardableResult
    func update(relationship: Relationship) async throws -> Relationship


    // MARK: - Delete Relationship(s)

    func delete(relationship: Relationship) async throws
}
