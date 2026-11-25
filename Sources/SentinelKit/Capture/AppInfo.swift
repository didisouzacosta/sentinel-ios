import Foundation

/// Identity and version of the app, read from its `Info.plist`.
struct AppInfo: Hashable, Sendable {

    // MARK: - Properties

    let identifier: String?

    let name: String?

    let version: String?

    let build: String?

    /// `<bundle id>@<version>+<build>`, the default release of every event.
    var release: String? {
        guard let identifier, let version else {
            return nil
        }

        return build.map { "\(identifier)@\(version)+\($0)" } ?? "\(identifier)@\(version)"
    }

    // MARK: - Initializers

    init(identifier: String?, name: String?, version: String?, build: String?) {
        self.identifier = identifier
        self.name = name
        self.version = version
        self.build = build
    }

    init(bundle: Bundle) {
        self.init(
            identifier: bundle.bundleIdentifier,
            name: bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
            version: bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }
}
