//
//  Gazetteer.swift
//  Cities
//
//  The namespace, and every question the dataset answers.
//

import Foundation

/// Every city over 15,000 people, searchable offline, each with its time zone.
///
/// The data is GeoNames' `cities15000` (CC BY 4.0), bundled as plain
/// tab-separated text and read once — on the first call to anything here —
/// into an immutable index that every thread then shares. Nothing touches
/// the network, ever.
///
/// Search folds case and diacritics (`zurich` finds Zürich, `kobenhavn`
/// finds København), matches prefixes of names and their later words, and
/// reads a trailing region or country as a filter: `portland maine`,
/// `london, ca`, `paris tx`.
public enum Gazetteer {

    /// Cities whose name starts with `text`, best first.
    ///
    /// Ranked by how much of a name matched — the whole name, then the start
    /// of one, then the start of a later word — and then by population, so
    /// `portland` is Oregon before Maine, and `york` is York before New York.
    ///
    /// Anything after the city narrows it to a region or a country, named,
    /// abbreviated or by code: `portland, me`, `portland maine`,
    /// `london on`, `london uk`, `springfield illinois`. With a comma the
    /// split is taken as written; without one, every split is tried, the
    /// longest city name first.
    ///
    /// - Parameters:
    ///   - text: what somebody typed. Empty, or wholly non-Latin, finds nothing.
    ///   - limit: the most cities to return.
    public static func search(_ text: String, limit: Int = 10) -> [City] {
        Matching.search(text, limit: limit, in: .shared)
    }

    /// The cities in a time zone, most populous first.
    ///
    /// The first is the city to label the zone with: Tokyo for `Asia/Tokyo`,
    /// London for `Europe/London`.
    public static func cities(in zone: TimeZone) -> [City] {
        cities(inZone: zone.identifier)
    }

    /// The cities in the zone with this IANA identifier, most populous first.
    /// Empty for an identifier no city here uses — including legacy aliases
    /// such as `US/Pacific`.
    public static func cities(inZone identifier: String) -> [City] {
        let index = CityIndex.shared
        return (index.byZone[identifier] ?? []).map { index.cities[Int($0)] }
    }

    /// The cities in a country, by ISO 3166-1 alpha-2 code, most populous first.
    public static func cities(inCountry code: String) -> [City] {
        let wanted = code.uppercased()
        return CityIndex.shared.cities
            .filter { $0.countryCode == wanted }
            .sorted { $0.population != $1.population ? $0.population > $1.population : $0.id < $1.id }
    }

    /// The city with this GeoNames id — the way to restore a stored choice.
    public static func city(id: Int) -> City? {
        let index = CityIndex.shared
        return index.byID[id].map { index.cities[Int($0)] }
    }

    /// The city nearest a coordinate, by great-circle distance.
    ///
    /// - Parameter minimumPopulation: ignore cities smaller than this — a
    ///   location in the suburbs usually wants the city, not the suburb.
    public static func nearest(latitude: Double, longitude: Double, minimumPopulation: Int = 0) -> City? {
        Geodesy.nearest(latitude, longitude, minimumPopulation: minimumPopulation, in: CityIndex.shared.cities)
    }

    /// Every city, in GeoNames id order.
    public static var all: [City] { CityIndex.shared.cities }

    /// How many cities are bundled.
    public static var count: Int { CityIndex.shared.cities.count }
}
