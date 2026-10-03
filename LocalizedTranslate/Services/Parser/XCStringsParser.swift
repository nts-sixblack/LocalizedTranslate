//
//  XCStringsParser.swift
//  LocalizedTranslate
//
//  Created by Coordinator & Sub-Agent 1 on 10/4/26.
//

import Foundation

public enum CatalogParserError: LocalizedError {
    case fileNotFound(URL)
    case unreadableData(Error)
    case invalidEncoding
    case serializationError(Error)

    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found at: \(url.path)"
        case .unreadableData(let error):
            return "Failed to parse catalog JSON: \(error.localizedDescription)"
        case .invalidEncoding:
            return "Unable to decode catalog into UTF-8 text."
        case .serializationError(let error):
            return "Failed to serialize catalog: \(error.localizedDescription)"
        }
    }
}

public struct XCStringsParser {
    public static func load(from url: URL) throws -> StringCatalog {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw CatalogParserError.fileNotFound(url)
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw CatalogParserError.unreadableData(error)
        }

        do {
            let decoder = JSONDecoder()
            return try decoder.decode(StringCatalog.self, from: data)
        } catch {
            throw CatalogParserError.unreadableData(error)
        }
    }

    public static func save(
        _ catalog: StringCatalog,
        to url: URL,
        createBackup: Bool = true
    ) throws {
        if createBackup && FileManager.default.fileExists(atPath: url.path) {
            let backupUrl = url.deletingPathExtension()
                .appendingPathExtension("xcstrings.backup")
            try? FileManager.default.removeItem(at: backupUrl)
            try? FileManager.default.copyItem(at: url, to: backupUrl)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]

        let data: Data
        do {
            data = try encoder.encode(catalog)
        } catch {
            throw CatalogParserError.serializationError(error)
        }

        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw CatalogParserError.invalidEncoding
        }

        // Apple Xcode uses standard 2 spaces indentation with trailing newline
        let finalContent = jsonString.hasSuffix("\n") ? jsonString : jsonString + "\n"
        
        // In macOS App Sandbox, atomic write creates a temp file in the parent folder
        // which may fail if sandbox only granted access to the specific file. Fallback to direct write.
        do {
            try finalContent.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            try finalContent.write(to: url, atomically: false, encoding: .utf8)
        }
    }

    /// Extract all distinct languages available across the catalog
    public static func extractLanguages(from catalog: StringCatalog) -> [String] {
        var languages = Set<String>()
        languages.insert(catalog.sourceLanguage)
        for group in catalog.strings.values {
            if let localizations = group.localizations {
                for lang in localizations.keys {
                    languages.insert(lang)
                }
            }
        }
        return languages.sorted()
    }
}
