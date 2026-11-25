import Foundation

/// The project's client key, as shown in Sentinel under Project settings → Client keys (DSN).
///
/// Format: `https://<public key>@<host>[:port][/prefix]/<project id>`. The key is public: it only allows
/// sending events to that project.
struct DSN: Hashable, Sendable {

    // MARK: - Properties

    let publicKey: String

    let projectID: String

    /// `POST` endpoint that receives envelopes: `<scheme>://<host>[:port][/prefix]/api/<project id>/envelope/`.
    let envelopeURL: URL

    // MARK: - Initializer

    init(_ string: String) throws(DSNError) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)

        guard
            let components = URLComponents(string: trimmed), let scheme = components.scheme, let host = components.host,
            !host.isEmpty
        else {
            throw .invalidURL
        }

        guard scheme == "https" || scheme == "http" else {
            throw .unsupportedScheme
        }

        guard let publicKey = components.user, !publicKey.isEmpty else {
            throw .missingPublicKey
        }

        var segments = components.path.split(separator: "/").map(String.init)

        guard let projectID = segments.popLast() else {
            throw .missingProjectID
        }

        var endpoint = URLComponents()
        endpoint.scheme = scheme
        endpoint.host = host
        endpoint.port = components.port
        endpoint.path = "/" + (segments + ["api", projectID, "envelope"]).joined(separator: "/") + "/"

        guard let envelopeURL = endpoint.url else {
            throw .invalidURL
        }

        self.publicKey = publicKey
        self.projectID = projectID
        self.envelopeURL = envelopeURL
    }
}
