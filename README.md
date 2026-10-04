# Swift Cities

Every city over 15,000 people, searchable offline, each with its time zone — the dataset behind a "pick a city" time-zone menu.

```swift
import Cities

let portland = Gazetteer.search("portland").first!
portland.displayName              // "Portland, Oregon, United States"
portland.timeZone                 // America/Los_Angeles

Gazetteer.search("portland maine").first!.timeZoneIdentifier   // "America/New_York"
Gazetteer.search("zurich").first!.name                         // "Zürich"
Gazetteer.search("london on").first!.displayName               // "London, Ontario, Canada"
```

## Why

`TimeZone.knownTimeZoneIdentifiers` names 443 zones, nearly all after a city. Somebody looking for Portland, Zürich without the umlaut, or London the one in Canada finds none of them there — and `Chrono.zone("Tokyo")` in [`swift-chrono-kit`](https://github.com/arraypress/swift-chrono-kit) can only match a city that *is* a zone name. This is the other 33,700: every populated place GeoNames lists at over 15,000 people, each with the IANA zone it keeps time in.

No network, no key, no geocoder. The whole list ships in the package as 2 MB of text, and loads on first use.

## Installation

```swift
.package(url: "https://github.com/arraypress/swift-cities.git", from: "0.1.0")
```

Foundation only. macOS 14+, iOS 17+, tvOS 17+, watchOS 10+, visionOS 1+. Swift 6.

## Searching

```swift
Gazetteer.search("sao paulo")         // São Paulo — case and diacritics folded
Gazetteer.search("kobenhavn")         // København — and ø, ß, æ, ł, which don't decompose
Gazetteer.search("kiev")              // Kyiv — by an English or historic name
Gazetteer.search("munchen")           // Munich — or the local one
Gazetteer.search("lon", limit: 5)     // London, Longyan, Londrina, …
```

Prefix matching, ranked in four tiers and then by population:

| Tier | `york` finds |
|---|---|
| The whole name, or a whole alternate name | York (England), York (Pennsylvania) |
| The start of the name | York University Heights, Yorkville, Yorkton |
| The start of an alternate name | — |
| The start of a later word | New York City, East New York, West New York |

So `portland` is Oregon (652,000) before Maine (67,000), and `york` is York before New York, which is fifty times the size but did not start with what you typed. Alternate names rank below real ones on a prefix because otherwise `san` lists Caracas — whose long form is *Santiago de León de Caracas* — above San Antonio.

## Narrowing it down

Anything after the city is read as its region or its country — by name, by abbreviation, or by code:

```swift
Gazetteer.search("portland maine")        // Portland, Maine
Gazetteer.search("Portland, ME")          // the same
Gazetteer.search("london ca")             // London, Ontario — CA is Canada's code
Gazetteer.search("london on")             // London, Ontario
Gazetteer.search("london uk")             // London, England
Gazetteer.search("buffalo new york")      // a region of two words
Gazetteer.search("washington dc")
Gazetteer.search("melbourne vic")         // Melbourne, Victoria
```

With a comma, the split is the writer's. Without one, every split is tried, the longest city name first: `new york` is New York City before it is "something starting *new* in a place starting *york*", and `portland maine` is first a city called that — there is none — then Portland, in Maine.

US states match by postal code because GeoNames' region codes for the US already are them. Canadian provinces and Australian states have their abbreviations added by the build script (`ON`, `BC`, `NSW`, `VIC`); everywhere else matches by region name.

## Zones, places, and stored choices

```swift
Gazetteer.cities(in: TimeZone(identifier: "Asia/Tokyo")!)   // Tokyo, Yokohama, Osaka, … — most populous first
Gazetteer.cities(inZone: "Europe/London").first             // London
Gazetteer.cities(inCountry: "CH").first                     // Zürich

Gazetteer.nearest(latitude: 51.508, longitude: -0.128)      // London
Gazetteer.nearest(latitude: 43.66, longitude: -70.26, minimumPopulation: 50_000)

Gazetteer.city(id: 5746545)                                 // Portland, Oregon — by GeoNames id
```

Store a choice by `id`. GeoNames ids are stable across releases; names and populations are not.

## The model

`City` is GeoNames' fields and nothing else: `id`, `name`, `asciiName`, `alternateNames`, `countryCode`, `countryName`, `regionName`, `population`, `timeZoneIdentifier`, `latitude`, `longitude`. It is `Sendable`, `Hashable`, `Codable` and `Identifiable`.

The rest is derived:

```swift
city.timeZone          // TimeZone — never nil, see below
city.displayName       // "Portland, Oregon, United States"; "Tokyo, Japan"; "Singapore"
city.subtitle          // "Oregon, United States" — the second line of a list row
city.flag              // "🇺🇸"
city.distance(to: other)                   // metres, great circle
```

A region that only repeats the city is left out, which is why it is "Tokyo, Japan" and not "Tokyo, Tokyo, Japan".

`timeZone` falls back to a fixed zone at the standard offset when the operating system does not know the identifier — a zone newer than the OS, such as `America/Ciudad_Juarez` (2022). On this machine every one of the 356 zones resolves; the fallback is for older releases, and it is right on the hour everywhere outside daylight saving rather than silently UTC.

## What is in it

Measured from the GeoNames dump of 4 October 2026:

| | |
|---|---|
| Cities | 34,125 |
| Countries | 244 |
| Regions (first-level) | 2,764 |
| Time zones | 356 |
| Alternate names | 5,070 |
| Bundled size | 1.99 MB as plain text (0.84 MB gzipped, as git stores it) |

Every populated place GeoNames lists at over 15,000 people, plus every capital, including city districts it lists as places in their own right (Kowloon, Shibuya, Navi Mumbai). Historical, abandoned and destroyed places are dropped.

Alternate names are capped at five per city and kept only if they are Latin-script and differ from the name: English names first, preferred before the rest, historic ones included (`Bombay`, `Saigon`, `Kiev`); then names in the country's own languages (`München`, `Wien`). Long forms that merely contain the name — "London Borough of Brent" — are dropped, because they make `london` list Brent.

## What is not

- **Places under 15,000.** That is GeoNames' threshold, and the size of the list. GeoNames also publishes 5,000, 1,000 and 500 cut-offs; the build script takes a different one by changing a file name, at a multiple of the size.
- **Non-Latin search.** `東京` finds nothing — deliberately nothing, rather than a wrong match. Names are kept in Latin script only, which is what keeps the file at 2 MB.
- **Abbreviations.** `NYC`, `LA`, `SF` are not names; `la` finds Los Angeles only because it is the biggest place starting "La".
- **Typos.** Prefix matching, not fuzzy matching. `zurihc` finds nothing.
- **Zone aliases.** `cities(inZone: "US/Pacific")` is empty; GeoNames uses canonical identifiers (`America/Los_Angeles`, `Asia/Kolkata`).
- **Current time, offsets, abbreviations.** That is `swift-chrono-kit`, which takes the `TimeZone` this hands back.

## Speed

Measured in a release build on an Apple-silicon Mac:

| | |
|---|---|
| First use — read, parse and index 34,125 cities | 120 ms |
| A typical search (`london`, `portland maine`, `zurich`) | 0.002–0.02 ms |
| A short, broad prefix (`san`, `new york`) | 0.07–0.15 ms |
| One letter (`s`) | 0.5 ms |
| `nearest` — a straight scan | 0.7 ms |

Search is a binary search into one sorted table of folded keys, so it is fast enough to run on every keystroke. The load happens once, on whichever thread asks first; call `Gazetteer.count` early on a background task if 120 ms on the main thread matters.

## Regenerating the data

```sh
python3 Scripts/build-cities.py
```

Downloads the five GeoNames files into `.geonames/` (about 210 MB, mostly the alternate names, which are read and never shipped), and rewrites `Sources/Cities/Resources/`. `--cache DIR` reuses files you already have. Output is sorted by GeoNames id, so a rebuild against the same dump is byte-identical and one against a new dump diffs city by city. Python 3, standard library only.

## Data license and attribution

The city data is from [GeoNames](https://www.geonames.org), licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). If you ship it, credit GeoNames — for example *"Contains data from GeoNames (geonames.org), CC BY 4.0"* in your about screen. See [LICENSE-DATA](LICENSE-DATA) for the source files and what the build script changes.

## License

Code: MIT — see [LICENSE](LICENSE). Data: CC BY 4.0 — see [LICENSE-DATA](LICENSE-DATA).
