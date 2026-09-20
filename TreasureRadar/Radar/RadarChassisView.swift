import SwiftUI

struct RadarChassisView<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.93, green: 0.72, blue: 0.18),
                            Color(red: 0.78, green: 0.52, blue: 0.08),
                            Color(red: 0.62, green: 0.38, blue: 0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .black.opacity(0.45), radius: 18, y: 10)

            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.45), Color.black.opacity(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 2
                )

            VStack(spacing: 14) {
                HStack {
                    Capsule()
                        .fill(Color.black.opacity(0.25))
                        .frame(width: 72, height: 10)
                    Spacer()
                    Circle()
                        .fill(Color(red: 0.35, green: 0.22, blue: 0.08))
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.black.opacity(0.4), lineWidth: 1))
                }
                .padding(.horizontal, 22)

                ZStack {
                    Circle()
                        .fill(Color(red: 0.08, green: 0.16, blue: 0.08))
                        .padding(6)
                        .shadow(color: .black.opacity(0.5), radius: 8, y: 4)

                    content
                        .padding(18)
                }
                .padding(.horizontal, 18)

                HStack(spacing: 16) {
                    ForEach(0..<5, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.black.opacity(0.28))
                            .frame(width: 18, height: 6)
                    }
                }
                .padding(.bottom, 10)
            }
            .padding(.vertical, 16)
        }
        .aspectRatio(0.92, contentMode: .fit)
    }
}
