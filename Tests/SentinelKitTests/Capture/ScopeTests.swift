import Foundation
import Testing
@testable import SentinelKit

@Suite("Scope")
struct ScopeTests {

    // MARK: - Breadcrumbs

    @Test("keeps breadcrumbs in order and drops the oldest past the limit")
    func breadcrumbLimit() {
        var scope = Scope(maxBreadcrumbs: 3)

        for index in 1...5 {
            scope.add(Breadcrumb(message: "step \(index)"))
        }

        #expect(scope.breadcrumbs.map(\.message) == ["step 3", "step 4", "step 5"])
    }

    @Test("defaults to the server's limit of 50 breadcrumbs")
    func defaultBreadcrumbLimit() {
        var scope = Scope()

        for index in 1...60 {
            scope.add(Breadcrumb(message: "\(index)"))
        }

        #expect(scope.breadcrumbs.count == 50)
        #expect(scope.breadcrumbs.first?.message == "11")
    }

    // MARK: - Custom parameters

    @Test("sets, updates and removes custom parameters")
    func customParameters() {
        var scope = Scope()

        scope.setCustom("plan", "free")
        scope.setCustom("plan", "pro")
        scope.setCustom("screen", "checkout")
        scope.setCustom("screen", nil)

        #expect(scope.custom == ["plan": "pro"])
    }

    @Test("ignores empty keys and trims keys to 32 and values to 200 characters")
    func customLimits() {
        var scope = Scope()

        scope.setCustom("   ", "x")
        scope.setCustom(String(repeating: "k", count: 40), String(repeating: "v", count: 250))

        #expect(scope.custom.count == 1)
        #expect(scope.custom.keys.first?.count == 32)
        #expect(scope.custom.values.first?.count == 200)
    }

    @Test("accepts at most 50 custom parameters, but still updates existing ones")
    func customCount() {
        var scope = Scope()

        for index in 1...55 {
            scope.setCustom("key\(index)", "value")
        }

        scope.setCustom("key1", "updated")

        #expect(scope.custom.count == 50)
        #expect(scope.custom["key1"] == "updated")
        #expect(scope.custom["key51"] == nil)
    }
}
