import Foundation
import PackStream
import Bolt
import NIO

#if os(Linux)
import Dispatch
#endif

typealias BoltRequest = Bolt.Request

open class BoltClient: ClientProtocol {
    // MARK: - Enums

    public enum BoltClientError: Error {
        case missingNodeResponse
        case missingRelationshipResponse
        case queryUnsuccessful
        case unexpectedNumberOfResponses
        case fetchingRecordsUnsuccessful
        case couldNotCreateRelationship
        case unknownError
    }


    // MARK: - Constants & Variables

    private let hostname: String
    private let port: Int
    private let username: String
    private let password: String
    private let encrypted: Bool
    private let connection: Connection

    private var currentTransaction: Transaction?


    // MARK: - init

    required public init(_ configuration: ClientConfigurationProtocol) throws {
        self.hostname = configuration.hostname
        self.port = configuration.port
        self.username = configuration.username
        self.password = configuration.password
        self.encrypted = configuration.encrypted

        let socket = try EncryptedSocket(hostname: hostname, port: port)
        socket.certificateValidator = UnsecureCertificateValidator(
            hostname: hostname,
            port: UInt(port)
        )
        self.connection = Connection(
            socket: socket,
            settings: ConnectionSettings(
                username: username,
                password: password,
                userAgent: "Theo 5.2.0"
            )
        )
    }

    required public init(
        hostname: String = "localhost",
        port: Int = 7687,
        username: String = "neo4j",
        password: String = "neo4j",
        encrypted: Bool = true
    ) throws {
        self.hostname = hostname
        self.port = port
        self.username = username
        self.password = password
        self.encrypted = encrypted

        let socket = try EncryptedSocket(hostname: hostname, port: port)
        socket.certificateValidator = UnsecureCertificateValidator(
            hostname: hostname,
            port: UInt(port)
        )
        self.connection = Connection(
            socket: socket,
            settings: ConnectionSettings(
                username: username,
                password: password,
                userAgent: "Theo 5.2.0"
            )
        )
    }


    // MARK: - Connect/Disconnect

    /**
     Connects to Neo4j given the connection settings BoltClient was initialized with.

     Asynchronous, so the function returns straight away. It is not defined what thread the completionblock will run on,
     so if you need it to run on main thread or another thread, make sure to dispatch to this that thread
     */
    public func connect() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) -> Void in
            do {
                try connection.connect { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /**
     Disconnects from Neo4j.
     */
    public func disconnect() {
        connection.disconnect()
    }


    // MARK: - Execute

    /**
     Executes a given request on Neo4j, and pulls the response data

     Requires an established connection

     Asynchronous, so the function returns straight away. It is not defined what thread the completionblock will run on,
     so if you need it to run on main thread or another thread, make sure to dispatch to this that thread

     - warning: This function should only be used with requests that expect data to be pulled after they run. Other requests can make Neo4j disconnect with a failure when it is subsequent asked for the result data

     - parameter request: The Bolt Request that will be sent to Neo4j
     - parameter completionBlock: Completion result-block that provides a complete QueryResult, or an Error to explain what went wrong
     */
    @discardableResult
    public func execute(request: Request) async throws -> QueryResult {
        guard let responses = try await connection.request(request)?.get() else {
            throw BoltClientError.unknownError
        }
        return try await pullAll(partialQueryResult: parseResponses(responses: responses))
    }

    /**
     Executes a given query on Neo4j, and pulls the response data

     Requires an established connection

     Asynchronous, so the function returns straight away. It is not defined what thread the completionblock will run on,
     so if you need it to run on main thread or another thread, make sure to dispatch to this that thread

     - warning: This function should only be used with requests that expect data to be pulled after they run. Other requests can make Neo4j disconnect with a failure when it is subsequent asked for the result data

     - parameter query: The query that will be sent to Neo4j
     - parameter params: The parameters that go with the query
     - parameter completionBlock: Completion result-block that provides a complete QueryResult, or an Error to explain what went wrong
     */
    @discardableResult
    public func executeCypher(
        _ query: String,
        params: [String: PackProtocol] = [:]
    ) async throws -> QueryResult {
        try await execute(
            request: Bolt.Request.run(statement: query, parameters: Map(dictionary: params))
        )
    }

    /**
     Executes a given block, usually containing multiple cypher queries run and results processed, as a transaction

     Requires an established connection

     Synchronous, so the function will return only when the query result is ready

     - parameter transactionBlock: The block of queries and result processing that make up the transaction. The Transaction object is available to it, so that it can mark it as failed, disable autocommit (on by default), or, after the transaction has been completed, get the transaction bookmark.
     */
    public func executeAsTransaction(
        mode: Request.TransactionMode = .readonly,
        operations: @escaping (_ transaction: Transaction) async throws -> ()
    ) async throws {
        let transaction = Transaction()
        transaction.commitBlock = { [weak self] succeed in
            if succeed {
                do {
                    guard try await self?.connection.request(BoltRequest.commit()) != nil else {
                        throw BoltClientError.unknownError
                    }
                    self?.currentTransaction = nil
//                    completionHandler?(true)
                } catch {
                    throw BoltClientError.queryUnsuccessful
                }
            } else {
                do {
                    guard try await self?.connection.request(BoltRequest.rollback()) != nil else {
                        throw BoltClientError.unknownError
                    }
                    self?.currentTransaction = nil
//                    completionHandler?(false)
                } catch {
//                    completionHandler?(false)
                }
            }
        }

        currentTransaction = transaction

        do {
            guard try await connection.request(BoltRequest.begin(mode: mode)) != nil else {
                throw BoltClientError.unknownError
            }
        } catch {
            transaction.commitBlock = { _ in }
        }

        try? await operations(transaction)
        if transaction.autocommit {
            try? await transaction.commitBlock(transaction.succeed)
            transaction.commitBlock = { _ in }
        }
    }

    private func parseResponses(responses: [Response], result: QueryResult = QueryResult()) -> QueryResult {
        let fields = (responses.flatMap { $0.items } .compactMap { ($0 as? Map)?.dictionary["fields"] }.first as? List)?.items.compactMap { $0 as? String }
        if let fields = fields {
            result.fields = fields
        }

        let stats = responses.flatMap { $0.items.compactMap { $0 as? Map }.compactMap { QueryStats(data: $0) } }.first
        if let stats = stats {
            result.stats = stats
        }

        if let resultAvailableAfter = (responses.flatMap { $0.items } .compactMap { ($0 as? Map)?.dictionary["result_available_after"] }.first?.uintValue()) {
            result.stats.resultAvailableAfter = resultAvailableAfter
        }

        if let resultConsumedAfter = (responses.flatMap { $0.items } .compactMap { $0 as? Map }.first?.dictionary["result_consumed_after"]?.uintValue()) {
            result.stats.resultConsumedAfter = resultConsumedAfter
        }

        if let type = (responses.flatMap { $0.items } .compactMap { $0 as? Map }.first?.dictionary["type"] as? String) {
            result.stats.type = type
        }



        let candidateList = responses.flatMap { $0.items.compactMap { ($0 as? List)?.items } }.reduce( [], +)
        var nodes = [UInt64:Node]()
        var relationships = [UInt64:Relationship]()
        var paths = [Path]()
        var rows = [[String:ResponseItem]]()
        var row = [String:ResponseItem]()

        for i in 0..<candidateList.count {
            if result.fields.count > 0, // there must be a field
               i > 0, // skip the first, because the  first row is already set
               i % result.fields.count == 0 { // then we need to break into the next row
                rows.append(row)
                row = [String:ResponseItem]()
            }

            let field = result.fields.count > 0 ? result.fields[i % result.fields.count] : nil
            let candidate = candidateList[i]

            if let node = Node(data: candidate) {
                if let nodeId = node.id {
                    nodes[nodeId] = node
                }

                if let field = field {
                    row[field] = node
                }
            }

            else if let relationship = Relationship(data: candidate) {
                if let relationshipId = relationship.id {
                    relationships[relationshipId] = relationship
                }

                if let field = field {
                    row[field] = relationship
                }
            }

            else if let path = Path(data: candidate) {
                paths.append(path)

                if let field = field {
                    row[field] = path
                }
            }

            else if let record = candidate.uintValue() {
                if let field = field {
                    row[field] = record
                }
            }

            else if let record = candidate.intValue() {
                if let field = field {
                    row[field] = record
                }
            }

            else if let record = candidate as? ResponseItem {
                if let field = field {
                    row[field] = record
                }
            }

            else {
                let record = Record(entry: candidate)
                if let field = field {
                    row[field] = record
                }
            }
        }

        if row.count > 0 {
            rows.append(row)
        }

        result.nodes.merge(nodes) { (n, _) -> Node in return n }

        let mapper: (UInt64, Relationship) -> (UInt64, Relationship)? = { (key: UInt64, rel: Relationship) in
            guard let fromNodeId = rel.fromNodeId, let toNodeId = rel.toNodeId else {
                print("Relationship was missing id in response. This is most unusual! Please report a bug!")
                return nil
            }
            rel.fromNode = nodes[fromNodeId]
            rel.toNode = nodes[toNodeId]
            return (key, rel)
        }

        let updatedRelationships = Dictionary(uniqueKeysWithValues: relationships.compactMap(mapper))
        result.relationships.merge(updatedRelationships) { (r, _) -> Relationship in return r }

        result.paths += paths
        result.rows += rows

        return result
    }


    // MARK: - Reset

    public func reset() async throws {
        guard try await connection.request(BoltRequest.reset())?.get() != nil else {
            throw BoltClientError.unknownError
        }
    }


    // MARK: - Other

    /**
     Pull all data, for use after executing a query that puts the Neo4j bolt server in streaming mode

     Requires an established connection

     Asynchronous, so the function returns straight away. It is not defined what thread the completionblock will run on,
     so if you need it to run on main thread or another thread, make sure to dispatch to this that thread

     - parameter partialQueryResult: If, for instance when executing the Cypher query, a partial QueryResult was given, pass it in here to have it fully populated in the completion result block
     - parameter completionBlock: Completion result-block that provides either a fully update QueryResult if a QueryResult was given, or a partial QueryResult if no prior QueryResult as given. If a failure has occurred, the Result contains an Error to explain what went wrong
     */
    @discardableResult
    public func pullAll(
        partialQueryResult: QueryResult = QueryResult()
    ) async throws -> QueryResult {
        guard let responses = try? await connection.request(BoltRequest.pullAll())?.get() else {
            throw BoltClientError.unknownError
        }
        return parseResponses(responses: responses, result: partialQueryResult)
    }


    // MARK: - Create Node(s)

    @discardableResult
    public func create(node: Node) async throws -> Node {
        let result = try await execute(request: node.createRequest())
        guard let (_, node) = result.nodes.first else { throw BoltClientError.missingNodeResponse }
        return node
    }

    @discardableResult
    public func create(nodes: [Node]) async throws -> [Node] {
        let result = try await execute(request: nodes.createRequest())
        return result.nodes.map { $0.value }
    }


    // MARK: - Get Node(s)

    public func get(nodeID: UInt64) async throws -> Node? {
        let result = try await executeCypher(
            "MATCH (n) WHERE id(n) = $id RETURN n",
            params: ["id": Int64(nodeID)]
        )
        guard result.nodes.count <= 1 else { throw BoltClientError.unexpectedNumberOfResponses }
        return result.nodes.map { $0.value }.first
    }

    public func get(customNodeID: NodeID) async throws -> Node? {
        let result = try await executeCypher(
            "MATCH (n) WHERE _id(n) = $id RETURN n",
            params: ["id": customNodeID.value]
        )
        guard result.nodes.count <= 1 else { throw BoltClientError.unexpectedNumberOfResponses }
        return result.nodes.map { $0.value }.first
    }

    public func get(
        labels: [String] = [],
        properties: [String: PackProtocol] = [:],
        skip: UInt64 = 0,
        limit: UInt64 = 25
    ) async throws -> [Node] {
        try await execute(
            request: Node.queryFor(
                labels: labels,
                andProperties: properties,
                skip: skip,
                limit: limit
            )
        ).nodes.map { $0.value }
    }


    // MARK: - Update Node(s)

    @discardableResult
    public func update(node: Node) async throws -> Node {
        let result = try await execute(request: node.updateRequest())
        guard let (_, node) = result.nodes.first else { throw BoltClientError.missingNodeResponse }
        return node
    }

    @discardableResult
    public func update(nodes: [Node]) async throws -> [Node] {
        try await execute(request: nodes.updateRequest()).nodes.map { $0.value }
    }


    // MARK: - Delete Node(s)

    public func delete(node: Node) async throws {
        try await execute(request: node.deleteRequest())
    }

    public func delete(nodes: [Node]) async throws {
        try await execute(request: nodes.deleteRequest())
    }


    // MARK: - Relate Nodes

    public func relate(
        node: Node,
        to: Node,
        type: String,
        properties: [String: PackProtocol] = [:]
    ) async throws -> Relationship {
        let result = try await execute(
            request: Relationship(
                fromNode: node,
                toNode: to,
                type: type,
                direction: .from,
                properties: properties
            ).createRequest()
        )
        guard let (_, relationship) = result.relationships.first else {
            throw BoltClientError.missingRelationshipResponse
        }
        return relationship
    }


    // MARK: - Create Relationship(s)

    @discardableResult
    public func create(relationship: Relationship) async throws -> Relationship {
        let result = try await execute(request: relationship.createRequest())
        guard let (_, relationship) = result.relationships.first else {
            throw BoltClientError.unknownError
        }
        return relationship
    }

    @discardableResult
    public func create(relationships: [Relationship]) async throws -> [Relationship] {
        try await execute(request: relationships.createRequest()).relationships.map { $0.value }
    }


    // MARK: - Get Relationship(s)

    public func get(
        type: String,
        properties: [String: PackProtocol] = [:],
        skip: UInt64 = 0,
        limit: UInt64 = 25
    ) async throws -> [Relationship] {
        try await execute(
            request: Relationship.queryFor(
                type: type,
                andProperties: properties,
                skip: skip,
                limit: limit
            )
        ).relationships.map { $0.value }
    }


    // MARK: - Update Relationship(s)

    @discardableResult
    public func update(relationship: Relationship) async throws -> Relationship {
        let result = try await execute(request: relationship.updateRequest())
        guard let (_, relationship) = result.relationships.first else {
            throw BoltClientError.missingRelationshipResponse
        }
        return relationship
    }

    @discardableResult
    public func update(relationships: [Relationship]) async throws -> [Relationship] {
        try await execute(request: relationships.updateRequest()).relationships.map { $0.value }
    }


    // MARK: - Delete Relationsip(s)

    public func delete(relationship: Relationship) async throws {
        try await execute(request: relationship.deleteRequest())
    }

    public func delete(relationships: [Relationship]) async throws {
        try await execute(request: relationships.deleteRequest())
    }
}
