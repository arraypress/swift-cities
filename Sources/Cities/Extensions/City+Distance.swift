//
//  City+Distance.swift
//  Cities
//

import Foundation

extension City {

    /// Great-circle distance to another city, in metres.
    public func distance(to other: City) -> Double {
        Geodesy.distance(latitude, longitude, other.latitude, other.longitude)
    }

    /// Great-circle distance to a coordinate, in metres.
    public func distance(toLatitude latitude: Double, longitude: Double) -> Double {
        Geodesy.distance(self.latitude, self.longitude, latitude, longitude)
    }
}
