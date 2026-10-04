//
//  Folding.swift
//  Cities
//
//  The one spelling every name and every query is compared in.
//

import Foundation

enum Folding {

    /// Letters a compatibility decomposition leaves alone. `ø` is not an `o`
    /// with a mark on it as far as Unicode is concerned, but it is to anybody
    /// typing "kobenhavn". Same table as `Scripts/build-cities.py`.
    private static let special: [Unicode.Scalar: String] = [
        "ø": "o", "ß": "ss", "æ": "ae", "œ": "oe", "ł": "l", "đ": "d",
        "ð": "d", "þ": "th", "ı": "i", "ħ": "h", "ŧ": "t", "ŋ": "n",
    ]

    /// Dropped, not spaced: "Xi'an" is typed "xian" and "D.C." is typed "dc".
    private static let dropped: Set<Unicode.Scalar> = ["'", "’", "ʻ", "ʼ", "ʿ", "ʾ", "`", "´", "."]

    /// Lowercase ASCII words separated by single spaces.
    ///
    /// `São Paulo` → `sao paulo`, `Zürich` → `zurich`, `Saint-Denis` →
    /// `saint denis`, `N'Djamena` → `ndjamena`. A letter with no Latin
    /// reading (Cyrillic, CJK) becomes a word break, so a non-Latin query
    /// folds to nothing and matches nothing rather than matching wrongly.
    static func fold(_ text: String) -> String {
        var out: [UInt8] = []
        out.reserveCapacity(text.utf8.count)
        var pendingSpace = false

        func emit(_ byte: UInt8) {
            if pendingSpace, !out.isEmpty { out.append(0x20) }
            pendingSpace = false
            out.append(byte)
        }

        func emitASCII(_ scalar: Unicode.Scalar) {
            let byte = UInt8(scalar.value)
            switch byte {
            case 0x61...0x7A, 0x30...0x39: emit(byte)          // a–z, 0–9
            case 0x41...0x5A: emit(byte + 0x20)                // A–Z
            default:
                if !dropped.contains(scalar) { pendingSpace = true }
            }
        }

        for scalar in text.unicodeScalars {
            if scalar.isASCII {
                emitASCII(scalar)
                continue
            }
            if dropped.contains(scalar) { continue }
            // The slow path, for the minority of characters that need it:
            // lowercase, decompose, drop the marks, map what is left.
            let decomposed = String(scalar).lowercased().decomposedStringWithCompatibilityMapping
            for part in decomposed.unicodeScalars {
                if part.properties.generalCategory == .nonspacingMark || dropped.contains(part) { continue }
                if let mapped = special[part] {
                    mapped.unicodeScalars.forEach(emitASCII)
                } else if part.isASCII {
                    emitASCII(part)
                } else {
                    pendingSpace = true
                }
            }
        }
        return String(decoding: out, as: UTF8.self)
    }
}
