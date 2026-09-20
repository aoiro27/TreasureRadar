import SwiftUI

struct SignalMeterView: View {
    var signal: LiveSignal?

    var body: some View {
        VStack(spacing: 8) {
            Text("ちかさパワー")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.6))
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(signal?.powerText ?? "—")
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(Color(red: 0.7, green: 1.0, blue: 0.62))
                    .contentTransition(.numericText())
                    .monospacedDigit()
                Text("/ 100")
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            strengthBar
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.28))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(red: 0.45, green: 0.98, blue: 0.42).opacity(0.22), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var strengthBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(Color(red: 0.45, green: 0.98, blue: 0.42))
                    .frame(width: proxy.size.width * (signal?.strength ?? 0))
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 6)
    }

    private var accessibilityText: String {
        guard let signal else { return "ちかさパワーなし" }
        return "ちかさパワー \(signal.power)"
    }
}
