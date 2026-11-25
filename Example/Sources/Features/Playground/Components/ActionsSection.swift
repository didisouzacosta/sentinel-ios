import SwiftUI

/// Consent, capture and crash buttons, enabled once the SDK is started.
struct ActionsSection: View {

    // MARK: - Properties

    let viewModel: PlaygroundViewModel

    // MARK: - Body

    var body: some View {
        Group {
            Section("Consent") {
                Button("Grant consent", action: viewModel.grantConsent)
                Button("Revoke consent", role: .destructive, action: viewModel.revokeConsent)
            }

            Section("Capture") {
                Button("Add breadcrumb", action: viewModel.addBreadcrumb)
                Button("Set custom parameter", action: viewModel.setPlan)
                Button("Capture error", action: viewModel.captureError)
                Button("Capture message", action: viewModel.captureMessage)
                Button("Flush queue", action: viewModel.requestFlush)
            }

            Section {
                Button("Crash: NSException", role: .destructive, action: viewModel.crashWithException)
                Button("Crash: fatalError", role: .destructive, action: viewModel.crashWithFatalError)
            } header: {
                Text("Crashes")
            } footer: {
                Text(
                    "Open the app again afterwards. NSException is sent on that launch; fatalError arrives through MetricKit, on a real device only."
                )
            }
        }
        .disabled(!viewModel.isStarted)
    }
}

#Preview {
    Form {
        ActionsSection(viewModel: .previewStarted)
    }
}
