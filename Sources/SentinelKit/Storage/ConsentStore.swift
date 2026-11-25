/// Where the consent decision is saved. Synchronous on purpose: the engine reads it once at start, so no
/// suspended read can race with a newer decision.
protocol ConsentStore: Sendable {
    func load() -> ConsentState
    func save(_ state: ConsentState)
}
