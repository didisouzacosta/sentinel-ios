import Foundation
import MachO
import Testing
@testable import SentinelKit

@Suite("Mach-O image")
struct MachOImageTests {

    // MARK: - Helpers

    private func parse(_ bytes: [UInt8]) -> MachOImage? {
        bytes.withUnsafeBytes { MachOImage(bytes: $0) }
    }

    // MARK: - Debug id

    @Test("formats the UUID as lowercase 8-4-4-4-12 hex, like dwarfdump")
    func debugIDFormat() {
        #expect(MachOImage.debugID(uuid: MachOFixtures.uuid) == "a1b2c3d4-0000-1111-2222-333344445555")
    }

    @Test("formats nothing unless the UUID has exactly 16 bytes", arguments: [0, 15, 17])
    func debugIDLength(count: Int) {
        #expect(MachOImage.debugID(uuid: Array(repeating: 0xAB, count: count)) == nil)
    }

    // MARK: - Architecture

    @Test(
        "names the architecture from the CPU type and subtype",
        arguments: [
            (Int32(0x0100_000C), Int32(0), "arm64"),
            (Int32(0x0100_000C), Int32(1), "arm64"),
            (Int32(0x0100_000C), Int32(2), "arm64e"),
            (Int32(0x0100_000C), Int32(bitPattern: 0x8000_0002), "arm64e"),
            (Int32(0x0100_000C), Int32(12), "arm64e"),
            (Int32(0x0100_0007), Int32(3), "x86_64"),
            (Int32(0x0200_000C), Int32(1), "arm64_32"),
        ]
    )
    func archNames(cpuType: Int32, cpuSubtype: Int32, expected: String) {
        #expect(MachOImage.archName(cpuType: cpuType, cpuSubtype: cpuSubtype) == expected)
    }

    @Test(
        "names no architecture for other CPUs",
        arguments: [(Int32(7), Int32(3)), (Int32(18), Int32(0))]
    )
    func unknownArch(cpuType: Int32, cpuSubtype: Int32) {
        #expect(MachOImage.archName(cpuType: cpuType, cpuSubtype: cpuSubtype) == nil)
    }

    // MARK: - Synthetic headers

    @Test("reads the UUID, the __TEXT size and the architecture of a header")
    func syntheticImage() throws {
        let image = try #require(parse(MachOFixtures.image(
            commands: [
                MachOFixtures.segmentCommand(name: "__PAGEZERO", vmsize: 0x1_0000_0000),
                MachOFixtures.segmentCommand(name: "__TEXT", vmsize: 0x4000),
                MachOFixtures.uuidCommand(MachOFixtures.uuid),
            ]
        )))

        #expect(image.debugID == "a1b2c3d4-0000-1111-2222-333344445555")
        #expect(image.imageSize == 0x4000)
        #expect(image.arch == "arm64e")
    }

    @Test("leaves the size unknown when there is no __TEXT segment")
    func noTextSegment() throws {
        let image = try #require(parse(MachOFixtures.image(
            commands: [
                MachOFixtures.uuidCommand(MachOFixtures.uuid),
                MachOFixtures.segmentCommand(name: "__DATA", vmsize: 0x4000),
            ]
        )))

        #expect(image.debugID == "a1b2c3d4-0000-1111-2222-333344445555")
        #expect(image.imageSize == nil)
    }

    @Test("gives up without a UUID, since the dSYM cannot be matched")
    func noUUID() {
        let bytes = MachOFixtures.image(commands: [MachOFixtures.segmentCommand(name: "__TEXT", vmsize: 0x4000)])

        #expect(parse(bytes) == nil)
    }

    @Test("stops at the end of the load commands when ncmds overstates them")
    func overstatedCount() {
        let bytes = MachOFixtures.image(
            commands: [
                MachOFixtures.segmentCommand(name: "__DATA", vmsize: 0x4000),
                MachOFixtures.uuidCommand(MachOFixtures.uuid),
            ],
            ncmds: 5
        )

        #expect(parse(bytes)?.debugID == "a1b2c3d4-0000-1111-2222-333344445555")
    }

    @Test("rejects malformed headers without trapping or looping", arguments: MalformedHeader.allCases)
    func malformed(header: MalformedHeader) {
        #expect(parse(header.bytes) == nil)
    }

    // MARK: - Loaded images

    @Test("reads the header of an image loaded in this process, matching dyld's own answers")
    func loadedImage() throws {
        let address = try #require(StackTraceBuilder.currentAddresses().first)
        let pointer = try #require(UnsafeRawPointer(bitPattern: address))

        var info = Dl_info()

        #expect(dladdr(pointer, &info) != 0)

        let base = try #require(info.dli_fbase.map { UnsafeRawPointer($0) })
        let image = try #require(MachOImage(header: base))
        let loadedHeaders = (0..<_dyld_image_count()).compactMap { _dyld_get_image_header($0) }

        var textSize: UInt = 0

        _ = getsegmentdata(base.assumingMemoryBound(to: mach_header_64.self), "__TEXT", &textSize)

        #expect(MachOFixtures.isDebugID(image.debugID))
        #expect(image.debugID != "00000000-0000-0000-0000-000000000000")
        #expect(image.imageSize == UInt64(textSize))
        #expect(loadedHeaders.contains { UnsafeRawPointer($0) == base })

        #if arch(arm64)
            #expect(image.arch == "arm64" || image.arch == "arm64e")
        #elseif arch(x86_64)
            #expect(image.arch == "x86_64")
        #endif
    }

    // MARK: - Doubles

    enum MalformedHeader: CaseIterable, Sendable {

        // MARK: - Cases

        case thirtyTwoBitMagic
        case truncatedHeader
        case commandsPastBuffer
        case zeroCommandSize
        case commandPastEnd
        case shortUUIDCommand

        // MARK: - Properties

        var bytes: [UInt8] {
            let uuid = MachOFixtures.uuidCommand(MachOFixtures.uuid)

            switch self {
            case .thirtyTwoBitMagic:
                return MachOFixtures.image(magic: 0xFEED_FACE, commands: [uuid])

            case .truncatedHeader:
                return Array(MachOFixtures.image(commands: []).prefix(20))

            case .commandsPastBuffer:
                return MachOFixtures.image(commands: [uuid], sizeOfCommands: 4096)

            case .zeroCommandSize:
                return MachOFixtures.image(commands: [MachOFixtures.loadCommand(cmd: 0x2, cmdsize: 0), uuid])

            case .commandPastEnd:
                return MachOFixtures.image(commands: [MachOFixtures.uuidCommand(MachOFixtures.uuid, cmdsize: 4096)])

            case .shortUUIDCommand:
                let shortUUID = MachOFixtures.uuidCommand(Array(MachOFixtures.uuid.prefix(8)), cmdsize: 16)

                return MachOFixtures.image(commands: [shortUUID])
            }
        }
    }
}
