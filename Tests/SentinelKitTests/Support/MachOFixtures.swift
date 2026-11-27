import Foundation

/// Little-endian Mach-O headers and load commands built byte by byte, to test the header parser on inputs a
/// real process never loads.
enum MachOFixtures {

    // MARK: - Type Properties

    /// A UUID whose formatted debug id is `a1b2c3d4-0000-1111-2222-333344445555`.
    static let uuid: [UInt8] = [
        0xA1, 0xB2, 0xC3, 0xD4, 0x00, 0x00, 0x11, 0x11,
        0x22, 0x22, 0x33, 0x33, 0x44, 0x44, 0x55, 0x55,
    ]

    /// `MH_MAGIC_64`.
    static let magic64: UInt32 = 0xFEED_FACF

    /// `LC_UUID`.
    static let uuidCommandType: UInt32 = 0x1B

    /// `LC_SEGMENT_64`.
    static let segmentCommandType: UInt32 = 0x19

    // MARK: - Type Methods

    /// A 64-bit header (arm64e by default) followed by `commands`. `ncmds` and `sizeofcmds` default to the real
    /// count and size of `commands`; override them to describe a malformed header.
    static func image(
        magic: UInt32 = magic64,
        cpuType: Int32 = 0x0100_000C,
        cpuSubtype: Int32 = Int32(bitPattern: 0x8000_0002),
        commands: [[UInt8]],
        ncmds: UInt32? = nil,
        sizeOfCommands: UInt32? = nil
    ) -> [UInt8] {
        let body = commands.flatMap(\.self)

        var header = bytes(of: magic)
        header += bytes(of: UInt32(bitPattern: cpuType))
        header += bytes(of: UInt32(bitPattern: cpuSubtype))
        header += bytes(of: UInt32(6)) // MH_DYLIB
        header += bytes(of: ncmds ?? UInt32(commands.count))
        header += bytes(of: sizeOfCommands ?? UInt32(body.count))
        header += bytes(of: UInt32(0)) // flags
        header += bytes(of: UInt32(0)) // reserved
        return header + body
    }

    /// An `LC_UUID` command. A `cmdsize` other than 24 describes a malformed command; the bytes still hold the UUID.
    static func uuidCommand(_ uuid: [UInt8], cmdsize: UInt32 = 24) -> [UInt8] {
        bytes(of: uuidCommandType) + bytes(of: cmdsize) + uuid
    }

    /// A 72-byte `LC_SEGMENT_64` command with no sections.
    static func segmentCommand(name: String, vmsize: UInt64) -> [UInt8] {
        let segname = Array(name.utf8.prefix(16)) + Array(repeating: 0, count: max(0, 16 - name.utf8.count))

        var command = bytes(of: segmentCommandType) + bytes(of: UInt32(72)) + segname
        command += bytes(of: UInt64(0x1_0000_0000)) // vmaddr
        command += bytes(of: vmsize)
        command += bytes(of: UInt64(0)) // fileoff
        command += bytes(of: vmsize) // filesize
        command += bytes(of: UInt32(5)) // maxprot
        command += bytes(of: UInt32(5)) // initprot
        command += bytes(of: UInt32(0)) // nsects
        command += bytes(of: UInt32(0)) // flags
        return command
    }

    /// A load command of any type, padded with zeros up to `cmdsize` (at least the 8-byte command header).
    static func loadCommand(cmd: UInt32, cmdsize: UInt32) -> [UInt8] {
        bytes(of: cmd) + bytes(of: cmdsize) + Array(repeating: 0, count: max(0, Int(cmdsize) - 8))
    }

    /// Whether `value` is a lowercase 8-4-4-4-12 UUID. Swift's `Regex` needs macOS 13 and iOS 16, newer than the
    /// package's deployment targets.
    static func isDebugID(_ value: String?) -> Bool {
        guard let value else {
            return false
        }

        let groups = value.split(separator: "-", omittingEmptySubsequences: false)

        return groups.map(\.count) == [8, 4, 4, 4, 12]
            && groups.allSatisfy { $0.allSatisfy { "0123456789abcdef".contains($0) } }
    }

    private static func bytes(of value: UInt32) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian, Array.init)
    }

    private static func bytes(of value: UInt64) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian, Array.init)
    }
}
