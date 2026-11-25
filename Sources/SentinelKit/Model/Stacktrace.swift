/// Frames of a stack trace, oldest first (the crashing frame is the last one).
struct Stacktrace: Hashable, Sendable, Encodable {
    var frames: [StackFrame]
}
