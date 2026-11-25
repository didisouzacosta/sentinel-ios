import SwiftUI

/// Every SentinelKit feature in one screen, to try the SDK against a Sentinel server.
struct PlaygroundView: View {

    // MARK: - Properties

    let viewModel: PlaygroundViewModel

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                SetupSection(viewModel: viewModel)
                ActionsSection(viewModel: viewModel)
                ActivitySection(activity: viewModel.activity)
            }
            .navigationTitle("SentinelKit")
        }
    }
}

#Preview("Not started") {
    PlaygroundView(viewModel: .previewNotStarted)
}

#Preview("Started") {
    PlaygroundView(viewModel: .previewStarted)
}
