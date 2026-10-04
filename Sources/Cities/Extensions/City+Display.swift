//
//  City+Display.swift
//  Cities
//

import Foundation

extension City {

    /// `Portland, Oregon, United States`. A region that repeats the city is
    /// left out: `Tokyo, Japan`, and plain `Singapore`.
    public var displayName: String { Naming.displayName(of: self) }

    /// `Oregon, United States` — the line under the name in a list.
    public var subtitle: String { Naming.subtitle(of: self) }

    /// The country's flag: 🇺🇸.
    public var flag: String { Naming.flag(for: countryCode) }
}
