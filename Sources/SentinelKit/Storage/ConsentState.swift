/// The user's decision about sending data, saved between launches.
enum ConsentState: String, Sendable {
    case unknown
    case granted
    case revoked
}
