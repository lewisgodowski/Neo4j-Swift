import Foundation

public enum NodeID {
    case int(Int64)
    case uuid(UUID)
    case string(String)

    var value: String {
        switch self {
        case .int(let int): return "\(int)"
        case .uuid(let uuid): return uuid.uuidString
        case .string(let string): return string
        }
    }
}
