/// What is attached to every event: recent breadcrumbs and the app's custom parameters (sent as tags).
struct Scope: Sendable {

    // MARK: - Constants

    static let maxCustomKeyLength = 32

    static let maxCustomValueLength = 200

    // MARK: - Properties

    let maxBreadcrumbs: Int

    let maxCustom: Int

    private(set) var breadcrumbs: [Breadcrumb] = []

    private(set) var custom: [String: String] = [:]

    // MARK: - Initializer

    /// The limits match what the Sentinel server keeps: 50 breadcrumbs and 50 tags.
    init(maxBreadcrumbs: Int = 50, maxCustom: Int = 50) {
        self.maxBreadcrumbs = maxBreadcrumbs
        self.maxCustom = maxCustom
    }

    // MARK: - Methods

    mutating func add(_ breadcrumb: Breadcrumb) {
        breadcrumbs.append(breadcrumb)

        if breadcrumbs.count > maxBreadcrumbs {
            breadcrumbs.removeFirst(breadcrumbs.count - maxBreadcrumbs)
        }
    }

    /// Sets a custom parameter, or removes it when `value` is `nil`.
    mutating func setCustom(_ key: String, _ value: String?) {
        let key = String(key.trimmingCharacters(in: .whitespaces).prefix(Self.maxCustomKeyLength))

        guard !key.isEmpty else {
            return
        }

        guard let value else {
            custom[key] = nil
            return
        }

        guard custom[key] != nil || custom.count < maxCustom else {
            return
        }

        custom[key] = String(value.prefix(Self.maxCustomValueLength))
    }
}
