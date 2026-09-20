import SwiftUI

struct RadarScreen: View {
    @Bindable var viewModel: RadarViewModel

    var body: some View {
        ZStack {
            background
            VStack(spacing: 18) {
                header
                Spacer(minLength: 0)
                RadarChassisView {
                    DragonRadarView(
                        treasures: viewModel.treasures,
                        isScanning: viewModel.isScanning,
                        isFound: viewModel.isFound,
                        onTick: viewModel.tick(now:)
                    )
                }
                .padding(.horizontal, 22)

                statusPanel
                controls
                utilityRow
            }
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsView(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.showHowTo) {
            HowToView(uuid: viewModel.settings.uuidString)
        }
        .onDisappear {
            viewModel.stopAll()
        }
    }

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.09, green: 0.12, blue: 0.08),
                Color(red: 0.05, green: 0.06, blue: 0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
        .overlay {
            RadialGradient(
                colors: [Color(red: 0.35, green: 0.28, blue: 0.04).opacity(0.35), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("しきしろレーダー")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1, green: 0.86, blue: 0.32))
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            HStack(spacing: 8) {
                if let link = viewModel.rangingLink {
                    rangingBadge(link)
                }
                Text(modeCaption)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }

    private func rangingBadge(_ link: RangingLink) -> some View {
        let tint = link == .uwb
            ? Color(red: 0.45, green: 0.85, blue: 1.0)
            : Color(red: 0.55, green: 1.0, blue: 0.48)
        return Text(link.rawValue)
            .font(.system(size: 12, weight: .black, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.18), in: Capsule())
            .overlay(Capsule().stroke(tint.opacity(0.55), lineWidth: 1))
            .accessibilityLabel(link == .uwb ? "UWBで探しています" : "BLEで探しています")
    }

    private var modeCaption: String {
        switch viewModel.session {
        case .hiding: "しきしろの電波を発信中"
        case .seeking: viewModel.settings.mode.title
        case .idle: "しきしろさがしのレーダー"
        }
    }

    private var statusPanel: some View {
        VStack(spacing: 6) {
            Text(viewModel.proximityLabel)
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.55, green: 1.0, blue: 0.48))
            Text(viewModel.statusMessage)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.75))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            SignalMeterView(signal: viewModel.liveSignal)
                .padding(.horizontal, 20)
        }
        .frame(minHeight: 58)
    }

    private var controls: some View {
        HStack(spacing: 12) {
            RadarActionButton(
                title: viewModel.isScanning ? "とめる" : "さがす",
                systemImage: viewModel.isScanning ? "stop.fill" : "dot.radiowaves.left.and.right",
                tint: Color(red: 0.25, green: 0.72, blue: 0.28)
            ) {
                if viewModel.isScanning {
                    viewModel.stopAll()
                } else {
                    viewModel.startSeeking()
                }
            }

            RadarActionButton(
                title: viewModel.isHiding ? "とめる" : "かくす",
                systemImage: viewModel.isHiding ? "stop.fill" : "antenna.radiowaves.left.and.right",
                tint: Color(red: 0.86, green: 0.52, blue: 0.12)
            ) {
                if viewModel.isHiding {
                    viewModel.stopAll()
                } else {
                    viewModel.startHiding()
                }
            }
        }
        .padding(.horizontal, 20)
    }

    private var utilityRow: some View {
        HStack(spacing: 18) {
            Button {
                viewModel.settings.soundEnabled.toggle()
                viewModel.persistSettings()
            } label: {
                Label(
                    viewModel.settings.soundEnabled ? "おと ON" : "おと OFF",
                    systemImage: viewModel.settings.soundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill"
                )
            }

            Button {
                viewModel.showHowTo = true
            } label: {
                Label("つかいかた", systemImage: "questionmark.circle.fill")
            }

            Button {
                viewModel.showSettings = true
            } label: {
                Label("せってい", systemImage: "gearshape.fill")
            }
        }
        .font(.system(size: 13, weight: .bold, design: .rounded))
        .foregroundStyle(.white.opacity(0.82))
        .labelStyle(.titleAndIcon)
    }
}

private struct RadarActionButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 58)
                .foregroundStyle(.white)
                .background(tint, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .shadow(color: tint.opacity(0.4), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
    }
}
