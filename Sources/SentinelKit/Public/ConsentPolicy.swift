/// Whether the SDK needs the user's consent before sending anything.
public enum ConsentPolicy: Sendable {
    /// Default. Nothing leaves the device until `Sentinel.grantConsent()`; events wait locally until then.
    case required
    /// For apps that rely on another legal basis (for example, legitimate interest) and inform the user themselves.
    case notRequired
}
