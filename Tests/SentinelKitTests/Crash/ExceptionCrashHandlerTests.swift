import Foundation
import Testing
@testable import SentinelKit

@Suite("Exception crash handler")
struct ExceptionCrashHandlerTests {

    // MARK: - Chaining

    @Test("writes the crash and then calls the handler the app had before")
    func chainsPreviousHandler() async throws {
        try await withTemporaryDirectory { directory in
            let store = CrashSnapshotStore()

            try? FileManager.default.removeItem(atPath: PreviousHandlerProbe.path)
            store.update(
                CrashSnapshot(
                    location: QueueLocation(directory: directory, capacity: 10),
                    options: Options(),
                    contexts: Contexts(),
                    scope: Scope(),
                    consentAllowsCapture: true,
                    stackTraceBuilder: StackTraceBuilder(isInApp: { _ in false })
                )
            )
            _ = store.markInstalled(previous: { _ in
                FileManager.default.createFile(atPath: PreviousHandlerProbe.path, contents: nil)
            })

            ExceptionCrashHandler.handle(
                NSException(name: .rangeException, reason: "index 5 beyond bounds", userInfo: nil),
                store: store
            )

            let pending = try await EventStore(directory: directory).pending()

            #expect(pending.count == 1)
            #expect(FileManager.default.fileExists(atPath: PreviousHandlerProbe.path))

            try? FileManager.default.removeItem(atPath: PreviousHandlerProbe.path)
        }
    }

    @Test("installs only once and remembers the first previous handler")
    func installsOnce() {
        let store = CrashSnapshotStore()

        #expect(store.markInstalled(previous: nil))
        #expect(!store.markInstalled(previous: nil))
    }

    // MARK: - Probe

    /// A C handler cannot capture context, so the previous handler signals through a known file.
    private enum PreviousHandlerProbe {
        static let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("SentinelKitTests-previous-handler-\(ProcessInfo.processInfo.processIdentifier)")
            .path
    }
}
