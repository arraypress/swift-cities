#!/usr/bin/env python3
"""
Rebuilds Sources/Cities/Resources/ from the GeoNames dump.

    python3 Scripts/build-cities.py                 # downloads into .geonames/
    python3 Scripts/build-cities.py --cache ~/geo   # or reuses a folder you already have

Reads, from https://download.geonames.org/export/dump/:

    cities15000.zip        every populated place over 15,000 people, and every capital
    admin1CodesASCII.txt   region names: "Oregon", "England", "Île-de-France"
    countryInfo.txt        country names and the languages each one speaks
    timeZones.txt          each IANA zone's standard offset, for the fallback
    alternateNamesV2.zip   other names, by language (~200 MB; only read, never shipped)

Writes four tab-separated files, UTF-8, no header rows:

    countries.tsv  code, name, aliases ("|"-joined, lowercase)
    regions.tsv    country code, admin1 code, name, abbreviation (may be empty)
    zones.tsv      IANA identifier, standard offset in seconds
    cities.tsv     geonameid, name, ascii name (empty when equal to name),
                   alternate names ("|"-joined), country code, admin1 code,
                   population, zone (row index into zones.tsv),
                   latitude, longitude (4 decimal places, ~11 m)

The data is GeoNames' (CC BY 4.0, https://www.geonames.org). The output is
sorted by geonameid, so a rebuild against an unchanged dump is byte-identical
and a rebuild against a new one diffs line by line.
"""

import argparse
import os
import sys
import unicodedata
import urllib.request
import zipfile

BASE = "https://download.geonames.org/export/dump/"
FILES = ["cities15000.zip", "admin1CodesASCII.txt", "countryInfo.txt",
         "timeZones.txt", "alternateNamesV2.zip"]

# Historical, abandoned, destroyed — not somewhere anyone lives now.
DROPPED_FEATURES = {"PPLH", "PPLQ", "PPLW"}

# At most this many alternate names per city. English first, then the
# country's own languages, preferred names before the rest.
MAX_ALTERNATES = 5
MAX_ALTERNATE_LENGTH = 40

# Names people type for a country that are not its GeoNames name.
COUNTRY_ALIASES = {
    "GB": ["uk", "united kingdom", "great britain", "britain"],
    "US": ["usa", "united states of america", "america"],
    "AE": ["uae"],
    "NL": ["holland", "the netherlands"],
    "CZ": ["czech republic"],
    "KR": ["korea"],
    "RU": ["russian federation"],
    "CI": ["cote d ivoire"],
    "MM": ["burma"],
    "SZ": ["swaziland"],
    "MK": ["macedonia"],
    "TR": ["turkiye"],
    "CV": ["cape verde"],
    "VA": ["vatican"],
    "PS": ["palestine"],
}

# The postal abbreviations people write after a city. US admin1 codes in
# GeoNames already ARE the postal codes; Canada's and Australia's are FIPS
# numbers, so theirs are keyed by name here.
REGION_ABBREVIATIONS = {
    ("CA", "Alberta"): "AB", ("CA", "British Columbia"): "BC",
    ("CA", "Manitoba"): "MB", ("CA", "New Brunswick"): "NB",
    ("CA", "Newfoundland and Labrador"): "NL", ("CA", "Nova Scotia"): "NS",
    ("CA", "Ontario"): "ON", ("CA", "Prince Edward Island"): "PE",
    ("CA", "Quebec"): "QC", ("CA", "Saskatchewan"): "SK",
    ("CA", "Yukon"): "YT", ("CA", "Northwest Territories"): "NT",
    ("CA", "Nunavut"): "NU",
    ("AU", "Australian Capital Territory"): "ACT", ("AU", "New South Wales"): "NSW",
    ("AU", "Northern Territory"): "NT", ("AU", "Queensland"): "QLD",
    ("AU", "South Australia"): "SA", ("AU", "Tasmania"): "TAS",
    ("AU", "Victoria"): "VIC", ("AU", "Western Australia"): "WA",
}

# Letters NFKD does not decompose. Same table as Support/Folding.swift, which
# folds every name again at load — here it only decides which alternates are
# worth keeping, so a disagreement costs a duplicate, never a missed match.
SPECIAL = {
    "ø": "o", "ß": "ss", "æ": "ae", "œ": "oe", "ł": "l", "đ": "d",
    "ð": "d", "þ": "th", "ı": "i", "ħ": "h", "ŧ": "t", "ŋ": "n",
}
# Dropped rather than spaced: "Xi'an" is typed "xian", "D.C." is typed "dc".
APOSTROPHES = set("'’ʻʼʿʾ`´.")


def fold(text):
    """Search key: lowercase ASCII words separated by single spaces."""
    out = []
    for ch in unicodedata.normalize("NFKD", text.lower()):
        if unicodedata.category(ch) == "Mn" or ch in APOSTROPHES:
            continue
        ch = SPECIAL.get(ch, ch)
        out.append(ch if (ch.isascii() and ch.isalnum()) else " ")
    return " ".join("".join(out).split())


def is_latin(text):
    """Whether every letter survives folding — i.e. it is typeable on a Latin keyboard."""
    for ch in unicodedata.normalize("NFKD", text.lower()):
        if unicodedata.category(ch) == "Mn" or ch in APOSTROPHES:
            continue
        ch = SPECIAL.get(ch, ch)
        if ch.isalpha() and not ch.isascii():
            return False
    return True


def fetch(cache):
    os.makedirs(cache, exist_ok=True)
    for name in FILES:
        path = os.path.join(cache, name)
        if not os.path.exists(path):
            print(f"downloading {name}…", file=sys.stderr)
            urllib.request.urlretrieve(BASE + name, path)


def lines(cache, name):
    """Yields the tab-split rows of a dump file, reading inside a zip if need be."""
    path = os.path.join(cache, name)
    if name.endswith(".zip"):
        inner = name.replace(".zip", ".txt")
        with zipfile.ZipFile(path) as archive:
            with archive.open(inner) as handle:
                for raw in handle:
                    line = raw.decode("utf-8").rstrip("\n")
                    if line and not line.startswith("#"):
                        yield line.split("\t")
    else:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                line = line.rstrip("\n")
                if line and not line.startswith("#"):
                    yield line.split("\t")


def main():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--cache", default=os.path.join(root, ".geonames"))
    parser.add_argument("--out", default=os.path.join(root, "Sources", "Cities", "Resources"))
    args = parser.parse_args()
    fetch(args.cache)

    # Countries, and the languages whose names count as "local".
    countries, languages = {}, {}
    for row in lines(args.cache, "countryInfo.txt"):
        countries[row[0]] = row[4]
        languages[row[0]] = {code.split("-")[0] for code in row[15].split(",") if code}

    regions = {}
    for row in lines(args.cache, "admin1CodesASCII.txt"):
        regions[row[0]] = row[1]

    offsets = {}
    for row in lines(args.cache, "timeZones.txt"):
        if row[0] == "CountryCode":
            continue
        offsets[row[1]] = int(round(float(row[4]) * 3600))

    cities = []
    for row in lines(args.cache, "cities15000.zip"):
        if row[7] in DROPPED_FEATURES or not row[17]:
            continue
        cities.append({
            "id": int(row[0]), "name": row[1], "ascii": row[2], "cc": row[8],
            "admin1": row[10], "population": int(row[14] or 0), "zone": row[17],
            "lat": float(row[4]), "lon": float(row[5]),
        })
    cities.sort(key=lambda city: city["id"])
    by_id = {city["id"]: city for city in cities}

    # Alternate names: one pass over 18 million rows, keeping the few that are
    # English or local, Latin-script, and different from the name already held.
    candidates = {}
    for row in lines(args.cache, "alternateNamesV2.zip"):
        geonameid = int(row[1])
        city = by_id.get(geonameid)
        if city is None:
            continue
        language, name = row[2], row[3]
        preferred, colloquial, historic = row[4] == "1", row[6] == "1", row[7] == "1"
        if colloquial or len(name) > MAX_ALTERNATE_LENGTH or not is_latin(name):
            continue
        if language == "en":
            rank = 0 if preferred else 1
        elif language in languages.get(city["cc"], ()) and not historic:
            rank = 2 if preferred else 3
        else:
            continue
        candidates.setdefault(geonameid, []).append((rank, int(row[0]), name))

    for city in cities:
        own = {fold(city["name"]), fold(city["ascii"])}
        seen = set(own)
        kept = []
        for _, _, name in sorted(candidates.get(city["id"], [])):
            key = fold(name)
            if not key or key in seen:
                continue
            # A long form that contains the name — "London Borough of Brent",
            # "City of Westminster" — finds nothing the name does not, and
            # makes "london" list Brent.
            if any(f" {word} " in f" {key} " for word in own):
                continue
            seen.add(key)
            kept.append(name.replace("|", " ").replace("\t", " "))
            if len(kept) == MAX_ALTERNATES:
                break
        city["alternates"] = kept

    zones = sorted({city["zone"] for city in cities})
    zone_index = {zone: index for index, zone in enumerate(zones)}
    used_regions = sorted({(city["cc"], city["admin1"]) for city in cities
                           if f'{city["cc"]}.{city["admin1"]}' in regions})
    used_countries = sorted({city["cc"] for city in cities})

    os.makedirs(args.out, exist_ok=True)

    def write(name, rows):
        with open(os.path.join(args.out, name), "w", encoding="utf-8", newline="\n") as handle:
            for row in rows:
                handle.write("\t".join(row) + "\n")

    write("countries.tsv", ([code, countries.get(code, code), "|".join(COUNTRY_ALIASES.get(code, []))]
                            for code in used_countries))
    write("regions.tsv", ([cc, admin1, regions[f"{cc}.{admin1}"],
                           admin1 if cc == "US" else REGION_ABBREVIATIONS.get((cc, regions[f"{cc}.{admin1}"]), "")]
                          for cc, admin1 in used_regions))
    write("zones.tsv", ([zone, str(offsets.get(zone, 0))] for zone in zones))
    write("cities.tsv", ([
        str(city["id"]), city["name"], "" if city["ascii"] == city["name"] else city["ascii"],
        "|".join(city["alternates"]), city["cc"], city["admin1"], str(city["population"]),
        str(zone_index[city["zone"]]), f'{city["lat"]:.4f}', f'{city["lon"]:.4f}',
    ] for city in cities))

    missing = [zone for zone in zones if zone not in offsets]
    print(f"{len(cities)} cities, {len(used_countries)} countries, {len(used_regions)} regions, "
          f"{len(zones)} zones, {sum(len(c['alternates']) for c in cities)} alternate names", file=sys.stderr)
    if missing:
        print(f"zones with no offset in timeZones.txt: {missing}", file=sys.stderr)


if __name__ == "__main__":
    main()
