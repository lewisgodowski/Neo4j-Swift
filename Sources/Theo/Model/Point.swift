import Bolt
import CoreLocation
import Foundation
import PackStream

public final class Point: ResponseItem, Sendable {
    // MARK: - Constants & Variables

    private static let srid = 4326

    public let latitude: CLLocationDegrees
    public let longitude: CLLocationDegrees

    var coordinate: CLLocationCoordinate2D {
        .init(latitude: latitude, longitude: longitude)
    }


    // MARK: - init

    public init?(data: PackProtocol) {
        if let s = data as? Structure,
           s.items.count >= 3,
           s.items[0] as? Int == Point.srid,
           let latitude = s.items[2] as? CLLocationDegrees,
           let longitude = s.items[1] as? CLLocationDegrees
        {
            self.latitude = latitude
            self.longitude = longitude
        } else {
            return nil
        }
    }

    public init?(structure: Structure) {
        if structure.items.count >= 3,
           structure.items[0] as? Int == Point.srid,
           let latitude = structure.items[2] as? CLLocationDegrees,
           let longitude = structure.items[1] as? CLLocationDegrees
        {
            self.latitude = latitude
            self.longitude = longitude
        } else {
            return nil
        }
    }
}
