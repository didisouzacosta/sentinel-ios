import SwiftUI

@main
struct SentinelExampleApp: App {

    // MARK: - Properties

    @State private var viewModel = PlaygroundViewModel(
        service: LiveSentinelService(),
        storage: UserDefaultsDSNStorage()
    )

    // MARK: - Initializer

    init() {
        // Starting at launch matters after a crash: the report written by the crash handler is sent on this start.
        if let dsn = UserDefaultsDSNStorage().savedDSN {
            LiveSentinelService().start(dsn: dsn)
        }
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            PlaygroundView(viewModel: viewModel)
        }
    }
}
