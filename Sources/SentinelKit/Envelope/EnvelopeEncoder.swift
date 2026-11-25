import Foundation

/// Writes an envelope as newline-separated lines: the envelope header, then for each item its header and its
/// payload.
///
/// ```
/// {"event_id":"…","sdk":{…},"sent_at":"…"}
/// {"length":123,"type":"event"}
/// {…event JSON…}
/// ```
struct EnvelopeEncoder: Sendable {

    // MARK: - Encoding

    func encode(_ envelope: Envelope) throws -> Data {
        let encoder = SentinelJSON.encoder
        let newline = Data("\n".utf8)

        var data = try encoder.encode(envelope.header)

        for item in envelope.items {
            data.append(newline)
            try data.append(encoder.encode(item.header))
            data.append(newline)
            data.append(item.payload)
        }

        return data
    }
}
