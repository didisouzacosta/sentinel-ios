/// Severity of an event or breadcrumb, using the level names the Sentinel server accepts.
public enum Level: String, Codable, Sendable, CaseIterable {
    case debug
    case info
    case warning
    case error
    case fatal
}
