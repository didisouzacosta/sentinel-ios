/// The `debug_meta` field of an event: the binaries needed to symbolicate its frames.
struct DebugMeta: Hashable, Sendable, Encodable {
    var images: [DebugImage]
}
