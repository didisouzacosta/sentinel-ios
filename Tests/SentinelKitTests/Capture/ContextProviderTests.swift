import Foundation
import Testing
@testable import SentinelKit

@Suite("Context provider")
struct ContextProviderTests {

    // MARK: - Helpers

    private let app = AppInfo(identifier: "com.example.shop", name: "Shop", version: "3.2.0", build: "412")

    // MARK: - Contexts

    @Test("describes the app, the OS and the device")
    func contexts() {
        let contexts = ContextProvider.contexts(app: app)

        #expect(contexts.app?.identifier == "com.example.shop")
        #expect(contexts.app?.version == "3.2.0")
        #expect(contexts.app?.build == "412")
        #expect(contexts.operatingSystem?.name.isEmpty == false)
        #expect(contexts.operatingSystem?.version.isEmpty == false)
        #expect(contexts.device?.model.isEmpty == false)
        #expect((contexts.device?.memorySize ?? 0) > 0)
    }

    @Test("never collects personal data such as the device name")
    func noPersonalData() throws {
        let data = try SentinelJSON.encoder.encode(ContextProvider.contexts(app: app))
        let text = try #require(String(bytes: data, encoding: .utf8))

        #expect(!text.contains("\"name\":\"\(ProcessInfo.processInfo.hostName)\""))
        #expect(!text.contains("device_name"))
        #expect(!text.contains("ip_address"))
    }

    @Test("builds the default release as bundle id, version and build")
    func release() {
        #expect(app.release == "com.example.shop@3.2.0+412")
        #expect(AppInfo(identifier: nil, name: nil, version: nil, build: nil).release == nil)
    }
}
