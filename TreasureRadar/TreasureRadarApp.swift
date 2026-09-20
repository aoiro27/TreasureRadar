import SwiftUI

@main
struct TreasureRadarApp: App {
    @State private var viewModel = RadarViewModel()

    var body: some Scene {
        WindowGroup {
            RadarScreen(viewModel: viewModel)
                .preferredColorScheme(.dark)
        }
    }
}
