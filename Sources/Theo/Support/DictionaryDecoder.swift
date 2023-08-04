import Foundation

class DictionaryDecoder {
    init() { }

    func decode<T: Decodable>(_ type: T.Type, from data: [String: Any]) throws -> T {
        let decoder = _Decoder(codingPath: [], source: data)
        return try T(from: decoder)
    }
}

// MARK: - Decoder
extension DictionaryDecoder {
    private class _Decoder: Decoder {
        let codingPath: [CodingKey]
        var userInfo: [CodingUserInfoKey: Any] = [:]
        private let source: Any?

        init(codingPath: [CodingKey], source: Any?) {
            self.codingPath = codingPath
            self.source = source
        }

        // MARK: - KeyedContainer
        func container<Key: CodingKey>(keyedBy type: Key.Type) throws -> KeyedDecodingContainer<Key> {
            return KeyedDecodingContainer(KeyedContainer(codingPath: codingPath, source: try castOrThrow(source, codingPath: codingPath)))
        }
        private struct KeyedContainer<Key: CodingKey>: KeyedDecodingContainerProtocol {
            let codingPath: [CodingKey]
            let allKeys: [Key]
            private let source: [String: Any]

            init(codingPath: [CodingKey], source: [String: Any]) {
                self.codingPath = codingPath
                self.source = source
                self.allKeys = source.keys.compactMap(Key.init)
            }

            func contains(_ key: Key) -> Bool {
                return allKeys.contains(where: { $0.stringValue == key.stringValue })
            }
            func decodeNil(forKey key: Key) throws -> Bool {
                return !contains(key)
            }
            func decode<T: Decodable>(_ type: T.Type, forKey key: Key) throws -> T {
                switch source[key.stringValue] {
                    case let value as T:
                        return value
                    case let value:
                        let decoder = _Decoder(codingPath: codingPath + [key], source: value)
                        return try T(from: decoder)
                }
            }

            func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type, forKey key: Key) throws -> KeyedDecodingContainer<NestedKey> {
                let newPath = codingPath + [key]
                return KeyedDecodingContainer<NestedKey>(KeyedContainer<NestedKey>(
                    codingPath: newPath, source: try castOrThrow(source[key.stringValue], codingPath: newPath))
                )
            }
            func nestedUnkeyedContainer(forKey key: Key) throws -> UnkeyedDecodingContainer {
                let newPath = codingPath + [key]
                return UnkeyedContainer(codingPath: newPath, source: try castOrThrow(source[key.stringValue], codingPath: newPath))
            }

            func superDecoder() throws -> Decoder { fatalError() }
            func superDecoder(forKey key: Key) throws -> Decoder { fatalError() }
        }

        // MARK: - UnkeyedContainer
        func unkeyedContainer() throws -> UnkeyedDecodingContainer {
            return UnkeyedContainer(codingPath: codingPath, source: try castOrThrow(source, codingPath: codingPath))
        }
        private struct UnkeyedContainer: UnkeyedDecodingContainer {
            let codingPath: [CodingKey]
            private(set) var currentIndex: Int = 0
            let count: Int?
            var isAtEnd: Bool { return currentIndex >= count! }
            private let source: [Any]

            init(codingPath: [CodingKey], source: [Any]) {
                self.codingPath = codingPath
                self.source = source
                self.count = source.count
            }

            private mutating func nextValueOrThrow() throws -> Any {
                try throwIfAtEnd()

                defer { currentIndex += 1 }
                return source[currentIndex]
            }
            private func throwIfAtEnd() throws {
                guard isAtEnd else { return }

                throw DecodingError.valueNotFound(Any.self, .init(codingPath: codingPath, debugDescription: "Unkeyed container is at end."))
            }

            mutating func decodeNil() throws -> Bool {
                try throwIfAtEnd()

                let result = source[currentIndex] is NSNull
                if result { currentIndex += 1 }
                return result
            }
            mutating func decode<T: Decodable>(_ type: T.Type) throws -> T {
                switch try nextValueOrThrow() {
                    case let value as T:
                        return value
                    case let value:
                        let decoder = _Decoder(codingPath: codingPath + [AnyCodingKey(currentIndex)], source: value)
                        return try T(from: decoder)
                }
            }

            mutating func nestedContainer<NestedKey: CodingKey>(keyedBy type: NestedKey.Type) throws -> KeyedDecodingContainer<NestedKey> {
                let newPath = codingPath + [AnyCodingKey(currentIndex)]
                return KeyedDecodingContainer<NestedKey>(KeyedContainer<NestedKey>(
                    codingPath: newPath, source: try castOrThrow(nextValueOrThrow(), codingPath: newPath))
                )
            }
            mutating func nestedUnkeyedContainer() throws -> UnkeyedDecodingContainer {
                let newPath = codingPath + [AnyCodingKey(currentIndex)]
                return UnkeyedContainer(codingPath: newPath, source: try castOrThrow(nextValueOrThrow(), codingPath: newPath))
            }

            mutating func superDecoder() throws -> Decoder { fatalError() }
        }

        // MARK: - SingleValueContainer
        func singleValueContainer() throws -> SingleValueDecodingContainer {
            return SingleValueContainer(codingPath: codingPath, source: source)
        }
        private struct SingleValueContainer: SingleValueDecodingContainer {
            let codingPath: [CodingKey]
            let source: Any?

            init(codingPath: [CodingKey], source: Any?) {
                self.codingPath = codingPath
                self.source = source
            }

            func decodeNil() -> Bool { return source == nil || source is NSNull }
            func decode<T: Decodable>(_ type: T.Type) throws -> T {
                let anyValue: Any = try castOrThrow(source, codingPath: codingPath)

                if let value = anyValue as? T {
                    return value
                } else {
                    let decoder = _Decoder(codingPath: codingPath, source: anyValue)
                    return try T(from: decoder)
                }
            }
        }
    }
}

private func castOrThrow<T>(_ value: Any?, codingPath: [CodingKey]) throws -> T {
    switch value {
        case let casted as T:
            return casted
        case let wrong?:
            throw DecodingError.typeMismatch(T.self, .init(codingPath: codingPath, debugDescription: "Actual type: '\(Swift.type(of: wrong))'"))
        case nil:
            throw DecodingError.valueNotFound(T.self, .init(codingPath: codingPath, debugDescription: "Found nil"))
    }
}


struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
    init?(stringValue: String) {
        self.intValue = nil
        self.stringValue = stringValue
    }
}

extension AnyCodingKey {
    init<T: CodingKey>(_ key: T) {
        self.stringValue = key.stringValue
        self.intValue = key.intValue
    }
    init(_ int: Int) {
        self.init(intValue: int)!
    }
    init(_ string: String) {
        self.init(stringValue: string)!
    }
}

extension AnyCodingKey: ExpressibleByStringLiteral {
    init(stringLiteral value: String) {
        self.init(stringValue: value)!
    }
}

extension AnyCodingKey: ExpressibleByIntegerLiteral {
    init(integerLiteral value: Int) {
        self.init(intValue: value)!
    }
}
