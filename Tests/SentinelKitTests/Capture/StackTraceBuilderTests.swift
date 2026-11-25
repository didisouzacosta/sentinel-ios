import Foundation
import Testing
@testable import SentinelKit

@Suite("Stack trace builder")
struct StackTraceBuilderTests {

    // MARK: - Real call stack

    @Test("resolves the current call stack on the device, oldest frame first")
    func realCallStack() throws {
        let builder = StackTraceBuilder(isInApp: { $0.contains(".xctest") })
        let frames = builder.frames(from: StackTraceBuilder.currentAddresses())
        let newest = try #require(frames.last)

        #expect(frames.count > 3)
        #expect(newest.function?.contains("StackTraceBuilderTests") == true)
        #expect(newest.inApp == true)
        #expect(newest.package?.isEmpty == false)
        #expect(newest.instructionAddress?.hasPrefix("0x") == true)
        #expect(newest.instructionAddress?.count == 18)
        #expect(newest.imageAddress?.hasPrefix("0x") == true)
    }

    @Test("drops the SDK's own frames from the top of the stack")
    func dropsSDKFrames() {
        let builder = StackTraceBuilder(isInApp: { _ in false })
        let frames = builder.frames(from: StackTraceBuilder.currentAddresses())

        #expect(frames.last?.function?.contains("SentinelKit.") == false)
    }

    @Test("keeps the address of a frame it cannot symbolicate")
    func unknownAddress() {
        let builder = StackTraceBuilder(isInApp: { _ in true })
        let frame = builder.frames(from: [0x10]).first

        #expect(frame?.instructionAddress == "0x0000000000000010")
        #expect(frame?.function == nil)
    }
}
