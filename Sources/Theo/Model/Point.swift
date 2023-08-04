import Bolt
import CoreLocation
import Foundation
import PackStream

public class Point {
  private static let srid = 88

  public private(set) var latitude: CLLocationDegrees
  public private(set) var longitude: CLLocationDegrees

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
}
