/// Why a DSN string could not be used.
enum DSNError: Error, Equatable, Sendable {
    case invalidURL
    case unsupportedScheme
    case missingPublicKey
    case missingProjectID
}
