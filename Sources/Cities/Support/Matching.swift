//
//  Matching.swift
//  Cities
//
//  Turning what somebody typed into a ranked list of cities.
//

import Foundation

enum Matching {

    /// How well a city's name answers the query. Lower is better.
    ///
    /// Tier first, population second: for `paris`, Paris, Texas (25,000)
    /// outranks every longer name that merely starts "Paris", and among the
    /// exact Parises size decides, so the French one leads.
    enum Tier: Int, Comparable {
        /// The whole name, or a whole alternate name: `kiev` for Kyiv.
        case exact
        /// The start of the name: `zur` for Zürich.
        case prefix
        /// The start of an alternate name: `muen` for Munich (`München`).
        /// Below the name, so `san` lists San Antonio before Caracas, whose
        /// long form is Santiago de León de Caracas.
        case alternatePrefix
        /// The start of a later word in a name: `paulo` for São Paulo.
        case word

        static func < (lhs: Tier, rhs: Tier) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// One way of reading a query: which part is the city, and which part
    /// narrows it down.
    struct Reading: Equatable {
        let name: String
        let qualifier: [String]
    }

    // MARK: - Search

    /// The ranked cities for a query, best first.
    static func search(_ text: String, limit: Int, in index: CityIndex) -> [City] {
        guard limit > 0 else { return [] }
        var results: [City] = []
        var taken = Set<Int32>()

        for reading in readings(of: text) {
            let found = candidates(prefix: reading.name, in: index)
            let ranked = found
                .filter { city, _ in
                    reading.qualifier.isEmpty
                        || qualifies(reading.qualifier[...], index.places[Int(index.placeOfCity[Int(city)])])
                }
                .sorted { lhs, rhs in
                    if lhs.value != rhs.value { return lhs.value < rhs.value }
                    let left = index.cities[Int(lhs.key)], right = index.cities[Int(rhs.key)]
                    if left.population != right.population { return left.population > right.population }
                    return left.id < right.id
                }
            for (city, _) in ranked where taken.insert(city).inserted {
                results.append(index.cities[Int(city)])
                if results.count == limit { return results }
            }
        }
        return results
    }

    /// Every way to read a query, the most literal first.
    ///
    /// With a comma the split is the writer's: `portland, oregon` is the city
    /// `portland` in `oregon`. Without one, every split is tried from the
    /// right, so `portland maine` is first a city called that — there is
    /// none — then `portland` in `maine`; and `new york` is first the city
    /// New York, and only then something starting `new` in a place `york`.
    static func readings(of text: String) -> [Reading] {
        if text.contains(",") {
            let parts = text.split(separator: ",", omittingEmptySubsequences: false)
            let name = Folding.fold(String(parts[0]))
            guard !name.isEmpty else { return [] }
            let qualifier = parts.dropFirst().flatMap { Folding.fold(String($0)).split(separator: " ").map(String.init) }
            return [Reading(name: name, qualifier: qualifier)]
        }
        let words = Folding.fold(text).split(separator: " ").map(String.init)
        return stride(from: words.count, through: 1, by: -1).map { count in
            Reading(name: words[..<count].joined(separator: " "), qualifier: Array(words[count...]))
        }
    }

    /// Every city with a key starting with `prefix`, and its best tier.
    static func candidates(prefix: String, in index: CityIndex) -> [Int32: Tier] {
        let target = Array(prefix.utf8)
        guard !target.isEmpty else { return [:] }
        var best: [Int32: Tier] = [:]

        index.bytes.withUnsafeBufferPointer { bytes in
            target.withUnsafeBufferPointer { wanted in
                // Lower bound: the first key not less than the prefix. Every
                // key that starts with it follows contiguously.
                var low = 0, high = index.keys.count
                while low < high {
                    let middle = (low + high) / 2
                    let key = index.keys[middle]
                    if compare(bytes, key.start, key.length, wanted, 0, Int32(wanted.count)) < 0 {
                        low = middle + 1
                    } else {
                        high = middle
                    }
                }
                var position = low
                while position < index.keys.count {
                    let key = index.keys[position]
                    guard hasPrefix(bytes, key.start, key.length, wanted) else { break }
                    let tier: Tier = key.isWord ? .word
                        : Int(key.length) == wanted.count ? .exact
                        : key.isAlternate ? .alternatePrefix : .prefix
                    if let existing = best[key.city], existing <= tier {} else { best[key.city] = tier }
                    position += 1
                }
            }
        }
        return best
    }

    // MARK: - Qualifiers

    /// Whether the qualifier words all name the city's region or country.
    ///
    /// Words may group: `new york` is one region, `oregon us` is a region and
    /// a country. The longest group is tried first.
    static func qualifies(_ words: ArraySlice<String>, _ place: CityIndex.Place) -> Bool {
        guard let first = words.indices.first else { return true }
        for end in words.indices.reversed() {
            let phrase = words[first...end].joined(separator: " ")
            if names(phrase, place), qualifies(words[(end + 1)...], place) { return true }
        }
        return false
    }

    /// Whether one phrase names the place: its country code, its region's
    /// abbreviation, or the start of a word in either's name.
    static func names(_ phrase: String, _ place: CityIndex.Place) -> Bool {
        if phrase == place.countryCode { return true }
        if !place.regionAbbreviation.isEmpty, phrase == place.regionAbbreviation { return true }
        if startsAWord(phrase, in: place.region) { return true }
        return place.countryNames.contains { startsAWord(phrase, in: $0) }
    }

    /// `col` starts a word in `british columbia`; `umbia` does not.
    static func startsAWord(_ phrase: String, in name: String) -> Bool {
        guard !name.isEmpty, !phrase.isEmpty else { return false }
        return name.hasPrefix(phrase) || name.contains(" " + phrase)
    }

    // MARK: - Bytes

    /// Lexicographic order on two byte ranges; a prefix sorts first.
    static func compare(
        _ left: UnsafeBufferPointer<UInt8>, _ leftStart: Int32, _ leftLength: Int32,
        _ right: UnsafeBufferPointer<UInt8>, _ rightStart: Int32, _ rightLength: Int32
    ) -> Int {
        let count = Int(min(leftLength, rightLength))
        for offset in 0..<count {
            let a = left[Int(leftStart) + offset], b = right[Int(rightStart) + offset]
            if a != b { return a < b ? -1 : 1 }
        }
        return Int(leftLength) - Int(rightLength)
    }

    static func hasPrefix(_ bytes: UnsafeBufferPointer<UInt8>, _ start: Int32, _ length: Int32,
                          _ prefix: UnsafeBufferPointer<UInt8>) -> Bool {
        guard Int(length) >= prefix.count else { return false }
        for offset in 0..<prefix.count where bytes[Int(start) + offset] != prefix[offset] { return false }
        return true
    }
}
