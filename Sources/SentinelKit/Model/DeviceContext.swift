/// Hardware facts that help reproduce a crash. Deliberately has no device name or identifier (GDPR).
struct DeviceContext: Hashable, Sendable, Encodable {

    // MARK: - Properties

    /// Hardware model identifier, for example `iPhone17,1`.
    let model: String

    let family: String

    let arch: String

    let simulator: Bool

    let memorySize: UInt64

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case model
        case family
        case arch
        case simulator
        case memorySize = "memory_size"
    }
}
