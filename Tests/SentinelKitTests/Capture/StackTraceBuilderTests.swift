import Foundation
import MachO
import Testing
@testable import SentinelKit

@Suite("Stack trace builder")
struct StackTraceBuilderTests {

    // MARK: - Helpers

    private var testBundleBuilder: StackTraceBuilder {
        StackTraceBuilder(isInApp: { $0.contains(".xctest") })
    }

    private static func hex(_ value: UInt) -> String {
        let digits = String(value, radix: 16)

        return "0x" + String(repeating: "0", count: max(0, 16 - digits.count)) + digits
    }

    /// The path dyld reports for the image loaded at `address`, symlinks resolved.
    private func dyldPath(ofImageAt address: String) -> String? {
        for index in 0..<_dyld_image_count() {
            guard let header = _dyld_get_image_header(index), let name = _dyld_get_image_name(index) else {
                continue
            }

            if Self.hex(UInt(bitPattern: header)) == address {
                return URL(fileURLWithPath: String(cString: name)).resolvingSymlinksInPath().path
            }
        }

        return nil
    }

    // MARK: - Real call stack

    @Test("resolves the current call stack on the device, oldest frame first")
    func realCallStack() throws {
        let frames = testBundleBuilder.resolve(StackTraceBuilder.currentAddresses()).frames
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
        let frames = builder.resolve(StackTraceBuilder.currentAddresses()).frames

        #expect(frames.last?.function?.contains("SentinelKit.") == false)
    }

    @Test("keeps the address of a frame it cannot symbolicate, without inventing an image")
    func unknownAddress() {
        let builder = StackTraceBuilder(isInApp: { _ in true })
        let trace = builder.resolve([0x10])
        let frame = trace.frames.first

        #expect(frame?.instructionAddress == "0x0000000000000010")
        #expect(frame?.function == nil)
        #expect(trace.debugMeta == nil)
    }

    // MARK: - Debug images

    @Test("lists each image the frames point into once, in the order the frames first reference it")
    func debugImagesForRealStack() throws {
        let trace = testBundleBuilder.resolve(StackTraceBuilder.currentAddresses())
        let images = try #require(trace.debugMeta?.images)

        var frameImages: [String] = []

        for address in trace.frames.compactMap(\.imageAddress) where !frameImages.contains(address) {
            frameImages.append(address)
        }

        #expect(Set(images.map(\.imageAddress)).count == images.count)
        #expect(frameImages == images.map(\.imageAddress))
        #expect(images.count < Int(_dyld_image_count()))

        for image in images {
            #expect(image.type == "macho")
            #expect(MachOFixtures.isDebugID(image.debugID))
            #expect((image.imageSize ?? 0) > 0)
            #expect(image.arch != nil)
            #expect(image.codeFile?.isEmpty == false)
        }
    }

    @Test("describes the test bundle's own image with the path dyld loaded it from")
    func testBundleImage() throws {
        let trace = testBundleBuilder.resolve(StackTraceBuilder.currentAddresses())
        let newest = try #require(trace.frames.last?.imageAddress)
        let image = try #require(trace.images.first { $0.imageAddress == newest })
        let codeFile = try #require(image.codeFile)

        #expect(codeFile.contains(".xctest"))
        #expect(URL(fileURLWithPath: codeFile).resolvingSymlinksInPath().path == dyldPath(ofImageAt: newest))
    }

    @Test("lists an image once when several frames point into it")
    func sameImageOnce() throws {
        let newest = try #require(testBundleBuilder.resolve(StackTraceBuilder.currentAddresses()).frames.last)
        let address = try #require(newest.instructionAddress.flatMap { UInt($0.dropFirst(2), radix: 16) })
        let trace = testBundleBuilder.resolve([address, address &+ 4])

        #expect(trace.images.count == 1)
        #expect(trace.frames.count == 2)
        #expect(trace.frames.allSatisfy { $0.imageAddress == trace.images.first?.imageAddress })
    }

    // MARK: - Code file

    @Test(
        "sends app binaries relative to the app's container and everything else as is",
        arguments: [
            CodeFileCase(
                path: "/private/var/containers/Bundle/Application/1234/Shop.app/Shop",
                container: "/private/var/containers/Bundle/Application/1234",
                expected: "Shop.app/Shop"
            ),
            CodeFileCase(
                path: "/usr/lib/libobjc.A.dylib",
                container: "/private/var/containers/Bundle/Application/1234",
                expected: "/usr/lib/libobjc.A.dylib"
            ),
            CodeFileCase(
                path: "/private/var/containers/Bundle/Application/1234/Shop.app/Shop",
                container: nil,
                expected: "/private/var/containers/Bundle/Application/1234/Shop.app/Shop"
            ),
            CodeFileCase(
                path: "/private/var/containers/Bundle/Application/12345/Shop.app/Shop",
                container: "/private/var/containers/Bundle/Application/1234",
                expected: "/private/var/containers/Bundle/Application/12345/Shop.app/Shop"
            ),
        ]
    )
    func codeFileRelative(_ testCase: CodeFileCase) {
        #expect(
            StackTraceBuilder.codeFile(for: testCase.path, appContainerPath: testCase.container) == testCase.expected
        )
    }

    @Test("strips the container from the code file of images inside it")
    func containerStripped() throws {
        let addresses = StackTraceBuilder.currentAddresses()
        let trace = testBundleBuilder.resolve(addresses)
        let newest = try #require(trace.frames.last?.imageAddress)
        let fullPath = try #require(trace.images.first { $0.imageAddress == newest }?.codeFile)
        let bundleEnd = try #require(fullPath.range(of: ".xctest/")?.lowerBound)
        let containerEnd = try #require(fullPath[..<bundleEnd].lastIndex(of: "/"))
        let container = String(fullPath[..<containerEnd])
        let builder = StackTraceBuilder(isInApp: { $0.contains(".xctest") }, appContainerPath: container)
        let stripped = try #require(builder.resolve(addresses).images.first { $0.imageAddress == newest }?.codeFile)

        #expect(!stripped.hasPrefix("/"))
        #expect(stripped.contains(".xctest/"))
        #expect(container + "/" + stripped == fullPath)
    }

    // MARK: - Doubles

    struct CodeFileCase: Sendable {
        let path: String

        let container: String?

        let expected: String
    }
}
