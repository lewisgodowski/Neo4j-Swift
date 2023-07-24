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
    // MARK:  - Constants & Variables

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
    ) async throws {
        self.configuration = configuration
        self.clientSemaphore = DispatchSemaphore(value: Int(poolSize.upperBound))
        self.clients = []
        for _ in 0..<poolSize.lowerBound {
            let client = try BoltClient(configuration)
            try await client.connect()
            self.clients.append(ClientInstanceWithProperties(client: client))
        }
    }
    
    required public convenience init(
        hostname: String = "localhost",
        port: Int = 7687,
        username: String = "neo4j",
        password: String = "neo4j",
        encrypted: Bool = true,
        poolSize: ClosedRange<UInt>
    ) async throws {
        let configuration = InMemoryClientConfiguration(
            hostname: hostname,
            port: port,
            username: username,
            password: password,
            encrypted: encrypted)
        try await self.init(configuration, poolSize: poolSize)
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
    // MARK: - Connect/Disconnect

    public func connect() async throws {
        let client = getClient()
        defer { release(client) }
        try await client.connect()
    }

    public func disconnect() {
        let client = getClient()
        defer { release(client) }
        client.disconnect()
    }


    // MARK: - Execute

    public func execute(request: Request) async throws -> QueryResult {
        let client = getClient()
        defer { release(client) }
        return try await client.execute(request: request)
    }
    
    public func executeCypher(
        _ query: String,
        params: [String: PackProtocol] = [:]
    ) async throws -> QueryResult {
        let client = getClient()
        defer { release(client) }
        return try await client.executeCypher(query, params: params)
    }
    
    public func executeAsTransaction(
        mode: Request.TransactionMode = .readonly,
        operations: @escaping (_ transaction: Transaction) async throws -> ()
    ) async throws {
        let client = getClient()
        defer { release(client) }
        try await client.executeAsTransaction(mode: mode, operations: operations)
    }


    // MARK: - Reset

    public func reset() async throws {
        let client = getClient() // TODO: How can we ensure we get the old client
        defer { release(client) }
        try await client.reset()
    }


    // MARK: - Other
    
    public func pullAll(partialQueryResult: QueryResult) async throws -> QueryResult {
        let client = getClient()
        defer { release(client) }
        return try await client.pullAll(partialQueryResult: partialQueryResult)
    }


    // MARK: - Create Node(s)

    @discardableResult
    public func create(node: Node) async throws -> Node {
        let client = getClient()
        defer { release(client) }
        return try await client.create(node: node)
    }

    @discardableResult
    public func create(nodes: [Node]) async throws -> [Node] {
        let client = getClient()
        defer { release(client) }
        return try await client.create(nodes: nodes)
    }


    // MARK: - Read Node(s)

    public func get(nodeID: UInt64) async throws -> Node? {
        let client = getClient()
        defer { release(client) }
        return try await client.get(nodeID: nodeID)
    }

    public func get(customNodeID: NodeID) async throws -> Node? {
        let client = getClient()
        defer { release(client) }
        return try await client.get(customNodeID: customNodeID)
    }

    public func get(
        labels: [String] = [],
        properties: [String: PackProtocol] = [:],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Node] {
        let client = getClient()
        defer { release(client) }
        return try await client.get(
            labels: labels,
            properties: properties,
            skip: skip,
            limit: limit
        )
    }


    // MARK: - Update Node(s)

    @discardableResult
    public func update(node: Node) async throws -> Node {
        let client = getClient()
        defer { release(client) }
        return try await client.update(node: node)
    }

    @discardableResult
    public func update(nodes: [Node]) async throws -> [Node] {
        let client = getClient()
        defer { release(client) }
        return try await client.update(nodes: nodes)
    }


    // MARK: - Delete Node(s)
    
    public func delete(node: Node) async throws {
        let client = getClient()
        defer { release(client) }
        try await client.delete(node: node)
    }
    
    public func delete(nodes: [Node]) async throws {
        let client = getClient()
        defer { release(client) }
        try await client.delete(nodes: nodes)
    }


    // MARK: - Relate Nodes

    public func relate(
        node: Node,
        to: Node,
        type: String,
        properties: [String: PackProtocol] = [:]
    ) async throws -> Relationship {
        let client = getClient()
        defer { release(client) }
        return try await client.relate(node: node, to: to, type: type, properties: properties)
    }


    // MARK: - Create Relationship(s)

    @discardableResult
    public func create(relationship: Relationship) async throws -> Relationship {
        let client = getClient()
        defer { release(client) }
        return try await client.create(relationship: relationship)
    }

    @discardableResult
    public func create(relationships: [Relationship]) async throws -> [Relationship] {
        let client = getClient()
        defer { release(client) }
        return try await client.create(relationships: relationships)
    }


    // MARK: - Read Relationship(s)

    public func get(
        type: String,
        properties: [String: PackProtocol] = [:],
        skip: UInt64,
        limit: UInt64
    ) async throws -> [Relationship] {
        let client = getClient()
        defer { release(client) }
        return try await client.get(
            type: type,
            properties: properties,
            skip: skip,
            limit: limit
        )
    }


    // MARK: - Update Relationship(s)

    @discardableResult
    public func update(relationship: Relationship) async throws -> Relationship {
        let client = getClient()
        defer { release(client) }
        return try await client.update(relationship: relationship)
    }

    @discardableResult
    public func update(relationships: [Relationship]) async throws -> [Relationship] {
        let client = getClient()
        defer { release(client) }
        return try await client.update(relationships: relationships)
    }


    // MARK: - Delete Relationship(s)

    public func delete(relationship: Relationship) async throws {
        let client = getClient()
        defer { release(client) }
        try await client.delete(relationship: relationship)
    }

    public func delete(relationships: [Relationship]) async throws {
        let client = getClient()
        defer { release(client) }
        try await client.delete(relationships: relationships)
    }
}
