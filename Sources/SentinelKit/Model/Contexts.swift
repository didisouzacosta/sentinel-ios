/// The `contexts` field of an event: app, operating system and device.
struct Contexts: Hashable, Sendable, Encodable {

    // MARK: - Properties

    var app: AppContext?

    var operatingSystem: OSContext?

    var device: DeviceContext?

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case app
        case operatingSystem = "os"
        case device
    }
}
