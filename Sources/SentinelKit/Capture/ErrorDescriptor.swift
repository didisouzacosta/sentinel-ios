import Foundation

/// Type and message of an error, as shown in the issue title (`type: value`).
struct ErrorDescriptor: Equatable, Sendable {

    // MARK: - Properties

    let type: String

    let value: String

    // MARK: - Initializer

    init(_ error: any Error) {
        if Swift.type(of: error) is NSError.Type {
            let error = error as NSError

            type = error.domain
            value = "Code \(error.code): \(error.localizedDescription)"
        } else {
            type = String(describing: Swift.type(of: error))
            value = (error as? any LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }
}
