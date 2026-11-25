import SwiftUI

/// DSN field, start button and a way to forget the DSN.
struct SetupSection: View {

    // MARK: - Properties

    @Bindable var viewModel: PlaygroundViewModel

    // MARK: - Body

    var body: some View {
        Section {
            TextField("https://<key>@<host>/<project id>", text: $viewModel.dsn, axis: .vertical)
                .font(.footnote.monospaced())
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .disabled(viewModel.isStarted)
                .accessibilityIdentifier("dsn-field")

            Button(viewModel.isStarted ? "Started" : "Start SentinelKit", action: viewModel.start)
                .disabled(!viewModel.canStart)
                .accessibilityIdentifier("start-button")

            if viewModel.hasSavedDSN {
                Button("Forget DSN", role: .destructive, action: viewModel.forgetDSN)
            }
        } header: {
            Text("DSN")
        } footer: {
            Text("Sentinel → Project settings → Client keys. Saved for the next launches.")
        }
    }
}

#Preview {
    Form {
        SetupSection(viewModel: .previewNotStarted)
    }
}
