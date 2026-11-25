/// Events found in a MetricKit payload, and whether one of its diagnostics was the crash the NSException handler
/// already wrote (so the handler's marker can be removed).
struct MetricKitParseResult: Sendable {
    let events: [Event]
    let matchedHandlerCrash: Bool
}
