import Bolt
import CoreLocation
import Foundation
import PackStream

public class Point: Codable {
  // MARK: - Enums

  enum CodingKeys: String, CodingKey {
    case latitude
    case longitude
  }


  // MARK: - Constants & Variables

  private static let srid = 88

  public private(set) var latitude: CLLocationDegrees
  public private(set) var longitude: CLLocationDegrees


  // MARK: - init

  init?(data: PackProtocol) {
    if let s = data as? Structure,
       s.signature == Point.srid,
       s.items.count >= 2,
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
