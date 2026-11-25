/// Name and version of the SDK that produced an event.
struct SDKInfo: Hashable, Sendable, Encodable {

    // MARK: - Properties

    static let current = SDKInfo(name: "sentinel.cocoa", version: "0.1.0")

    let name: String

    let version: String
}
