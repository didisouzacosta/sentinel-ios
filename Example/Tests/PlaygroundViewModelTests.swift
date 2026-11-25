import Foundation
import Testing
@testable import SentinelExample

@Suite("Playground view model")
@MainActor
struct PlaygroundViewModelTests {

    // MARK: - Helpers

    private let dsn = "https://key@sentinel.example.com/1"

    private func makeHarness(saved: String? = nil) -> Harness {
        let service = SpySentinelService()
        let storage = InMemoryDSNStorage(savedDSN: saved)

        return Harness(
            viewModel: PlaygroundViewModel(service: service, storage: storage),
            service: service,
            storage: storage
        )
    }

    // MARK: - Setup

    @Test("cannot start without a DSN", arguments: ["", "   ", "\n"])
    func blankDSN(_ text: String) {
        let harness = makeHarness()
        let viewModel = harness.viewModel
        let service = harness.service

        viewModel.dsn = text
        viewModel.start()

        #expect(!viewModel.canStart)
        #expect(!viewModel.isStarted)
        #expect(service.calls.isEmpty)
    }

    @Test("starts once with the trimmed DSN and saves it for the next launches")
    func start() {
        let harness = makeHarness()
        let viewModel = harness.viewModel
        let service = harness.service
        let storage = harness.storage

        viewModel.dsn = "  \(dsn)\n"
        viewModel.start()
        viewModel.start()

        #expect(viewModel.isStarted)
        #expect(viewModel.dsn == dsn)
        #expect(storage.savedDSN == dsn)
        #expect(viewModel.hasSavedDSN)
        #expect(service.calls == ["start \(dsn)"])
    }

    @Test("with a saved DSN opens started, without starting again (the app did at launch)")
    func savedDSN() {
        let harness = makeHarness(saved: dsn)
        let viewModel = harness.viewModel
        let service = harness.service

        #expect(viewModel.isStarted)
        #expect(viewModel.dsn == dsn)
        #expect(!viewModel.canStart)
        #expect(service.calls.isEmpty)
    }

    @Test("forgetting the DSN clears it for the next launch, once")
    func forget() {
        let harness = makeHarness(saved: dsn)
        let viewModel = harness.viewModel
        let storage = harness.storage

        viewModel.forgetDSN()
        viewModel.forgetDSN()

        #expect(storage.savedDSN == nil)
        #expect(!viewModel.hasSavedDSN)
        #expect(viewModel.activity.count == 1)
    }

    // MARK: - Actions

    @Test("each action calls SentinelKit and is listed in the activity, newest first")
    func actions() async {
        let harness = makeHarness(saved: dsn)
        let viewModel = harness.viewModel
        let service = harness.service

        viewModel.grantConsent()
        viewModel.addBreadcrumb()
        viewModel.setPlan()
        viewModel.captureError()
        viewModel.captureMessage()
        await viewModel.flush()
        viewModel.revokeConsent()

        #expect(service.calls == [
            "grantConsent",
            "breadcrumb ui Tapped Pay",
            "custom plan=pro",
            "error Card declined by the bank",
            "message Hello from the SentinelKit example",
            "flush",
            "revokeConsent",
        ])
        #expect(viewModel.activity.count == 7)
        #expect(viewModel.activity.first?.text == "Consent revoked: queue cleared, capture stopped")
    }

    // MARK: - Doubles

    private struct Harness {
        let viewModel: PlaygroundViewModel
        let service: SpySentinelService
        let storage: InMemoryDSNStorage
    }
}
