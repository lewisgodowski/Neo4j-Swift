import PackStream

extension Structure {
    var subType: ResponseItem.Type? {
        if signature == 78, items.count >= 3 { return Node.self }
        if signature == 80, items.count >= 3 { return Path.self }
        if signature == 88, items.count >= 3 { return Point.self }
        if signature == 82, items.count >= 5 { return Relationship.self }
        if signature == 114, items.count >= 3 { return UnboundRelationship.self }
        return nil
    }
}

extension Structure: Codable {
    enum CodingKeys: String, CodingKey {
        case items
        case signature
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)

        // let items = try values.decode([PackProtocol].self, forKey: .signature)
        let signature = try values.decode(UInt8.self, forKey: .signature)

        self.init(signature: signature, items: [])
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        // try container.encode(items, forKey: .items)
        try container.encode(signature, forKey: .signature)
    }
}
