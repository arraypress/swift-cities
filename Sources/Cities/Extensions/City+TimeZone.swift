//
//  City+TimeZone.swift
//  Cities
//

import Foundation

extension City {

    /// The city's time zone.
    ///
    /// Never `nil`: a zone the operating system does not know (newer than
    /// the OS) falls back to a fixed zone at its standard offset.
    public var timeZone: TimeZone {
        Zones.timeZone(for: timeZoneIdentifier, offsets: CityIndex.shared.zoneOffsets)
    }
}
