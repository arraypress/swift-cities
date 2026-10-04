//
//  Naming.swift
//  Cities
//
//  Assembling the strings a picker shows.
//

import Foundation

enum Naming {

    /// The parts after the city, skipping any that repeat it: Tokyo is in
    /// the region Tokyo, Ho Chi Minh City in "Ho Chi Minh City (HCMC)", and
    /// Singapore in Singapore.
    static func context(of city: City) -> [String] {
        let name = Folding.fold(city.name)
        func repeatsName(_ part: String) -> Bool {
            let folded = Folding.fold(part)
            return folded == name || folded.hasPrefix(name + " ")
        }
        var parts: [String] = []
        if let region = city.regionName, !region.isEmpty, !repeatsName(region) {
            parts.append(region)
        }
        if !repeatsName(city.countryName) {
            parts.append(city.countryName)
        }
        return parts
    }

    /// `Portland, Oregon, United States`.
    static func displayName(of city: City) -> String {
        ([city.name] + context(of: city)).joined(separator: ", ")
    }

    /// `Oregon, United States` — the second line under the name.
    static func subtitle(of city: City) -> String {
        context(of: city).joined(separator: ", ")
    }

    /// 🇺🇸 — the two letters of the code shifted into the regional-indicator block.
    static func flag(for countryCode: String) -> String {
        let letters = countryCode.uppercased().unicodeScalars
        guard letters.count == 2, letters.allSatisfy({ $0.value >= 0x41 && $0.value <= 0x5A }) else { return "" }
        var flag = ""
        for letter in letters {
            if let indicator = Unicode.Scalar(0x1F1E6 + letter.value - 0x41) {
                flag.unicodeScalars.append(indicator)
            }
        }
        return flag
    }
}
