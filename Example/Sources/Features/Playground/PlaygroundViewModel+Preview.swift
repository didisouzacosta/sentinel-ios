extension PlaygroundViewModel {

    // MARK: - Previews

    /// Not started yet: nothing saved, no SDK.
    static var previewNotStarted: PlaygroundViewModel {
        PlaygroundViewModel(service: PreviewSentinelService(), storage: InMemoryDSNStorage())
    }

    /// Started with a saved DSN, still without the real SDK.
    static var previewStarted: PlaygroundViewModel {
        PlaygroundViewModel(
            service: PreviewSentinelService(),
            storage: InMemoryDSNStorage(savedDSN: "https://key@sentinel.example.com/1")
        )
    }
}
