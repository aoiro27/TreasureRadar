import SwiftUI

struct HowToView: View {
    let uuid: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    step(number: "1", title: "かくすスマホを用意する", body: "もう1台のスマホで Beacon Simulator などのアプリを開きます。iPhone同士なら、このアプリの『かくす』でも発信できます。")
                    step(number: "2", title: "同じUUIDにする", body: "発信側のビーコン種類は iBeacon にします。UUID は下の値をそのまま使ってください。Major / Minor は 1 がかんたんです。")

                    Text(uuid)
                        .font(.system(.footnote, design: .monospaced))
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        .textSelection(.enabled)

                    step(number: "3", title: "発信を開始して隠す", body: "発信をオンにしたまま、机の下やクッションの陰などにスマホを隠します。画面は消えても大丈夫ですが、発信が止まらないように電池とBluetoothはオンのままにしてください。探す人がすぐ近くまで来ると、隠しているスマホが「やばい、ちかづいてきたー！」と声を出します。")
                    step(number: "4", title: "レーダーで探す", body: "探す側で『さがす』を押します。近いほど赤い点は中央に寄り、音の間隔も短くなります。「まだとおいよ」「ちかづいてきたよ」などの声でも知らせます。Bluetoothは方向までは分からないので、点の位置ではなく距離の変化を頼りにしてください。")
                    step(number: "5", title: "うまく見つからないとき", body: "UUIDが同じか、位置情報とBluetoothの許可がオンか、発信側の画面が落ちて発信が止まっていないかを見てください。実機での確認が必要です。シミュレータでは『れんしゅう』モードを使います。")
                }
                .padding(20)
            }
            .navigationTitle("つかいかた")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("とじる") { dismiss() }
                }
            }
        }
    }

    private func step(number: String, title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(number). \(title)")
                .font(.system(.headline, design: .rounded))
            Text(body)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }
}
