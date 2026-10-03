//
//  RaycastTheme.swift
//  LocalizedTranslate
//
//  Created by Coordinator & Sub-Agent 4 on 10/4/26.
//

import SwiftUI

// MARK: - Color Hex Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let alphaVal, redVal, greenVal, blueVal: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (alphaVal, redVal, greenVal, blueVal) = (
                255,
                (int >> 8) * 17,
                (int >> 4 & 0xF) * 17,
                (int & 0xF) * 17
            )
        case 6: // RGB (24-bit)
            (alphaVal, redVal, greenVal, blueVal) = (
                255,
                int >> 16,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        case 8: // ARGB (32-bit)
            (alphaVal, redVal, greenVal, blueVal) = (
                int >> 24,
                int >> 16 & 0xFF,
                int >> 8 & 0xFF,
                int & 0xFF
            )
        default:
            (alphaVal, redVal, greenVal, blueVal) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(redVal) / 255,
            green: Double(greenVal) / 255,
            blue: Double(blueVal) / 255,
            opacity: Double(alphaVal) / 255
        )
    }
}

// MARK: - Raycast Design System Color Tokens
public struct RaycastTheme {
    // Surfaces
    public static let canvas = Color(hex: "#07080a")
    public static let surface = Color(hex: "#0d0d0d")
    public static let surfaceElevated = Color(hex: "#101111")
    public static let surfaceCard = Color(hex: "#121212")

    // Borders & Hairlines
    public static let hairline = Color(hex: "#242728")
    public static let hairlineStrong = Color.white.opacity(0.16)

    // Text & Foregrounds
    public static let ink = Color(hex: "#f4f4f6")
    public static let body = Color(hex: "#cdcdcd")
    public static let mute = Color(hex: "#9c9c9d")
    public static let ash = Color(hex: "#6a6b6c")

    // Primary CTA
    public static let primaryWhite = Color(hex: "#ffffff")
    public static let primaryPressed = Color(hex: "#e8e8e8")
    public static let onPrimaryBlack = Color.black

    // Semantics
    public static let accentBlue = Color(hex: "#57c1ff")
    public static let accentGreen = Color(hex: "#59d499")
    public static let accentYellow = Color(hex: "#ffc533")
    public static let accentRed = Color(hex: "#ff6161")
}

// MARK: - Keycap Glyph Badge Component
public struct KeycapBadge: View {
    public let key: String

    public init(_ key: String) {
        self.key = key
    }

    public var body: some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(RaycastTheme.mute)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(RaycastTheme.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(RaycastTheme.hairline, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Raycast Pill Primary Button
public struct RaycastPillButton: View {
    public let title: String
    public let icon: String?
    public let action: () -> Void

    public init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(RaycastTheme.onPrimaryBlack)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(RaycastTheme.primaryWhite)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Raycast Secondary Button
public struct RaycastSecondaryButton: View {
    public let title: String
    public let icon: String?
    public let action: () -> Void

    public init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(RaycastTheme.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(RaycastTheme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(RaycastTheme.hairline, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Status Pill Badge
public struct StatusPill: View {
    public let title: String
    public let color: Color
    public let icon: String?

    public init(title: String, color: Color, icon: String? = nil) {
        self.title = title
        self.color = color
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
            }
            Text(title)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(color.opacity(0.12))
                .overlay(
                    Capsule().stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}
