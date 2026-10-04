//
//  Geodesy.swift
//  Cities
//

import Foundation

enum Geodesy {

    /// The mean radius of the Earth, in metres (IUGG).
    static let earthRadius = 6_371_008.8

    /// Great-circle distance in metres, by the haversine formula.
    ///
    /// A sphere, not the ellipsoid: up to about 0.5% off, which never changes
    /// which of two cities is nearer in a way anybody picking a time zone
    /// would notice.
    static func distance(_ latitude1: Double, _ longitude1: Double,
                         _ latitude2: Double, _ longitude2: Double) -> Double {
        let φ1 = latitude1 * .pi / 180, φ2 = latitude2 * .pi / 180
        let Δφ = φ2 - φ1
        let Δλ = (longitude2 - longitude1) * .pi / 180
        let a = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        return 2 * earthRadius * asin(min(1, sqrt(a)))
    }

    /// The city nearest a point, among those with at least `minimumPopulation`.
    ///
    /// A straight scan: 34,000 distances is well under a millisecond's work
    /// more than any spatial index would save.
    static func nearest(_ latitude: Double, _ longitude: Double, minimumPopulation: Int,
                        in cities: [City]) -> City? {
        var best: City?
        var bestDistance = Double.infinity
        for city in cities where city.population >= minimumPopulation {
            let distance = distance(latitude, longitude, city.latitude, city.longitude)
            if distance < bestDistance {
                bestDistance = distance
                best = city
            }
        }
        return best
    }
}
