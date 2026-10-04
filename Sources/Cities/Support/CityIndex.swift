//
//  CityIndex.swift
//  Cities
//
//  Everything search needs, built once from the bundled tables.
//

import Foundation

/// The loaded dataset and the sorted keys that make prefix search a binary
/// search. Immutable once built, so sharing it across threads is free.
struct CityIndex: Sendable {

    /// Built on first use, exactly once. A `static let` is initialised lazily
    /// and atomically, which is the whole of the thread safety needed.
    static let shared = CityIndex()

    /// One searchable spelling of one city.
    struct Key: Sendable {
        /// Where the folded bytes start in ``CityIndex/bytes``.
        let start: Int32
        let length: Int32
        let city: Int32
        /// Whether this key starts at a later word of a name — `york city`
        /// inside `new york city` — rather than at its beginning.
        let isWord: Bool
        /// Whether it comes from an alternate name rather than the name.
        let isAlternate: Bool
    }

    /// What a qualifier after the city can name: its region or its country.
    struct Place: Sendable {
        /// Folded region name: `oregon`. Empty when there is none.
        let region: String
        /// Lowercased abbreviation: `or`, `on`, `nsw`. Empty when none.
        let regionAbbreviation: String
        /// Lowercased ISO code: `us`.
        let countryCode: String
        /// The folded country name and its aliases: `united states`, `usa`.
        let countryNames: [String]
    }

    let cities: [City]
    /// Per city, an index into ``places``.
    let placeOfCity: [Int32]
    let places: [Place]
    /// Every folded key, end to end.
    let bytes: [UInt8]
    /// Sorted by their bytes.
    let keys: [Key]
    let byID: [Int: Int32]
    /// Zone identifier → cities in it, most populous first.
    let byZone: [String: [Int32]]
    /// Zone identifier → standard offset in seconds, the fallback for a zone
    /// the operating system does not know.
    let zoneOffsets: [String: Int]

    init() {
        let countries = BundledData.countries()
        let regions = BundledData.regions()
        let zones = BundledData.zones()
        let loaded = BundledData.cities(countries: countries, regions: regions, zones: zones)

        var cities: [City] = []
        var placeOfCity: [Int32] = []
        var places: [Place] = []
        var placeSlots: [String: Int32] = [:]
        var bytes: [UInt8] = []
        var keys: [Key] = []
        var byID: [Int: Int32] = [:]
        var byZone: [String: [Int32]] = [:]
        cities.reserveCapacity(loaded.count)
        keys.reserveCapacity(loaded.count * 3)
        bytes.reserveCapacity(loaded.count * 30)

        for (offset, entry) in loaded.enumerated() {
            let city = entry.city
            let index = Int32(offset)
            cities.append(city)
            byID[city.id] = index
            byZone[city.timeZoneIdentifier, default: []].append(index)

            // Cities in one region share one Place, so a qualifier's terms
            // are folded once per region rather than once per city.
            let slot: Int32
            if let existing = placeSlots[entry.regionKey] {
                slot = existing
            } else {
                let region = regions[entry.regionKey]
                let country = countries[city.countryCode]
                let names = ([country?.name ?? city.countryCode] + (country?.aliases ?? [])).map(Folding.fold)
                places.append(Place(
                    region: region.map { Folding.fold($0.name) } ?? "",
                    regionAbbreviation: region?.abbreviation.lowercased() ?? "",
                    countryCode: city.countryCode.lowercased(),
                    countryNames: names
                ))
                slot = Int32(places.count - 1)
                placeSlots[entry.regionKey] = slot
            }
            placeOfCity.append(slot)

            // Each distinct spelling once as a whole, and once from each later
            // word: "new york city", "york city", "city".
            var seen = Set<String>()
            let spellings = [(city.name, false), (city.asciiName, false)] + city.alternateNames.map { ($0, true) }
            for (spelling, isAlternate) in spellings {
                let folded = Folding.fold(spelling)
                guard !folded.isEmpty, seen.insert(folded).inserted else { continue }
                let utf8 = Array(folded.utf8)
                let start = Int32(bytes.count)
                bytes.append(contentsOf: utf8)
                keys.append(Key(start: start, length: Int32(utf8.count), city: index,
                                isWord: false, isAlternate: isAlternate))
                for (position, byte) in utf8.enumerated() where byte == 0x20 {
                    let wordStart = position + 1
                    keys.append(Key(start: start + Int32(wordStart), length: Int32(utf8.count - wordStart),
                                    city: index, isWord: true, isAlternate: isAlternate))
                }
            }
        }

        bytes.withUnsafeBufferPointer { buffer in
            keys.sort { lhs, rhs in
                Matching.compare(buffer, lhs.start, lhs.length, buffer, rhs.start, rhs.length) < 0
            }
        }
        for zone in byZone.keys {
            byZone[zone]?.sort { cities[Int($0)].population > cities[Int($1)].population }
        }

        self.cities = cities
        self.placeOfCity = placeOfCity
        self.places = places
        self.bytes = bytes
        self.keys = keys
        self.byID = byID
        self.byZone = byZone
        self.zoneOffsets = Dictionary(zones.map { ($0.identifier, $0.offset) }, uniquingKeysWith: { first, _ in first })
    }
}
