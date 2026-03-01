//
//  StormHelpers.swift
//  DesktopHomeInfoScraper
//
//  Loads and parses storms.md for the Named Storm dropdown.
//

import Foundation

struct KnownStorm: Identifiable {
    let id = UUID()
    let name: String
    let date: Date
}

enum StormHelpers {
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d/yyyy"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// Known storms from bundle storms.md: (name, date). Returns empty array if file missing or parse fails.
    static func loadKnownStorms() -> [KnownStorm] {
        guard let url = Bundle.main.url(forResource: "storms", withExtension: "md"),
              let content = try? String(contentsOf: url, encoding: .utf8) else {
            print("MYDEBUG → storms.md not found in bundle")
            return []
        }
        let lines = content.components(separatedBy: .newlines)
        var result: [KnownStorm] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            if trimmed.lowercased().hasPrefix("storm name") || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count >= 2 else { continue }
            let name = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let dateString = String(parts[1]).trimmingCharacters(in: .whitespaces)
            guard let date = dateFormatter.date(from: dateString) else { continue }
            result.append(KnownStorm(name: name, date: date))
        }
        return result
    }
}
