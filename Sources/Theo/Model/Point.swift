import Bolt
import CoreLocation
import Foundation
import PackStream

public final class Point: Codable, Sendable {
  // MARK: - Enums

  enum CodingKeys: String, CodingKey {
    case latitude
    case longitude
  }


  // MARK: - Constants & Variables

  private static let srid = 4326

  public let latitude: CLLocationDegrees
  public let longitude: CLLocationDegrees

  var coordinate: CLLocationCoordinate2D {
    .init(latitude: latitude, longitude: longitude)
  }


  // MARK: - init

  init?(data: PackProtocol) {
    if let s = data as? Structure,
       s.items.count >= 3,
       s.items[0] as? Int == Point.srid,
       let latitude = s.items[2] as? CLLocationDegrees,
       let longitude = s.items[1] as? CLLocationDegrees {
      self.latitude = latitude
      self.longitude = longitude
    } else {
      return nil
    }
  }


  // MARK: - Decodable

  public required init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    print("something", values)
    latitude = 10.0
    longitude = 10.0
  }

  public func encode(to encoder: Encoder) throws {
//    var container = encoder.container(keyedBy: CodingKeys.self)
//    try container.encode(self.latitude, forKey: .latitude)
//    try container.encode(self.longitude, forKey: .longitude)
  }
}


extension Structure: Codable {
  enum CodingKeys: String, CodingKey {
    case items
    case signature
  }

  public init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)

    print("STRUCTURE DECODABLE", values)
    self.init(signature: 8, items: [])
  }

  public func encode(to encoder: Encoder) throws {
    print("STRUCTURE ENCODABLE")
  }
}
