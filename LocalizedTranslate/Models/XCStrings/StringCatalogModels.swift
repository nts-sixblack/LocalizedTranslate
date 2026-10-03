//
//  StringCatalogModels.swift
//  LocalizedTranslate
//
//  Created by Coordinator & Sub-Agent 1 on 10/4/26.
//

import Foundation

// MARK: - String Catalog Root
public final class StringCatalog: Codable, @unchecked Sendable {
    public var sourceLanguage: String
    public var version: String
    public var strings: [String: LocalizationGroup]

    public init(
        sourceLanguage: String = "en",
        version: String = "1.0",
        strings: [String: LocalizationGroup] = [:]
    ) {
        self.sourceLanguage = sourceLanguage
        self.version = version
        self.strings = strings
    }
}

// MARK: - Localization Group
public final class LocalizationGroup: Codable, @unchecked Sendable {
    public var comment: String?
    public var extractionState: String?
    public var localizations: [String: LocalizationUnit]?

    public init(
        comment: String? = nil,
        extractionState: String? = nil,
        localizations: [String: LocalizationUnit]? = nil
    ) {
        self.comment = comment
        self.extractionState = extractionState
        self.localizations = localizations
    }

    public func translation(for language: String) -> String? {
        localizations?[language]?.stringUnit?.value
    }

    public func state(for language: String) -> String? {
        localizations?[language]?.stringUnit?.state
    }

    public func setTranslation(_ value: String, for language: String, state: String = "translated") {
        if localizations == nil {
            localizations = [:]
        }
        if let existing = localizations?[language] {
            if let stringUnit = existing.stringUnit {
                stringUnit.value = value
                stringUnit.state = state
            } else {
                existing.stringUnit = StringUnit(state: state, value: value)
            }
        } else {
            localizations?[language] = LocalizationUnit(
                stringUnit: StringUnit(state: state, value: value)
            )
        }
    }
}

// MARK: - Localization Unit
public final class LocalizationUnit: Codable, @unchecked Sendable {
    public var stringUnit: StringUnit?
    public var variations: VariationsUnit?
    public var substitutions: [String: SubstitutionsUnit]?

    public var isSupportedFormat: Bool {
        variations == nil && substitutions == nil
    }

    public var hasTranslation: Bool {
        if let val = stringUnit?.value, !val.isEmpty {
            return true
        }
        if let variations = variations {
            if let plural = variations.plural, plural.hasAnyValue { return true }
            if let device = variations.device, device.hasAnyValue { return true }
        }
        return false
    }

    public init(
        stringUnit: StringUnit? = nil,
        variations: VariationsUnit? = nil,
        substitutions: [String: SubstitutionsUnit]? = nil
    ) {
        self.stringUnit = stringUnit
        self.variations = variations
        self.substitutions = substitutions
    }
}

// MARK: - String Unit
public final class StringUnit: Codable, @unchecked Sendable {
    public var state: String
    public var value: String

    public init(state: String = "translated", value: String) {
        self.state = state
        self.value = value
    }
}

// MARK: - Variations Unit
public final class VariationsUnit: Codable, @unchecked Sendable {
    public var plural: PluralVariation?
    public var device: DeviceVariation?

    public init(plural: PluralVariation? = nil, device: DeviceVariation? = nil) {
        self.plural = plural
        self.device = device
    }
}

// MARK: - Substitutions Unit
public final class SubstitutionsUnit: Codable, @unchecked Sendable {
    public var formatSpecifier: String
    public var variations: VariationsUnit

    public init(formatSpecifier: String, variations: VariationsUnit) {
        self.formatSpecifier = formatSpecifier
        self.variations = variations
    }
}

// MARK: - Plural Variation
public final class PluralVariation: Codable, @unchecked Sendable {
    public var zero: VariationStringUnit?
    public var one: VariationStringUnit?
    public var two: VariationStringUnit?
    public var few: VariationStringUnit?
    public var many: VariationStringUnit?
    public var other: VariationStringUnit?

    public var hasAnyValue: Bool {
        [zero, one, two, few, many, other].compactMap { $0?.stringUnit.value }.contains { !$0.isEmpty }
    }

    public init(
        zero: VariationStringUnit? = nil,
        one: VariationStringUnit? = nil,
        two: VariationStringUnit? = nil,
        few: VariationStringUnit? = nil,
        many: VariationStringUnit? = nil,
        other: VariationStringUnit? = nil
    ) {
        self.zero = zero
        self.one = one
        self.two = two
        self.few = few
        self.many = many
        self.other = other
    }

    public func allVariants() -> [(category: String, unit: VariationStringUnit)] {
        var list: [(String, VariationStringUnit)] = []
        if let zero = zero { list.append(("zero", zero)) }
        if let one = one { list.append(("one", one)) }
        if let two = two { list.append(("two", two)) }
        if let few = few { list.append(("few", few)) }
        if let many = many { list.append(("many", many)) }
        if let other = other { list.append(("other", other)) }
        return list
    }
}

// MARK: - Device Variation
public final class DeviceVariation: Codable, @unchecked Sendable {
    public var appletv: VariationStringUnit?
    public var applevision: VariationStringUnit?
    public var applewatch: VariationStringUnit?
    public var ipad: VariationStringUnit?
    public var iphone: VariationStringUnit?
    public var ipod: VariationStringUnit?
    public var mac: VariationStringUnit?
    public var other: VariationStringUnit?

    public var hasAnyValue: Bool {
        [appletv, applevision, applewatch, ipad, iphone, ipod, mac, other]
            .compactMap { $0?.stringUnit.value }.contains { !$0.isEmpty }
    }

    public init(
        appletv: VariationStringUnit? = nil,
        applevision: VariationStringUnit? = nil,
        applewatch: VariationStringUnit? = nil,
        ipad: VariationStringUnit? = nil,
        iphone: VariationStringUnit? = nil,
        ipod: VariationStringUnit? = nil,
        mac: VariationStringUnit? = nil,
        other: VariationStringUnit? = nil
    ) {
        self.appletv = appletv
        self.applevision = applevision
        self.applewatch = applewatch
        self.ipad = ipad
        self.iphone = iphone
        self.ipod = ipod
        self.mac = mac
        self.other = other
    }
}

// MARK: - Variation String Unit
public final class VariationStringUnit: Codable, @unchecked Sendable {
    public var stringUnit: StringUnit

    public init(stringUnit: StringUnit) {
        self.stringUnit = stringUnit
    }

    public init(state: String = "translated", value: String) {
        self.stringUnit = StringUnit(state: state, value: value)
    }
}
