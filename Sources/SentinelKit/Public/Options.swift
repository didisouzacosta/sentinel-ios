/// Settings passed to `Sentinel.start(dsn:configure:)`.
public struct Options: Sendable {

    // MARK: - Properties

    /// For example `"production"` or `"debug"`.
    public var environment: String?

    /// Defaults to `<bundle id>@<version>+<build>`.
    public var release: String?

    /// Build number or variant; defaults to nothing.
    public var dist: String?

    /// Defaults to `.required`: nothing is sent until `Sentinel.grantConsent()`.
    public var consent: ConsentPolicy = .required

    // MARK: - Initializer

    public init() {}
}
