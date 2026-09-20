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

            if viewModel.isFound {
                foundOverlay
            }
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
            Text("トレジャーレーダー")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1, green: 0.86, blue: 0.32))
                .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
            Text(modeCaption)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var modeCaption: String {
        switch viewModel.session {
        case .hiding: "宝の電波を発信中"
        case .seeking: viewModel.settings.mode.title
        case .idle: "宝さがしのレーダー"
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

    private var foundOverlay: some View {
        VStack(spacing: 16) {
            Text("宝をみつけた！")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color(red: 1, green: 0.9, blue: 0.35))
            Text("すぐそばに電波があるよ")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            Button("つづける") {
                viewModel.continueHunting()
            }
            .font(.system(size: 18, weight: .black, design: .rounded))
            .padding(.horizontal, 28)
            .padding(.vertical, 12)
            .background(Color(red: 0.25, green: 0.72, blue: 0.28), in: Capsule())
            .foregroundStyle(.white)
        }
        .padding(28)
        .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(24)
        .transition(.scale.combined(with: .opacity))
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
