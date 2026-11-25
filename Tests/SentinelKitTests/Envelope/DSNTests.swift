import Foundation
import Testing
@testable import SentinelKit

@Suite("DSN")
struct DSNTests {

    // MARK: - Parsing

    @Test("parses the public key, host and project id")
    func parsesProductionDSN() throws {
        let dsn = try DSN("https://pk123@sentinel.example.com/42")

        #expect(dsn.publicKey == "pk123")
        #expect(dsn.projectID == "42")
        #expect(dsn.envelopeURL.absoluteString == "https://sentinel.example.com/api/42/envelope/")
    }

    @Test("keeps the scheme and port of a local DSN")
    func keepsSchemeAndPort() throws {
        let dsn = try DSN("http://pk@127.0.0.1:8787/1")

        #expect(dsn.envelopeURL.absoluteString == "http://127.0.0.1:8787/api/1/envelope/")
    }

    @Test("keeps a path prefix before the project id")
    func keepsPathPrefix() throws {
        let dsn = try DSN("https://pk@example.com/sentinel/7")

        #expect(dsn.projectID == "7")
        #expect(dsn.envelopeURL.absoluteString == "https://example.com/sentinel/api/7/envelope/")
    }

    @Test("ignores surrounding whitespace")
    func trimsWhitespace() throws {
        let dsn = try DSN("  https://pk@example.com/3\n")

        #expect(dsn.projectID == "3")
    }

    // MARK: - Errors

    @Test(
        "rejects malformed DSNs with a typed error",
        arguments: [
            ("not a url", DSNError.invalidURL),
            ("", DSNError.invalidURL),
            ("https://example.com/42", DSNError.missingPublicKey),
            ("https://pk@example.com/", DSNError.missingProjectID),
            ("https://pk@example.com", DSNError.missingProjectID),
            ("ftp://pk@example.com/1", DSNError.unsupportedScheme),
        ]
    )
    func rejectsMalformed(input: String, expected: DSNError) {
        #expect(throws: expected) {
            try DSN(input)
        }
    }
}
