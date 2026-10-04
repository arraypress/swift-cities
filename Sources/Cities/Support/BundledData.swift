//
//  BundledData.swift
//  Cities
//
//  Reading the four tables `Scripts/build-cities.py` writes.
//

import Foundation

enum BundledData {

    /// One region's English name and the abbreviation people write after a
    /// city, if it has one (`OR`, `ON`, `NSW`).
    struct Region {
        let name: String
        let abbreviation: String
    }

    /// The tab-separated rows of a bundled table. A missing resource is a
    /// broken build, not a runtime condition, so it stops loudly.
    static func rows(_ name: String) -> [[Substring]] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "tsv", subdirectory: "Resources"),
              let data = try? Data(contentsOf: url) else {
            preconditionFailure("Cities: the bundled \(name).tsv is missing — run Scripts/build-cities.py")
        }
        let text = String(decoding: data, as: UTF8.self)
        return text.split(separator: "\n").map { $0.split(separator: "\t", omittingEmptySubsequences: false) }
    }

    /// Country code → English name, and the aliases people write instead.
    static func countries() -> [String: (name: String, aliases: [String])] {
        var countries: [String: (name: String, aliases: [String])] = [:]
        for row in rows("countries") where row.count >= 3 {
            let aliases = row[2].split(separator: "|").map(String.init)
            countries[String(row[0])] = (String(row[1]), aliases)
        }
        return countries
    }

    /// `"US.OR"` → Oregon.
    static func regions() -> [String: Region] {
        var regions: [String: Region] = [:]
        for row in rows("regions") where row.count >= 4 {
            regions["\(row[0]).\(row[1])"] = Region(name: String(row[2]), abbreviation: String(row[3]))
        }
        return regions
    }

    /// Zone identifiers in file order — cities refer to them by row — and
    /// each one's standard offset from UTC in seconds.
    static func zones() -> [(identifier: String, offset: Int)] {
        rows("zones").compactMap { row in
            guard row.count >= 2, let offset = Int(row[1]) else { return nil }
            return (String(row[0]), offset)
        }
    }

    /// Every city, with its admin1 code kept beside it for the region lookup.
    static func cities(
        countries: [String: (name: String, aliases: [String])],
        regions: [String: Region],
        zones: [(identifier: String, offset: Int)]
    ) -> [(city: City, regionKey: String)] {
        rows("cities").compactMap { row in
            guard row.count >= 10,
                  let id = Int(row[0]),
                  let population = Int(row[6]),
                  let zone = Int(row[7]), zones.indices.contains(zone),
                  let latitude = Double(row[8]),
                  let longitude = Double(row[9]) else { return nil }
            let name = String(row[1])
            let countryCode = String(row[4])
            let regionKey = "\(countryCode).\(row[5])"
            let city = City(
                id: id,
                name: name,
                asciiName: row[2].isEmpty ? name : String(row[2]),
                alternateNames: row[3].split(separator: "|").map(String.init),
                countryCode: countryCode,
                countryName: countries[countryCode]?.name ?? countryCode,
                regionName: regions[regionKey]?.name,
                population: population,
                timeZoneIdentifier: zones[zone].identifier,
                latitude: latitude,
                longitude: longitude
            )
            return (city, regionKey)
        }
    }
}
