/// The app that sent the event.
struct AppContext: Hashable, Sendable, Encodable {

    // MARK: - Properties

    let identifier: String?

    let name: String?

    let version: String?

    let build: String?

    // MARK: - Coding Keys

    private enum CodingKeys: String, CodingKey {
        case identifier = "app_identifier"
        case name = "app_name"
        case version = "app_version"
        case build = "app_build"
    }
}
