/// Identity of a loaded Mach-O image, read from its header in memory: what a symbolicator needs to match its dSYM.
///
/// Only 64-bit little-endian headers are read, which covers every image an iOS 15+ process loads. Every read is
/// bounded by the header's `sizeofcmds` and each command's `cmdsize`; a malformed header yields nil, never a trap.
struct MachOImage: Hashable, Sendable {

    // MARK: - Type Properties

    /// Size of `mach_header_64`.
    private static let headerSize = 32

    /// `MH_MAGIC_64`.
    private static let magic64: UInt32 = 0xFEED_FACF

    /// Upper bound for `sizeofcmds`, far above any real image, so a corrupt value cannot describe a huge read.
    private static let maxCommandsSize: UInt32 = 16 << 20

    /// `LC_UUID`.
    private static let uuidCommand: UInt32 = 0x1B

    /// Size of `uuid_command`.
    private static let uuidCommandSize = 24

    /// `LC_SEGMENT_64`.
    private static let segmentCommand: UInt32 = 0x19

    /// Size of `segment_command_64`.
    private static let segmentCommandSize = 72

    /// `segname` of the segment whose `vmsize` is the image size: `__TEXT`, padded with NULs to 16 bytes.
    private static let textSegmentName = Array("__TEXT".utf8) + Array(repeating: 0, count: 10)

    /// `CPU_TYPE_ARM64`.
    private static let cpuTypeARM64: Int32 = 0x0100_000C

    /// `CPU_TYPE_ARM64_32`.
    private static let cpuTypeARM64ILP32: Int32 = 0x0200_000C

    /// `CPU_TYPE_X86_64`.
    private static let cpuTypeX64: Int32 = 0x0100_0007

    /// Clears the capability bits (`CPU_SUBTYPE_MASK`, e.g. `CPU_SUBTYPE_PTRAUTH_ABI`) to leave the plain subtype.
    private static let cpuSubtypeValueMask: Int32 = 0x00FF_FFFF

    /// Byte indices of the UUID followed by a dash in the 8-4-4-4-12 form.
    private static let dashIndices: Set<Int> = [4, 6, 8, 10]

    /// `CPU_SUBTYPE_ARM64E` and `CPU_SUBTYPE_ARM64E_X1`.
    private static let arm64eSubtypes: Set<Int32> = [2, 12]

    // MARK: - Properties

    /// `LC_UUID`, lowercased with dashes (the dSYM debug id).
    let debugID: String

    /// `vmsize` of the `__TEXT` segment; nil when the image has none.
    let imageSize: UInt64?

    /// `arm64`, `arm64e`, `x86_64` or `arm64_32`; nil for other CPUs.
    let arch: String?

    // MARK: - Initializers

    /// Reads the header of an image loaded in this process (e.g. `Dl_info.dli_fbase`). Nil when it is not a 64-bit
    /// Mach-O header or its load commands are malformed.
    init?(header: UnsafeRawPointer) {
        guard UInt32(littleEndian: header.loadUnaligned(as: UInt32.self)) == Self.magic64 else {
            return nil
        }

        let commandsSize = UInt32(littleEndian: header.loadUnaligned(fromByteOffset: 20, as: UInt32.self))

        guard commandsSize > 0, commandsSize <= Self.maxCommandsSize else {
            return nil
        }

        self.init(bytes: UnsafeRawBufferPointer(start: header, count: Self.headerSize + Int(commandsSize)))
    }

    /// Parses a buffer holding a `mach_header_64` followed by its load commands. Every read is bounds-checked.
    init?(bytes: UnsafeRawBufferPointer) {
        guard bytes.count >= Self.headerSize, Self.uint32(at: 0, in: bytes) == Self.magic64 else {
            return nil
        }

        let commandCount = Self.uint32(at: 16, in: bytes)
        let end = Self.headerSize + Int(Self.uint32(at: 20, in: bytes))

        guard end <= bytes.count else {
            return nil
        }

        var uuid: [UInt8]?

        var textSize: UInt64?

        var offset = Self.headerSize

        // `ncmds` may overstate the commands; the walk stops at `end` and moves at least 8 bytes per command.
        for _ in 0..<commandCount {
            guard offset + 8 <= end else {
                break
            }

            let command = Self.uint32(at: offset, in: bytes)
            let size = Int(Self.uint32(at: offset + 4, in: bytes))

            guard size >= 8, offset + size <= end else {
                return nil
            }

            if command == Self.uuidCommand, size >= Self.uuidCommandSize {
                uuid = Array(bytes[(offset + 8)..<(offset + 24)])
            } else if Self.isTextSegment(command: command, size: size, at: offset, in: bytes) {
                textSize = Self.uint64(at: offset + 32, in: bytes)
            }

            offset += size

            if uuid != nil, textSize != nil {
                break
            }
        }

        guard let uuid, let debugID = Self.debugID(uuid: uuid) else {
            return nil
        }

        self.debugID = debugID
        self.imageSize = textSize
        self.arch = Self.archName(
            cpuType: Int32(bitPattern: Self.uint32(at: 4, in: bytes)),
            cpuSubtype: Int32(bitPattern: Self.uint32(at: 8, in: bytes))
        )
    }

    // MARK: - Type Methods

    /// The UUID as lowercase 8-4-4-4-12 hex, the form `dwarfdump --uuid` prints; nil unless it has 16 bytes.
    static func debugID(uuid bytes: [UInt8]) -> String? {
        guard bytes.count == 16 else {
            return nil
        }

        var text = ""

        for (index, byte) in bytes.enumerated() {
            if dashIndices.contains(index) {
                text += "-"
            }

            let digits = String(byte, radix: 16)

            text += digits.count == 1 ? "0" + digits : digits
        }

        return text
    }

    /// The architecture name a symbolicator expects; nil for CPUs an iOS app does not run on.
    static func archName(cpuType: Int32, cpuSubtype: Int32) -> String? {
        let subtype = cpuSubtype & cpuSubtypeValueMask

        switch cpuType {
        case cpuTypeARM64:
            return arm64eSubtypes.contains(subtype) ? "arm64e" : "arm64"

        case cpuTypeX64:
            return "x86_64"

        case cpuTypeARM64ILP32:
            return "arm64_32"

        default:
            return nil
        }
    }

    /// Whether the load command at `offset` is a whole `segment_command_64` named `__TEXT`. Callers check that
    /// `offset + size` lies inside `bytes` first.
    private static func isTextSegment(
        command: UInt32,
        size: Int,
        at offset: Int,
        in bytes: UnsafeRawBufferPointer
    ) -> Bool {
        command == segmentCommand
            && size >= segmentCommandSize
            && bytes[(offset + 8)..<(offset + 24)].elementsEqual(textSegmentName)
    }

    /// Callers check `offset + 4 <= bytes.count` first.
    private static func uint32(at offset: Int, in bytes: UnsafeRawBufferPointer) -> UInt32 {
        UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt32.self))
    }

    /// Callers check `offset + 8 <= bytes.count` first.
    private static func uint64(at offset: Int, in bytes: UnsafeRawBufferPointer) -> UInt64 {
        UInt64(littleEndian: bytes.loadUnaligned(fromByteOffset: offset, as: UInt64.self))
    }
}
