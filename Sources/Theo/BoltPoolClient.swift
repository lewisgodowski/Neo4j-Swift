import Foundation
import PackStream
import Bolt

private class ClientInstanceWithProperties {
    let client: ClientProtocol
    var inUse: Bool
    
    init(client: ClientProtocol) {
        self.client = client
        self.inUse = false
    }
}

private struct InMemoryClientConfiguration: ClientConfigurationProtocol {
    let hostname: String
    let port: Int
    let username: String
    let password: String
    let encrypted: Bool
}

public class BoltPoolClient: ClientProtocol {
    // MARK:  - COnstants & Variables

    private var clients: [ClientInstanceWithProperties]
    private let clientSemaphore: DispatchSemaphore
    
    private let configuration: ClientConfigurationProtocol
    
    private var hostname: String { configuration.hostname }
    private var port: Int { configuration.port }
    private var username: String { configuration.username }
    private var password: String { configuration.password }
    private var encrypted: Bool { configuration.encrypted }


    // MARK: - init

    required public init(
        _ configuration: ClientConfigurationProtocol,
        poolSize: ClosedRange<UInt>
    ) throws {
        self.configuration = configuration
        self.clientSemaphore = DispatchSemaphore(value: Int(poolSize.upperBound))
        self.clients = try (0..<poolSize.lowerBound).map { _ in
            let client = try BoltClient(configuration)
            _ = client.connectSync()
            return ClientInstanceWithProperties(client: client)
        }
    }
    
    required public convenience init(
        hostname: String = "localhost",
        port: Int = 7687,
        username: String = "neo4j",
        password: String = "neo4j",
        encrypted: Bool = true,
        poolSize: ClosedRange<UInt>
    ) throws {
        let configuration = InMemoryClientConfiguration(
            hostname: hostname,
            port: port,
            username: username,
            password: password,
            encrypted: encrypted)
        try self.init(configuration, poolSize: poolSize)
    }
    
    private let clientsMutationSemaphore = DispatchSemaphore(value: 1)
    
    public func getClient() -> ClientProtocol {
        clientSemaphore.wait()
        clientsMutationSemaphore.wait()

        var client: ClientProtocol? = nil

        for (index, alt) in clients.enumerated() {
            guard !alt.inUse else { continue }

            alt.inUse = true
            client = alt.client
            clients[index] = alt
            break
        }
        
        if client == nil {
            let boltClient = try! BoltClient(configuration) // TODO: !!! !
            let clientWithProps = ClientInstanceWithProperties(client: boltClient)
            clientWithProps.inUse = true
            clients.append(clientWithProps)
            client = clientWithProps.client
        }
        
        clientsMutationSemaphore.signal()
        
        return client! // TODO: !!! !
    }
    
    public func release(_ client: ClientProtocol) {
        clientsMutationSemaphore.wait()

        for (index, alt) in clients.enumerated() {
            guard alt.client === client else { continue }
            alt.inUse = false
            clients[index] = alt
            break
        }

        clientsMutationSemaphore.signal()
        clientSemaphore.signal()
    }
}

extension BoltPoolClient {
    public func all() -> [ClientProtocol] {
        clients.map(\.client)
    }
}

extension BoltPoolClient {
    // MARK: - Connect

//    public func connect(completionBlock: ((Result<Bool, Error>) -> ())?) {
    public func connect() async throws {
        let client = getClient()
        defer { release(client) }
        try await client.connect()
    }
    
//    public func connectSync() -> Result<Bool, Error> {
    public func connect() throws {
        let client = getClient()
        defer { release(client) }
        try client.connect()
    }


    // MARK: - Disconnect
    
    public func disconnect() {
        let client = getClient()
        defer { release(client) }
        client.disconnect()
    }


    // MARK: - Execute

//    public func execute(request: Request, completionBlock: ((Result<(Bool, QueryResult), Error>) -> ())?) {
    public func execute(request: Request) async throws -> QueryResult {
        let client = getClient()
        defer { release(client) }
        return try await client.execute(request: request)
    }
    
//    public func executeWithResult(request: Request, completionBlock: ((Result<(Bool, QueryResult), Error>) -> ())?) {
//        let client = self.getClient()
//
//        defer { release(client) }
//        client.executeWithResult(request: request, completionBlock: completionBlock)
//    }
    
//    public func executeCypher(_ query: String, params: Dictionary<String, PackProtocol>?, completionBlock: ((Result<(Bool, QueryResult), Error>) -> ())?) {
    public func executeCypher(
        _ query: String,
        params: [String: PackProtocol]?
    ) async throws -> QueryResult {
        let client = getClient()
        defer { release(client) }
        return try await client.executeCypher(query, params: params)
    }
    
//    public func executeCypherWithResult(_ query: String, params: [String:PackProtocol] = [:], completionBlock: ((Result<(Bool, QueryResult), Error>) -> ())? = nil) {
//        let client = self.getClient()
//        client.executeCypherWithResult(query, params: params) { result in
//            self.release(client)
//            completionBlock?(result)
//        }
//    }
    
//    public func executeCypherSync(_ query: String, params: Dictionary<String, PackProtocol>?) -> (Result<QueryResult, Error>) {
    public func executeCypher(
        _ query: String,
        params: [String: PackProtocol]?
    ) throws -> QueryResult {
        let client = getClient()
        defer { release(client) }
        return try client.executeCypher(query, params: params)
    }
    
    public func executeAsTransaction(
        mode: Request.TransactionMode = .readonly,
        bookmark: String?,
        transactionBlock: @escaping (Transaction) throws -> (),
        transactionCompleteBlock: ((Bool) -> ())? = nil
    ) throws {
        let client = getClient()
        defer { release(client) }
        try client.executeAsTransaction(
            mode: mode,
            bookmark: bookmark,
            transactionBlock: transactionBlock,
            transactionCompleteBlock: transactionCompleteBlock
        )
    }


    // MARK: - Reset

//    public func reset(completionBlock: (() -> ())?) throws {
    public func reset() async throws {
        let client = getClient() // TODO: How can we ensure we get the old client
        defer { release(client) }
        try await client.reset()
    }
    public func reset() throws {
        let client = getClient() // TODO: How can we ensure we get the old client
        defer { release(client) }
        try client.reset()
    }


    // MARK: - Other
    
//    public func rollback(transaction: Transaction, rollbackCompleteBlock: (() -> ())?) throws {
    public func rollback(transaction: Transaction) async throws {
        let client = getClient() // TODO: How can we ensure we get the same client that is currently processing that transaction?
        defer { release(client) }
        return try await client.rollback(transaction: transaction)
    }
    
//    public func pullAll(partialQueryResult: QueryResult, completionBlock: ((Result<(Bool, QueryResult), Error>) -> ())?) {
    public func pullAll(partialQueryResult: QueryResult) async throws -> QueryResult {
        let client = getClient()
        defer { release(client) }
        return try await client.pullAll(partialQueryResult: partialQueryResult)
    }

    public func pullSynchronouslyAndIgnore() {
        let client = getClient()
        defer { release(client) }
        client.pullSynchronouslyAndIgnore()
    }
    
    public func getBookmark() -> String? {
        let client = getClient()
        defer { release(client) }
        return client.getBookmark()
    }


    // MARK: - Perform Request

//    public func performRequestWithNoReturnNode(request: Request, completionBlock: ((Result<Bool, Error>) -> ())?) {
    public func performNodeRequest(request: Request) async throws {
        let client = getClient()
        defer { release(client) }
        try await client.performNodeRequest(request: request)
    }

//    public func performRequestWithNoReturnRelationship(request: Request, completionBlock: ((Result<Bool, Error>) -> ())?) {
    public func performRelationshipRequest(request: Request) async throws {
        let client = getClient()
        defer { release(client) }
        try await client.performRelationshipRequest(request: request)
    }


    // MARK: - Create Node(s)

//    public func createAndReturnNode(node: Node, completionBlock: ((Result<Node, Error>) -> ())?) {
//        let client = self.getClient()
//        defer { release(client) }
//        client.createAndReturnNode(node: node, completionBlock: completionBlock)
//    }
    
//    public func createAndReturnNodeSync(node: Node) -> Result<Node, Error> {
//        let client = getClient()
//        defer { release(client) }
//        return client.createAndReturnNodeSync(node: node)
//    }

    @discardableResult
    public func createNode(node: Node) async throws -> Node {
        let client = getClient()
        defer { release(client) }
        return try await client.createNode(node: node)
    }

//    public func createNodeSync(node: Node) -> Result<Bool, Error> {
    @discardableResult
    public func createNode(node: Node) throws -> Node {
        let client = getClient()
        defer { release(client) }
        return try client.createNode(node: node)
    }
    
//    public func createAndReturnNodes(nodes: [Node], completionBlock: ((Result<[Node], Error>) -> ())?) {
//        let client = getClient()
//        defer { release(client) }
//        client.createAndReturnNodes(nodes: nodes, completionBlock: completionBlock)
//    }
    
//    public func createAndReturnNodesSync(nodes: [Node]) -> Result<[Node], Error> {
//        let client = self.getClient()
//        defer { release(client) }
//        let res = client.createAndReturnNodesSync(nodes: nodes)
//        return res
//    }
    
//    public func createNodes(nodes: [Node], completionBlock: ((Result<Bool, Error>) -> ())?) {
    @discardableResult
    public func createNodes(nodes: [Node]) async throws -> [Node] {
        let client = getClient()
        defer { release(client) }
        return try await client.createNodes(nodes: nodes)
    }
    
//    public func createNodesSync(nodes: [Node]) -> Result<Bool, Error> {
    @discardableResult
    public func createNodes(nodes: [Node]) throws -> [Node] {
        let client = getClient()
        defer { release(client) }
        return try client.createNodes(nodes: nodes)
    }


    // MARK: - Read Node(s)

//    public func nodeBy(id: UInt64, completionBlock: ((Result<Node?, Error>) -> ())?) {
    public func nodeBy(id: UInt64) async throws -> Node? {
        let client = getClient()
        defer { release(client) }
        return try await client.nodeBy(id: id)
    }

//    public func nodesWith(labels: [String], andProperties properties: [String : PackProtocol], skip: UInt64, limit: UInt64, completionBlock: ((Result<[Node], Error>) -> ())?) {
    public func nodesWith(
        labels: [String],
        andProperties properties: [String: PackProtocol],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Node] {
        let client = getClient()
        defer { release(client) }
        return try await client.nodesWith(
            labels: labels,
            andProperties: properties,
            skip: skip,
            limit: limit
        )
    }

//    public func nodesWith(properties: [String : PackProtocol], skip: UInt64, limit: UInt64, completionBlock: ((Result<[Node], Error>) -> ())?) {
    public func nodesWith(
        properties: [String: PackProtocol],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Node] {
        let client = getClient()
        defer { release(client) }
        return try await client.nodesWith(properties: properties, skip: skip, limit: limit)
    }

//    public func nodesWith(label: String, andProperties properties: [String : PackProtocol], skip: UInt64, limit: UInt64, completionBlock: ((Result<[Node], Error>) -> ())?) {
    public func nodesWith(
        label: String,
        andProperties properties: [String: PackProtocol],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Node] {
        let client = getClient()
        defer { release(client) }
        return try await client.nodesWith(
            label: label,
            andProperties: properties,
            skip: skip,
            limit: limit
        )
    }


    // MARK: - Update Node(s)

//    public func updateAndReturnNode(node: Node, completionBlock: ((Result<Node, Error>) -> ())?) {
//        let client = self.getClient()
//        defer { release(client) }
//        client.updateAndReturnNode(node: node, completionBlock: completionBlock)
//    }
    
//    public func updateAndReturnNodeSync(node: Node) -> Result<Node, Error> {
//        let client = self.getClient()
//        defer { release(client) }
//        return client.updateAndReturnNodeSync(node: node)
//    }
    
//    public func updateNode(node: Node, completionBlock: ((Result<Bool, Error>) -> ())?) {
    @discardableResult
    public func updateNode(node: Node) async throws -> Node {
        let client = getClient()
        defer { release(client) }
        return try await client.updateNode(node: node)
    }

//    public func updateNodeSync(node: Node) -> Result<Bool, Error> {
    @discardableResult
    public func updateNode(node: Node) throws -> Node {
        let client = getClient()
        defer { release(client) }
        return try client.updateNode(node: node)
    }
    
//    public func updateAndReturnNodes(nodes: [Node], completionBlock: ((Result<[Node], Error>) -> ())?) {
//        let client = self.getClient()
//        defer { release(client) }
//        client.updateAndReturnNodes(nodes: nodes, completionBlock: completionBlock)
//    }
    
//    public func updateAndReturnNodesSync(nodes: [Node]) -> Result<[Node], Error> {
//        let client = self.getClient()
//        defer { release(client) }
//        return client.updateAndReturnNodesSync(nodes: nodes)
//    }
    
//    public func updateNodes(nodes: [Node], completionBlock: ((Result<Bool, Error>) -> ())?) {
    @discardableResult
    public func updateNodes(nodes: [Node]) async throws -> [Node] {
        let client = getClient()
        defer { release(client) }
        return try await client.updateNodes(nodes: nodes)
    }
    
//    public func updateNodesSync(nodes: [Node]) -> Result<Bool, Error> {
    @discardableResult
    public func updateNodes(nodes: [Node]) throws -> [Node] {
        let client = getClient()
        defer { release(client) }
        return try client.updateNodes(nodes: nodes)
    }


    // MARK: - Delete Node(s)
    
//    public func deleteNode(node: Node, completionBlock: ((Result<Bool, Error>) -> ())?) {
    public func deleteNode(node: Node) async throws {
        let client = getClient()
        defer { release(client) }
        try await client.deleteNode(node: node)
    }
    
//    public func deleteNodeSync(node: Node) -> Result<Bool, Error> {
    public func deleteNode(node: Node) throws {
        let client = getClient()
        defer { release(client) }
        try client.deleteNode(node: node)
    }
    
//    public func deleteNodes(nodes: [Node], completionBlock: ((Result<Bool, Error>) -> ())?) {
    public func deleteNodes(nodes: [Node]) async throws {
        let client = getClient()
        defer { release(client) }
        try await client.deleteNodes(nodes: nodes)
    }
    
//    public func deleteNodesSync(nodes: [Node]) -> Result<Bool, Error> {
    public func deleteNodes(nodes: [Node]) throws {
        let client = getClient()
        defer { release(client) }
        try client.deleteNodes(nodes: nodes)
    }


    // MARK: - Relate Nodes

//    public func relate(node: Node, to: Node, type: String, properties: [String : PackProtocol], completionBlock: ((Result<Relationship, Error>) -> ())?) {
    public func relate(
        node: Node,
        to: Node,
        type: String,
        properties: [String: PackProtocol]
    ) async throws -> Relationship {
        let client = getClient()
        defer { release(client) }
        return try await client.relate(node: node, to: to, type: type, properties: properties)
    }
    
//    public func relateSync(node: Node, to: Node, type: String, properties: [String : PackProtocol]) -> Result<Relationship, Error> {
    public func relate(
        node: Node,
        to: Node,
        type: String,
        properties: [String: PackProtocol]
    ) throws -> Relationship {
        let client = getClient()
        defer { release(client) }
        return try client.relate(node: node, to: to, type: type, properties: properties)
    }


    // MARK: - Create Relationship(s)

//    public func createAndReturnRelationship(relationship: Relationship, completionBlock: ((Result<Relationship, Error>) -> ())?) {
    public func createRelationship(relationship: Relationship) async throws -> Relationship {
        let client = getClient()
        defer { release(client) }
        return try await client.createRelationship(relationship: relationship)
    }

//    func createAndReturnRelationshipSync(relationship: Relationship) -> Result<Relationship, Error>
    public func createRelationship(relationship: Relationship) throws -> Relationship {
        let client = getClient()
        defer { release(client) }
        return try client.createRelationship(relationship: relationship)
    }

//    public func createAndReturnRelationships(relationships: [Relationship], completionBlock: ((Result<[Relationship], Error>) -> ())?) {
    public func createRelationships(relationships: [Relationship]) async throws -> [Relationship] {
        let client = getClient()
        defer { release(client) }
        return try await client.createRelationships(relationships: relationships)
    }

//    public func createAndReturnRelationshipsSync(relationships: [Relationship]) -> Result<[Relationship], Error> {
    public func createRelationships(relationships: [Relationship]) throws -> [Relationship] {
        let client = getClient()
        defer { release(client) }
        return try client.createRelationships(relationships: relationships)
    }


    // MARK: - Read Relationship(s)

//    public func relationshipsWith(type: String, andProperties properties: [String : PackProtocol], skip: UInt64, limit: UInt64, completionBlock: ((Result<[Relationship], Error>) -> ())?) {
    public func relationshipsWith(
        type: String,
        andProperties properties: [String: PackProtocol],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Relationship] {
        let client = getClient()
        defer { release(client) }
        return try await client.relationshipsWith(
            type: type,
            andProperties: properties,
            skip: skip,
            limit: limit
        )
    }


    // MARK: - Update Relationship(s)

//    public func updateAndReturnRelationship(relationship: Relationship, completionBlock: ((Result<Relationship, Error>) -> ())?) {
//        let client = self.getClient()
//        defer { release(client) }
//        client.updateAndReturnRelationship(relationship: relationship, completionBlock: completionBlock)
//    }
    
//    public func updateAndReturnRelationshipSync(relationship: Relationship) -> Result<Relationship, Error> {
//        let client = self.getClient()
//        defer { release(client) }
//        return client.updateAndReturnRelationshipSync(relationship: relationship)
//    }
    
//    public func updateRelationship(relationship: Relationship, completionBlock: ((Result<Bool, Error>) -> ())?) {
    @discardableResult
    public func updateRelationship(relationship: Relationship) async throws -> Relationship {
        let client = getClient()
        defer { release(client) }
        return try await client.updateRelationship(relationship: relationship)
    }

//    public func updateRelationshipSync(relationship: Relationship) -> Result<Bool, Error> {
    @discardableResult
    public func updateRelationship(relationship: Relationship) throws -> Relationship {
        let client = getClient()
        defer { release(client) }
        return try client.updateRelationship(relationship: relationship)
    }


    // MARK: - Delete Relationship(s)
    
//    public func deleteRelationship(relationship: Relationship, completionBlock: ((Result<Bool, Error>) -> ())?) {
    public func deleteRelationship(relationship: Relationship) async throws {
        let client = getClient()
        defer { release(client) }
        try await client.deleteRelationship(relationship: relationship)
    }
    
//    public func deleteRelationshipSync(relationship: Relationship) -> Result<Bool, Error> {
    public func deleteRelationship(relationship: Relationship) throws {
        let client = getClient()
        defer { release(client) }
        try client.deleteRelationship(relationship: relationship)
    }
}
