//
//  CitiesTests.swift
//  Cities
//
//  Every expectation here is a fixed fact about the bundled GeoNames data:
//  the city a query must find first, and the zone it must be in. Ids are
//  GeoNames ids, which do not change between releases.
//

import XCTest
@testable import Cities

private let portlandOregon = 5746545
private let portlandMaine = 4975802
private let londonEngland = 2643743
private let londonOntario = 6058560

final class SearchTests: XCTestCase {

    func testTokyoIsInAsiaTokyo() throws {
        let tokyo = try XCTUnwrap(Gazetteer.search("Tokyo").first)
        XCTAssertEqual(tokyo.name, "Tokyo")
        XCTAssertEqual(tokyo.countryCode, "JP")
        XCTAssertEqual(tokyo.timeZoneIdentifier, "Asia/Tokyo")
        XCTAssertEqual(tokyo.timeZone.identifier, "Asia/Tokyo")
    }

    func testDiacriticsFold() throws {
        // GeoNames' own ASCII name for Zürich is "Zuerich", so "zurich" only
        // matches because the name itself is folded.
        let zurich = try XCTUnwrap(Gazetteer.search("zurich").first)
        XCTAssertEqual(zurich.name, "Zürich")
        XCTAssertEqual(zurich.timeZoneIdentifier, "Europe/Zurich")
        XCTAssertEqual(Gazetteer.search("ZÜRICH").first?.id, zurich.id)
        XCTAssertEqual(Gazetteer.search("zuerich").first?.id, zurich.id)
    }

    func testSaoPauloWithoutTheTilde() throws {
        let sao = try XCTUnwrap(Gazetteer.search("sao paulo").first)
        XCTAssertEqual(sao.name, "São Paulo")
        XCTAssertEqual(sao.countryCode, "BR")
        XCTAssertEqual(sao.timeZoneIdentifier, "America/Sao_Paulo")
    }

    func testLettersThatDoNotDecompose() throws {
        XCTAssertEqual(Gazetteer.search("kobenhavn").first?.countryCode, "DK")
        XCTAssertEqual(Gazetteer.search("lodz").first?.name, "Łódź")
    }

    func testPortlandIsOregonFirstBecauseItIsBigger() throws {
        let results = Gazetteer.search("portland")
        XCTAssertEqual(results.first?.id, portlandOregon)
        XCTAssertEqual(results.dropFirst().first?.id, portlandMaine)
        XCTAssertEqual(results.first?.timeZoneIdentifier, "America/Los_Angeles")
    }

    func testPortlandMaineDisambiguates() throws {
        for query in ["portland maine", "portland, maine", "Portland, ME", "portland me us", "portland, maine, united states"] {
            let first = try XCTUnwrap(Gazetteer.search(query).first, query)
            XCTAssertEqual(first.id, portlandMaine, query)
            XCTAssertEqual(first.timeZoneIdentifier, "America/New_York", query)
        }
        XCTAssertEqual(Gazetteer.search("portland oregon").first?.id, portlandOregon)
        XCTAssertEqual(Gazetteer.search("portland or").first?.id, portlandOregon)
    }

    func testLondonQualifiedByCountryOrProvince() throws {
        XCTAssertEqual(Gazetteer.search("london").first?.id, londonEngland)
        XCTAssertEqual(Gazetteer.search("london ca").first?.id, londonOntario)
        XCTAssertEqual(Gazetteer.search("london on").first?.id, londonOntario)
        XCTAssertEqual(Gazetteer.search("london, canada").first?.id, londonOntario)
        XCTAssertEqual(Gazetteer.search("london uk").first?.id, londonEngland)
        XCTAssertEqual(Gazetteer.search("london england").first?.id, londonEngland)
    }

    func testAMultiWordRegion() throws {
        let buffalo = try XCTUnwrap(Gazetteer.search("buffalo new york").first)
        XCTAssertEqual(buffalo.regionName, "New York")
        // GeoNames' admin1 code for the District is "DC", which is what people write.
        let washington = try XCTUnwrap(Gazetteer.search("washington dc").first)
        XCTAssertEqual(washington.name, "Washington")
        XCTAssertEqual(washington.regionName, "District of Columbia")
    }

    func testAMultiWordNameIsReadAsANameFirst() throws {
        // Not "something starting new, in a place starting york".
        let first = try XCTUnwrap(Gazetteer.search("new york").first)
        XCTAssertEqual(first.name, "New York City")
        XCTAssertEqual(first.timeZoneIdentifier, "America/New_York")
    }

    func testASmallCityJustOverTheThreshold() throws {
        let town = try XCTUnwrap(Gazetteer.search("aberystwyth").first)
        XCTAssertEqual(town.name, "Aberystwyth")
        XCTAssertEqual(town.regionName, "Wales")
        XCTAssertEqual(town.countryCode, "GB")
        XCTAssertEqual(town.timeZoneIdentifier, "Europe/London")
        XCTAssertGreaterThanOrEqual(town.population, 15_000)
        XCTAssertLessThan(town.population, 25_000)
    }

    func testNothingMatches() {
        XCTAssertEqual(Gazetteer.search("xqzzyv"), [])
        XCTAssertEqual(Gazetteer.search(""), [])
        XCTAssertEqual(Gazetteer.search("   "), [])
        XCTAssertEqual(Gazetteer.search(","), [])
        XCTAssertEqual(Gazetteer.search("portland narnia"), [])
        XCTAssertEqual(Gazetteer.search("tokyo", limit: 0), [])
    }

    func testANonLatinQueryFindsNothingRatherThanSomethingWrong() {
        XCTAssertEqual(Gazetteer.search("東京"), [])
    }

    func testExactMatchesComeFirstThenPopulation() throws {
        let results = Gazetteer.search("springfield", limit: 50)
        XCTAssertGreaterThan(results.count, 3)
        let exact = results.filter { $0.name == "Springfield" }
        XCTAssertEqual(Array(results.prefix(exact.count)), exact, "exact names lead")
        XCTAssertEqual(exact.map(\.population), exact.map(\.population).sorted(by: >))
    }

    func testAPrefixRanksByPopulation() throws {
        let results = Gazetteer.search("lon", limit: 20)
        XCTAssertEqual(results.first?.id, londonEngland)
        XCTAssertEqual(results.map(\.population), results.map(\.population).sorted(by: >))
    }

    func testTheStartOfANameBeatsALaterWord() throws {
        // York (a prefix of the whole name) before New York City (a later
        // word), though New York is fifty times the size.
        let results = Gazetteer.search("york", limit: 50)
        let york = try XCTUnwrap(results.firstIndex { $0.name == "York" && $0.countryCode == "GB" })
        let newYork = try XCTUnwrap(results.firstIndex { $0.name == "New York City" })
        XCTAssertLessThan(york, newYork)
    }

    func testAnAlternateNamesPrefixRanksBelowARealName() {
        // Caracas's long form is "Santiago de León de Caracas"; it is bigger
        // than San Antonio, but "san" is not what anybody types for it.
        let results = Gazetteer.search("san", limit: 10)
        XCTAssertFalse(results.contains { $0.name == "Caracas" })
        XCTAssertTrue(results.allSatisfy { Folding.fold($0.name).hasPrefix("san") })
    }

    func testLongFormsDoNotLeakIntoOtherCities() {
        // "London Borough of Brent" is dropped at build time, so "london"
        // lists Londons, not the boroughs.
        XCTAssertFalse(Gazetteer.search("london").contains { $0.name == "Brent" })
    }

    func testALaterWordStillMatches() throws {
        XCTAssertTrue(Gazetteer.search("paulo").contains { $0.name == "São Paulo" })
    }

    func testAlternateNamesFindTheCity() throws {
        XCTAssertEqual(Gazetteer.search("kiev").first?.name, "Kyiv")
        XCTAssertEqual(Gazetteer.search("bombay").first?.name, "Mumbai")
        XCTAssertEqual(Gazetteer.search("saigon").first?.name, "Ho Chi Minh City")
        XCTAssertEqual(Gazetteer.search("munchen").first?.name, "Munich")
        XCTAssertEqual(Gazetteer.search("wien").first?.name, "Vienna")
    }

    func testLimitIsHonoured() {
        XCTAssertEqual(Gazetteer.search("s", limit: 7).count, 7)
    }
}

final class LookupTests: XCTestCase {

    func testCitiesInAZoneAreMostPopulousFirst() throws {
        let tokyo = TimeZone(identifier: "Asia/Tokyo")!
        let cities = Gazetteer.cities(in: tokyo)
        XCTAssertEqual(cities.first?.name, "Tokyo")
        XCTAssertTrue(cities.allSatisfy { $0.timeZoneIdentifier == "Asia/Tokyo" })
        XCTAssertEqual(cities.map(\.population), cities.map(\.population).sorted(by: >))
        XCTAssertGreaterThan(cities.count, 100)

        XCTAssertEqual(Gazetteer.cities(inZone: "Europe/London").first?.id, londonEngland)
        XCTAssertEqual(Gazetteer.cities(inZone: "Not/AZone"), [])
    }

    func testCitiesInACountry() {
        let swiss = Gazetteer.cities(inCountry: "ch")
        XCTAssertEqual(swiss.first?.name, "Zürich")
        XCTAssertTrue(swiss.allSatisfy { $0.countryCode == "CH" })
    }

    func testCityByID() throws {
        XCTAssertEqual(Gazetteer.city(id: portlandOregon)?.name, "Portland")
        XCTAssertNil(Gazetteer.city(id: -1))
    }

    func testNearest() throws {
        // Trafalgar Square.
        XCTAssertEqual(Gazetteer.nearest(latitude: 51.5080, longitude: -0.1281)?.id, londonEngland)
        // Just outside Portland, Maine, which is bigger than its neighbours.
        XCTAssertEqual(Gazetteer.nearest(latitude: 43.66, longitude: -70.26, minimumPopulation: 50_000)?.id, portlandMaine)
    }

    func testDistance() throws {
        let london = try XCTUnwrap(Gazetteer.city(id: londonEngland))
        let paris = try XCTUnwrap(Gazetteer.search("paris").first)
        XCTAssertEqual(london.distance(to: paris) / 1000, 344, accuracy: 3)
    }

    func testTheDatasetIsAllThere() {
        XCTAssertGreaterThan(Gazetteer.count, 30_000)
        XCTAssertEqual(Gazetteer.all.count, Gazetteer.count)
        XCTAssertEqual(Set(Gazetteer.all.map(\.id)).count, Gazetteer.count, "ids are unique")
    }

    func testEveryZoneIsKnownToTheSystem() {
        // If this fails on an older OS, the fallback in City.timeZone is what
        // users of those cities get — worth knowing which.
        let zones = Set(Gazetteer.all.map(\.timeZoneIdentifier))
        let unknown = zones.filter { TimeZone(identifier: $0) == nil }.sorted()
        XCTAssertEqual(unknown, [], "zones this OS does not know")
    }

    func testAnUnknownZoneFallsBackToItsStandardOffset() {
        let zone = Zones.timeZone(for: "Made/Up", offsets: ["Made/Up": 19_800])
        XCTAssertEqual(zone.secondsFromGMT(), 19_800)
    }
}

final class DisplayTests: XCTestCase {

    func testDisplayNames() throws {
        let portland = try XCTUnwrap(Gazetteer.city(id: portlandOregon))
        XCTAssertEqual(portland.displayName, "Portland, Oregon, United States")
        XCTAssertEqual(portland.subtitle, "Oregon, United States")
        XCTAssertEqual(portland.flag, "🇺🇸")

        let london = try XCTUnwrap(Gazetteer.city(id: londonEngland))
        XCTAssertEqual(london.displayName, "London, England, United Kingdom")
    }

    func testARegionThatRepeatsTheCityIsLeftOut() throws {
        let tokyo = try XCTUnwrap(Gazetteer.search("tokyo").first)
        XCTAssertEqual(tokyo.displayName, "Tokyo, Japan")
        let singapore = try XCTUnwrap(Gazetteer.search("singapore").first)
        XCTAssertEqual(singapore.displayName, "Singapore")
    }

    func testCodableRoundTrip() throws {
        let city = try XCTUnwrap(Gazetteer.search("zurich").first)
        let decoded = try JSONDecoder().decode(City.self, from: JSONEncoder().encode(city))
        XCTAssertEqual(decoded, city)
    }
}

final class FoldingTests: XCTestCase {

    func testFolding() {
        XCTAssertEqual(Folding.fold("São Paulo"), "sao paulo")
        XCTAssertEqual(Folding.fold("Zürich"), "zurich")
        XCTAssertEqual(Folding.fold("  Saint-Denis  "), "saint denis")
        XCTAssertEqual(Folding.fold("N'Djamena"), "ndjamena")
        XCTAssertEqual(Folding.fold("Washington, D.C."), "washington dc")
        XCTAssertEqual(Folding.fold("København"), "kobenhavn")
        XCTAssertEqual(Folding.fold("Straße"), "strasse")
        XCTAssertEqual(Folding.fold("İstanbul"), "istanbul")
        XCTAssertEqual(Folding.fold("東京"), "")
    }

    func testReadings() {
        XCTAssertEqual(Matching.readings(of: "portland maine").map(\.name), ["portland maine", "portland"])
        XCTAssertEqual(Matching.readings(of: "portland, maine"), [.init(name: "portland", qualifier: ["maine"])])
    }
}

final class PerformanceTests: XCTestCase {

    /// The index loads outside the timed loop; this is search alone.
    func testTimings() {
        _ = Gazetteer.count

        let queries = ["l", "lon", "london", "portland maine", "san", "sao paulo", "new york", "zurich", "springfield il", "xqzzy"]
        let rounds = 20
        let start = Date()
        for _ in 0..<rounds {
            for query in queries { _ = Gazetteer.search(query) }
        }
        let perSearch = Date().timeIntervalSince(start) / Double(rounds * queries.count)
        print(String(format: "Cities timing: mean search %.3f ms", perSearch * 1000))
        XCTAssertLessThan(perSearch, 0.05, "a search should take well under 50 ms")
    }

    func testSearchPerformance() {
        _ = Gazetteer.count
        measure {
            for query in ["lon", "portland maine", "sao paulo", "s"] { _ = Gazetteer.search(query) }
        }
    }
}
