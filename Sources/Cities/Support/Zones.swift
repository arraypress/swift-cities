//
//  Zones.swift
//  Cities
//

import Foundation

enum Zones {

    /// The zone for an IANA identifier, which the system almost always knows.
    ///
    /// When it does not — a zone newer than the OS, such as
    /// `America/Ciudad_Juarez` (2022) on an older release — the answer is a
    /// fixed zone at its standard offset from GeoNames' `timeZones.txt`:
    /// right on the hour outside daylight saving, rather than silently UTC.
    static func timeZone(for identifier: String, offsets: [String: Int]) -> TimeZone {
        if let zone = TimeZone(identifier: identifier) { return zone }
        if let offset = offsets[identifier], let fixed = TimeZone(secondsFromGMT: offset) { return fixed }
        return TimeZone(secondsFromGMT: 0)!
    }
}
