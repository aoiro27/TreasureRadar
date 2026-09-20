import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: RadarViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("さがし方") {
                    Picker("モード", selection: $viewModel.settings.mode) {
                        ForEach(ScanSettings.Mode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(viewModel.settings.mode.subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("iBeacon") {
                    TextField("UUID", text: $viewModel.settings.uuidString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(.footnote, design: .monospaced))
                    if !viewModel.settings.isUUIDValid {
                        Text("UUIDの形が正しくありません")
                            .foregroundStyle(.red)
                    }
                    HStack {
                        Button("コピー") { viewModel.copyUUIDToPasteboard() }
                        Spacer()
                        Button("もとにもどす") { viewModel.resetUUID() }
                    }
                    TextField("Major（空ならすべて）", text: $viewModel.settings.majorText)
                        .keyboardType(.numberPad)
                    TextField("Minor（空ならすべて）", text: $viewModel.settings.minorText)
                        .keyboardType(.numberPad)
                }

                Section("Bluetoothのなまえ") {
                    TextField("発信側の名前", text: $viewModel.settings.bleName)
                    Text("nRF Connect などで名前を付けて発信する場合に使います。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("おと") {
                    Toggle("レーダー音", isOn: $viewModel.settings.soundEnabled)
                    Toggle("アナウンス", isOn: $viewModel.settings.voiceEnabled)
                    Button("アナウンスをためす") {
                        viewModel.previewVoice()
                    }
                    Text("さがす側はステータスが変わったときに「まだとおいよ」などを知らせます。かくす側は、探す人がすぐ近くまで来ると「やばい、ちかづいてきたー！」と声を出します。同じファイル名で差し替えできます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("せってい")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("とじる") {
                        viewModel.persistSettings()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                viewModel.persistSettings()
            }
        }
        .presentationDetents([.large])
    }
}
