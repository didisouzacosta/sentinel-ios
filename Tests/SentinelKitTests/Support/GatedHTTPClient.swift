import Foundation
@testable import SentinelKit

/// Holds every request until the test releases it, so tests can act while a send is in flight.
/// Cancelling the sending task fails the held request with `CancellationError`, like `URLSession`.
actor GatedHTTPClient: HTTPClient {

    // MARK: - Properties

    private(set) var requests: [URLRequest] = []

    private var held: [UUID: CheckedContinuation<HTTPResponse, any Error>] = [:]

    private var cancelled: Set<UUID> = []

    private var arrivals: [CheckedContinuation<Void, Never>] = []

    private(set) var cancellations = 0

    private var openStatus: Int?

    private var cancellationWaiters: [CheckedContinuation<Void, Never>] = []

    // MARK: - HTTPClient

    func send(_ request: URLRequest) async throws -> HTTPResponse {
        let id = UUID()

        requests.append(request)
        arrivals.forEach { $0.resume() }
        arrivals.removeAll()

        if let openStatus {
            return HTTPResponse(statusCode: openStatus, headers: [:], body: Data())
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                hold(continuation, id: id)
            }
        } onCancel: {
            Task {
                await self.cancel(id)
            }
        }
    }

    // MARK: - Methods

    /// Waits until at least `count` requests arrived.
    func waitForRequests(_ count: Int) async {
        while requests.count < count {
            await withCheckedContinuation { arrivals.append($0) }
        }
    }

    /// Waits until at least `count` held requests were cancelled.
    func waitForCancellations(_ count: Int) async {
        while cancellations < count {
            await withCheckedContinuation { cancellationWaiters.append($0) }
        }
    }

    /// Answers every held request with `status`.
    func releaseAll(status: Int = 200) {
        for continuation in held.values {
            continuation.resume(returning: HTTPResponse(statusCode: status, headers: [:], body: Data()))
        }

        held.removeAll()
    }

    /// Releases what is held and answers every later request at once.
    func open(status: Int = 200) {
        openStatus = status
        releaseAll(status: status)
    }

    // MARK: - Private Methods

    private func hold(_ continuation: CheckedContinuation<HTTPResponse, any Error>, id: UUID) {
        if cancelled.remove(id) != nil {
            continuation.resume(throwing: CancellationError())
        } else {
            held[id] = continuation
        }
    }

    private func cancel(_ id: UUID) {
        cancellations += 1
        cancellationWaiters.forEach { $0.resume() }
        cancellationWaiters.removeAll()

        if let continuation = held.removeValue(forKey: id) {
            continuation.resume(throwing: CancellationError())
        } else {
            cancelled.insert(id)
        }
    }
}
