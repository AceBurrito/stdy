// Theme.swift
// Steady — shared visual tokens ("Training log" direction, Nov 2026).
//
// Principles:
// - Flat graphite layers that differ clearly in tone. No glows, no decorative gradients.
// - Large tabular numbers, small uppercase tracked labels.
// - Color carries state and data only. Teal = primary, coral = accent/alert, amber = caution.
//
// Legacy color names (atlas*) are kept on purpose: the brand rename is still TBD.

import SwiftUI

// MARK: - Brand Colors

extension Color {
    // Palette (unchanged from Atlas)
    static let atlasPrimary = Color(hex: "#5BA4A4")      // Teal
    static let atlasAccent = Color(hex: "#E07856")       // Coral
    static let atlasAmber = Color(hex: "#FFC26A")        // Amber
    static let steadyGreen = Color(hex: "#7CC48A")       // "Ready to Crush" only

    // Surfaces: three clearly separated graphite steps
    static let atlasBackground = Color(hex: "#0F1011")   // Base (was #1C1C1E)
    static let atlasCardDark = Color(hex: "#1D2023")     // Panel, a clear step up from base
    static let steadyRaised = Color(hex: "#292D31")      // Raised control / selected row
    static let steadyHairline = Color.white.opacity(0.10)

    // Text
    static let atlasText = Color(hex: "#F2F1EE")         // Warm white
    static let atlasTextMuted = Color(hex: "#8E9093")
    static let steadyTextFaint = Color(hex: "#5C5F63")
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Type

enum SteadyType {
    /// Small uppercase section label, e.g. "TODAY'S TRAINING"
    static let label = Font.system(size: 11, weight: .semibold)
    /// Body copy
    static let body = Font.system(size: 15, weight: .regular)
    static let bodyEmphasis = Font.system(size: 15, weight: .semibold)
    static let caption = Font.system(size: 12, weight: .regular)
    static let title = Font.system(size: 20, weight: .semibold)

    /// Condensed display face for hero words and numbers (recovery state, big metrics)
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }

    /// Tabular figures so columns of numbers line up
    static func metric(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}

// MARK: - Modifiers

extension View {
    /// Uppercase tracked label in the muted text color.
    func steadyLabel(_ color: Color = .atlasTextMuted) -> some View {
        self.font(SteadyType.label)
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundColor(color)
    }

    /// Section title at the top of a panel: one step brighter than the labels
    /// inside it, so "BODY" reads above "WEIGHT". Never colored.
    func steadySectionHeader() -> some View {
        self.font(.system(size: 12, weight: .bold))
            .tracking(1.4)
            .textCase(.uppercase)
            .foregroundColor(.atlasText.opacity(0.88))
    }

    /// Standard panel: flat graphite fill with a hairline edge.
    func steadyPanel(padding: CGFloat = 16) -> some View {
        self.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.atlasCardDark)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.steadyHairline, lineWidth: 1)
            )
    }
}

// MARK: - Buttons

/// Solid primary action. Square-ish corners, no shadow.
struct SteadyPrimaryButtonStyle: ButtonStyle {
    var tint: Color = .atlasPrimary

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SteadyType.bodyEmphasis)
            .foregroundColor(.atlasBackground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(tint.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

/// Outlined secondary action.
struct SteadySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(SteadyType.bodyEmphasis)
            .foregroundColor(.atlasText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.steadyRaised.opacity(configuration.isPressed ? 1 : 0.6))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.steadyHairline, lineWidth: 1)
            )
    }
}

// MARK: - Text Field

struct atlasTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .foregroundColor(.atlasText)
            .padding(14)
            .background(Color.steadyRaised)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.steadyHairline, lineWidth: 1)
            )
    }
}

// MARK: - Option Row (single-select list, used by onboarding and settings)

struct SteadyOptionRow: View {
    let title: String
    var subtitle: String? = nil
    var icon: String? = nil
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(isSelected ? .atlasPrimary : .atlasTextMuted)
                        .frame(width: 24)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(SteadyType.bodyEmphasis)
                        .foregroundColor(.atlasText)
                    if let subtitle {
                        Text(subtitle)
                            .font(SteadyType.caption)
                            .foregroundColor(.atlasTextMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? .atlasPrimary : .steadyTextFaint)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Color.steadyRaised : Color.atlasCardDark)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.atlasPrimary.opacity(0.6) : Color.steadyHairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Segmented Control

struct SteadySegmented<Option: Hashable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                Button { selection = option } label: {
                    Text(title(option))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(selection == option ? .atlasText : .atlasTextMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(selection == option ? Color.steadyRaised : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(2)
        .background(Color.atlasBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(Color.steadyHairline, lineWidth: 1))
    }
}
