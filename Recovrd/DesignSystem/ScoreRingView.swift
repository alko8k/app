import SwiftUI

/// The recurring visual motif: a gradient ring with a counting number.
struct ScoreRingView: View {
    var score: Int
    var potential: Int? = nil
    var size: CGFloat = 220
    var lineWidth: CGFloat = 18
    var caption: String? = "out of 100"
    /// When true the ring sweeps from 0 on first appear.
    var animateIn = true

    @State private var progress: Double = 0
    @State private var shown: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.track, lineWidth: lineWidth)

            if let potential, potential > score {
                Circle()
                    .trim(from: 0, to: Double(potential) / 100)
                    .stroke(Theme.accent.opacity(0.18), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Theme.ring, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                CountingText(value: shown)
                    .font(.display(size * 0.32, weight: .heavy))
                    .foregroundStyle(Theme.textPrimary)
                    .monospacedDigit()
                if let caption {
                    Text(caption)
                        .font(.system(size: max(12, size * 0.06), weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Score \(score) out of 100")
        .onAppear { animate(to: score, delay: animateIn ? 0.15 : 0, instant: !animateIn) }
        .onChange(of: score) { _, new in animate(to: new, delay: 0, instant: false) }
    }

    private func animate(to value: Int, delay: Double, instant: Bool) {
        if instant {
            progress = Double(value) / 100
            shown = Double(value)
            return
        }
        withAnimation(.spring(response: 1.4, dampingFraction: 0.85).delay(delay)) {
            progress = Double(value) / 100
        }
        withAnimation(.easeOut(duration: 1.2).delay(delay)) {
            shown = Double(value)
        }
    }
}

/// Interpolates the number itself so it visibly counts up.
struct CountingText: View, Animatable {
    var value: Double
    var animatableData: Double {
        get { value }
        set { value = newValue }
    }
    var body: some View {
        Text("\(Int(value.rounded()))")
    }
}
