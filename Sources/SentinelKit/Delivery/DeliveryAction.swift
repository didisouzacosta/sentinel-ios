/// What to do with a stored envelope after an attempt to send it.
enum DeliveryAction: Equatable, Sendable {
    /// Sent or refused for good: remove it from the queue.
    case delete
    /// Keep it and stop sending for now.
    case keepAndStop
}
