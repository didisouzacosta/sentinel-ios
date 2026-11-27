/// The frames of one stack, oldest first, and the loaded images they point into.
struct ResolvedStackTrace: Sendable {

    // MARK: - Properties

    let frames: [StackFrame]

    /// One entry per image the frames reference, in order of first reference.
    let images: [DebugImage]

    /// Nil without frames, so the event carries no empty stack trace.
    var stacktrace: Stacktrace? {
        frames.isEmpty ? nil : Stacktrace(frames: frames)
    }

    /// Nil without images, so the event carries no empty `debug_meta`.
    var debugMeta: DebugMeta? {
        images.isEmpty ? nil : DebugMeta(images: images)
    }
}
