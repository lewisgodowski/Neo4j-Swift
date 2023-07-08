import Foundation
import Bolt
import PackStream

public protocol ClientProtocol: AnyObject {
    // MARK: - Connect

//    func connect(completionBlock: ((Result<Bool, Error>) -> ())?)
    func connect() async throws

//    func connectSync() -> Result<Bool, Error>
    func connect() throws


    // MARK: - Disconnect

    func disconnect()


    // MARK: - Execute

//    func executeWithResult(request: Request, completionBlock: ((Result<(Bool, QueryResult), Error>) -> ())?)
//    func executeCypherWithResult(_ query: String, params: [String:PackProtocol], completionBlock: ((Result<(Bool, QueryResult), Error>) -> ())?)

//    func execute(request: Request, completionBlock: ((Result<(Bool, QueryResult), Error>) -> ())?)
    @discardableResult
    func execute(request: Request) async throws -> QueryResult

//    func executeCypher(_ query: String, params: Dictionary<String,PackProtocol>?, completionBlock: ((Result<(Bool, QueryResult), Error>) -> ())?)
    @discardableResult
    func executeCypher(_ query: String, params: [String: PackProtocol]?) async throws -> QueryResult

//    func executeCypherSync(_ query: String, params: Dictionary<String,PackProtocol>?) -> (Result<QueryResult, Error>)
    func executeCypher(_ query: String, params: [String: PackProtocol]?) throws -> QueryResult

    func executeAsTransaction(mode: Request.TransactionMode, bookmark: String?, transactionBlock: @escaping (_ tx: Transaction) throws -> (), transactionCompleteBlock: ((Bool) -> ())?) throws


    // MARK: - Reset

//    func reset(completionBlock: (() -> ())?) throws
    func reset() async throws

    func reset() throws


    // MARK: - Other

//    func rollback(transaction: Transaction, rollbackCompleteBlock: (() -> ())?) throws
    func rollback(transaction: Transaction) async throws

//    func pullAll(partialQueryResult: QueryResult, completionBlock: ((Result<(Bool, QueryResult), Error>) -> ())?)
    func pullAll(partialQueryResult: QueryResult) async throws -> QueryResult

    func pullSynchronouslyAndIgnore()

    func getBookmark() -> String?


    // MARK: - Perform Request

//    func performRequestWithNoReturnNode(request: Request, completionBlock: ((Result<Bool, Error>) -> ())?)
    func performNodeRequest(request: Request) async throws

//    func performRequestWithNoReturnRelationship(request: Request, completionBlock: ((Result<Bool, Error>) -> ())?)
    func performRelationshipRequest(request: Request) async throws


    // MARK: - Create Node(s)

//    func createAndReturnNode(node: Node, completionBlock: ((Result<Node, Error>) -> ())?)
//    func createAndReturnNodeSync(node: Node) -> Result<Node, Error>

//    func createNode(node: Node, completionBlock: ((Result<Bool, Error>) -> ())?)
    @discardableResult
    func createNode(node: Node) async throws -> Node

//    func createNodeSync(node: Node) -> Result<Bool, Error>
    @discardableResult
    func createNode(node: Node) throws -> Node

//    func createAndReturnNodes(nodes: [Node], completionBlock: ((Result<[Node], Error>) -> ())?)
//    func createAndReturnNodesSync(nodes: [Node]) -> Result<[Node], Error>

//    func createNodes(nodes: [Node], completionBlock: ((Result<Bool, Error>) -> ())?)
    @discardableResult
    func createNodes(nodes: [Node]) async throws -> [Node]

//    func createNodesSync(nodes: [Node]) -> Result<Bool, Error>
    @discardableResult
    func createNodes(nodes: [Node]) throws -> [Node]


    // MARK: - Read Node(s)

//    func nodeBy(id: UInt64, completionBlock: ((Result<Node?, Error>) -> ())?)
    func nodeBy(id: UInt64) async throws -> Node?

//    func nodesWith(labels: [String], andProperties properties: [String:PackProtocol], skip: UInt64, limit: UInt64, completionBlock: ((Result<[Node], Error>) -> ())?)
    func nodesWith(
        labels: [String],
        andProperties properties: [String: PackProtocol],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Node]

//    func nodesWith(properties: [String:PackProtocol], skip: UInt64, limit: UInt64, completionBlock: ((Result<[Node], Error>) -> ())?)
    func nodesWith(
        properties: [String: PackProtocol],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Node]

//    func nodesWith(label: String, andProperties properties: [String:PackProtocol], skip: UInt64, limit: UInt64, completionBlock: ((Result<[Node], Error>) -> ())?)
    func nodesWith(
        label: String,
        andProperties properties: [String: PackProtocol],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Node]


    // MARK: - Update Node(s)

//    func updateAndReturnNode(node: Node, completionBlock: ((Result<Node, Error>) -> ())?)
//    func updateAndReturnNodeSync(node: Node) -> Result<Node, Error>

//    func updateNode(node: Node, completionBlock: ((Result<Bool, Error>) -> ())?)
    @discardableResult
    func updateNode(node: Node) async throws -> Node

//    func updateNodeSync(node: Node) -> Result<Bool, Error>
    @discardableResult
    func updateNode(node: Node) throws -> Node

//    func updateAndReturnNodes(nodes: [Node], completionBlock: ((Result<[Node], Error>) -> ())?)
//    func updateAndReturnNodesSync(nodes: [Node]) -> Result<[Node], Error>

//    func updateNodes(nodes: [Node], completionBlock: ((Result<Bool, Error>) -> ())?)
    @discardableResult
    func updateNodes(nodes: [Node]) async throws -> [Node]

//    func updateNodesSync(nodes: [Node]) -> Result<Bool, Error>
    @discardableResult
    func updateNodes(nodes: [Node]) throws -> [Node]


    // MARK: - Delete Node(s)

//    func deleteNode(node: Node, completionBlock: ((Result<Bool, Error>) -> ())?)
    func deleteNode(node: Node) async throws

//    func deleteNodeSync(node: Node) -> Result<Bool, Error>
    func deleteNode(node: Node) throws

//    func deleteNodes(nodes: [Node], completionBlock: ((Result<Bool, Error>) -> ())?)
    func deleteNodes(nodes: [Node]) async throws

//    func deleteNodesSync(nodes: [Node]) -> Result<Bool, Error>
    func deleteNodes(nodes: [Node]) throws


    // MARK: - Relate Nodes

//    func relate(node: Node, to: Node, type: String, properties: [String:PackProtocol], completionBlock: ((Result<Relationship, Error>) -> ())?)
    func relate(
        node: Node,
        to: Node,
        type: String,
        properties: [String: PackProtocol]
    ) async throws -> Relationship

//    func relateSync(node: Node, to: Node, type: String, properties: [String:PackProtocol]) -> Result<Relationship, Error>
    func relate(
        node: Node,
        to: Node,
        type: String,
        properties: [String: PackProtocol]
    ) throws -> Relationship


    // MARK: - Create Relationship(s)

//    func createAndReturnRelationship(relationship: Relationship, completionBlock: ((Result<Relationship, Error>) -> ())?)
    func createRelationship(relationship: Relationship) async throws -> Relationship

//    func createAndReturnRelationshipSync(relationship: Relationship) -> Result<Relationship, Error>
    func createRelationship(relationship: Relationship) throws -> Relationship

//    func createAndReturnRelationships(relationships: [Relationship], completionBlock: ((Result<[Relationship], Error>) -> ())?)
    func createRelationships(relationships: [Relationship]) async throws -> [Relationship]

//    func createAndReturnRelationshipsSync(relationships: [Relationship]) -> Result<[Relationship], Error>
    func createRelationships(relationships: [Relationship]) throws -> [Relationship]


    // MARK: - Read Relationship(s)

//    func relationshipsWith(type: String, andProperties properties: [String:PackProtocol], skip: UInt64, limit: UInt64, completionBlock: ((Result<[Relationship], Error>) -> ())?)
    func relationshipsWith(
        type: String,
        andProperties properties: [String: PackProtocol],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Relationship]


    // MARK: - Update Relationship(s)

//    func updateRelationship(relationship: Relationship, completionBlock: ((Result<Bool, Error>) -> ())?)
//    func updateRelationshipSync(relationship: Relationship) -> Result<Bool, Error>

//    func updateAndReturnRelationship(relationship: Relationship, completionBlock: ((Result<Relationship, Error>) -> ())?)
    @discardableResult
    func updateRelationship(relationship: Relationship) async throws -> Relationship

//    func updateAndReturnRelationshipSync(relationship: Relationship) -> Result<Relationship, Error>
    @discardableResult
    func updateRelationship(relationship: Relationship) throws -> Relationship


    // MARK: - Delete Relationship(s)

//    func deleteRelationship(relationship: Relationship, completionBlock: ((Result<Bool, Error>) -> ())?)
    func deleteRelationship(relationship: Relationship) async throws

//    func deleteRelationshipSync(relationship: Relationship) -> Result<Bool, Error>
    func deleteRelationship(relationship: Relationship) throws
}
