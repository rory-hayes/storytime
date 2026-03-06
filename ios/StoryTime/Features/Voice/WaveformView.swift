import SwiftUI

struct WaveformView: View {
    let speaker: VoiceSpeaker
    let phase: CGFloat
    let childLevel: CGFloat
    let aiLevel: CGFloat

    // Symmetric bar profile inspired by a single center waveform icon.
    private let profile: [CGFloat] = [0.30, 0.58, 1.00, 0.55, 0.24, 0.55, 1.00, 0.58, 0.30]

    var body: some View {
        GeometryReader { proxy in
            HStack(alignment: .center, spacing: interBarSpacing(for: proxy.size.width)) {
                ForEach(profile.indices, id: \.self) { index in
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.92))
                        .frame(
                            width: barWidth(for: proxy.size.width),
                            height: barHeight(for: index, maxHeight: proxy.size.height)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 126)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 1)
        )
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.80), value: childLevel)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.80), value: aiLevel)
        .animation(.linear(duration: 0.08), value: phase)
    }

    private var activeLevel: CGFloat {
        switch speaker {
        case .child:
            return max(0.03, min(1, childLevel))
        case .ai:
            return max(0.03, min(1, aiLevel))
        case .idle:
            return max(0.02, min(1, max(childLevel, aiLevel) * 0.45))
        }
    }

    private func barHeight(for index: Int, maxHeight: CGFloat) -> CGFloat {
        let minHeight: CGFloat = 20
        let maxDynamic = max(24, maxHeight - 10)
        let wavePulse = speaker == .idle
            ? 0.72
            : 0.55 + (0.45 * abs(sin((phase * 1.8) + (CGFloat(index) * 0.9))))
        let dynamic = (maxDynamic - minHeight) * profile[index] * activeLevel * wavePulse
        return min(maxDynamic, max(minHeight, minHeight + dynamic))
    }

    private func barWidth(for totalWidth: CGFloat) -> CGFloat {
        let proposed = totalWidth * 0.055
        return min(16, max(10, proposed))
    }

    private func interBarSpacing(for totalWidth: CGFloat) -> CGFloat {
        let proposed = totalWidth * 0.030
        return min(14, max(8, proposed))
    }
}
