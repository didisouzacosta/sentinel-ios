import Foundation

/// Assembles events from errors and messages, adding the scope, the contexts and the options.
struct EventBuilder: Sendable {

    // MARK: - Properties

    let options: Options

    let contexts: Contexts

    let stackTraceBuilder: StackTraceBuilder

    // MARK: - Methods

    func event(for error: any Error, addresses: [UInt], scope: Scope, at date: Date) -> Event {
        let descriptor = ErrorDescriptor(error)
        let frames = stackTraceBuilder.frames(from: addresses)

        var event = base(level: .error, scope: scope, at: date)
        event.exception = ExceptionList(
            values: [
                ExceptionValue(
                    type: descriptor.type,
                    value: descriptor.value,
                    mechanism: Mechanism(type: "generic", handled: true),
                    stacktrace: frames.isEmpty ? nil : Stacktrace(frames: frames)
                ),
            ]
        )
        return event
    }

    /// An uncaught Objective-C exception: fatal and unhandled.
    func event(exceptionName: String, reason: String, addresses: [UInt], scope: Scope, at date: Date) -> Event {
        let frames = stackTraceBuilder.frames(from: addresses)

        var event = base(level: .fatal, scope: scope, at: date)
        event.exception = ExceptionList(
            values: [
                ExceptionValue(
                    type: exceptionName,
                    value: reason,
                    mechanism: Mechanism(type: "NSException", handled: false),
                    stacktrace: frames.isEmpty ? nil : Stacktrace(frames: frames)
                ),
            ]
        )
        return event
    }

    func event(message: String, level: Level, scope: Scope, at date: Date) -> Event {
        var event = base(level: level, scope: scope, at: date)
        event.message = message
        return event
    }

    // MARK: - Private Methods

    private func base(level: Level, scope: Scope, at date: Date) -> Event {
        var event = Event(timestamp: date, level: level)
        event.release = options.release
        event.environment = options.environment
        event.dist = options.dist
        event.contexts = contexts
        event.breadcrumbs = scope.breadcrumbs.isEmpty ? nil : scope.breadcrumbs
        event.tags = scope.custom.isEmpty ? nil : scope.custom
        return event
    }
}
