import SwiftUI

enum Theme {
    // Neutrals
    static let background = Color(red: 0.965, green: 0.961, blue: 0.945)
    static let surface = Color.white
    static let surfaceRaised = Color(red: 0.937, green: 0.933, blue: 0.918)
    static let stroke = Color.black.opacity(0.07)
    static let track = Color.black.opacity(0.06)
    static let textPrimary = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let textSecondary = Color(red: 0.08, green: 0.08, blue: 0.08).opacity(0.6)
    static let textTertiary = Color(red: 0.08, green: 0.08, blue: 0.08).opacity(0.38)

    /// Filled controls (primary button, selected tiles) are ink, not color.
    static let ink = textPrimary
    static let onInk = Color.white

    /// The one accent: score ring, progress and checkmarks.
    static let accent = Color(red: 0.12, green: 0.45, blue: 0.33)
    /// Only for check-ins that cost points.
    static let warning = Color(red: 0.76, green: 0.32, blue: 0.24)

    static let ring = accent

    static func color(for pillar: Pillar) -> Color { accent }

    /// One hue at three strengths instead of a traffic light.
    static func scoreColor(_ score: Int) -> Color {
        switch score {
        case 80...: accent
        case 60..<80: accent.opacity(0.6)
        default: accent.opacity(0.3)
        }
    }
}

extension Font {
    static func display(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

struct AppBackground: View {
    var body: some View {
        Theme.background.ignoresSafeArea()
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.stroke))
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var enabled = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(enabled ? Theme.onInk : Theme.textTertiary)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(enabled ? Theme.ink : Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium, design: .rounded))
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(enabled: Bool) -> PrimaryButtonStyle { PrimaryButtonStyle(enabled: enabled) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
