//
//  City.swift
//  Cities
//

import Foundation

/// One populated place from the GeoNames `cities15000` list.
///
/// Every field is GeoNames' own. Names are as GeoNames writes them — mostly
/// the English name where one is in common use (`Munich`, `Vienna`), the
/// local one otherwise (`Zürich`, `São Paulo`). Assembled strings such as
/// `displayName` live in extensions, not here.
public struct City: Sendable, Hashable, Codable, Identifiable {

    /// The GeoNames id — stable across releases, and the way to store a choice.
    public let id: Int

    /// The name, with its diacritics: `Zürich`.
    public let name: String

    /// GeoNames' ASCII spelling: `Zuerich`. Often equal to ``name``.
    public let asciiName: String

    /// Up to five other names people search by — English exonyms and
    /// historic names first (`Kiev`, `Bombay`, `Saigon`), then the local
    /// language's (`München`, `Wien`). Latin script only.
    public let alternateNames: [String]

    /// ISO 3166-1 alpha-2, uppercase: `US`.
    public let countryCode: String

    /// The country's English name: `United States`.
    public let countryName: String

    /// The first-level region's English name — a state, province or
    /// country of the UK: `Oregon`, `Ontario`, `England`. `nil` when
    /// GeoNames assigns none.
    public let regionName: String?

    /// The population GeoNames records. Over 15,000, or a capital.
    public let population: Int

    /// The IANA time zone: `America/Los_Angeles`.
    public let timeZoneIdentifier: String

    /// Degrees north, to four decimal places (about 11 metres).
    public let latitude: Double

    /// Degrees east, to four decimal places.
    public let longitude: Double

    /// A city as GeoNames lists it.
    public init(
        id: Int, name: String, asciiName: String, alternateNames: [String],
        countryCode: String, countryName: String, regionName: String?,
        population: Int, timeZoneIdentifier: String,
        latitude: Double, longitude: Double
    ) {
        self.id = id
        self.name = name
        self.asciiName = asciiName
        self.alternateNames = alternateNames
        self.countryCode = countryCode
        self.countryName = countryName
        self.regionName = regionName
        self.population = population
        self.timeZoneIdentifier = timeZoneIdentifier
        self.latitude = latitude
        self.longitude = longitude
    }
}
