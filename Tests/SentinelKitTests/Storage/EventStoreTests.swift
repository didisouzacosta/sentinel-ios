import Foundation
import Testing
@testable import SentinelKit

@Suite("Event store")
struct EventStoreTests {

    // MARK: - Helpers

    private func payload(_ index: Int) -> Data {
        Data("envelope \(index)".utf8)
    }

    // MARK: - Queue

    @Test("returns stored envelopes oldest first, with their contents")
    func order() async throws {
        try await withTemporaryDirectory { directory in
            let store = EventStore(directory: directory)

            for index in 1...3 {
                try await store.save(payload(index), id: EventID())
            }

            let pending = try await store.pending()

            #expect(try pending.map { try Data(contentsOf: $0.url) } == [payload(1), payload(2), payload(3)])
        }
    }

    @Test("keeps at most 10 envelopes and recycles the oldest")
    func capacity() async throws {
        try await withTemporaryDirectory { directory in
            let store = EventStore(directory: directory)

            for index in 1...12 {
                try await store.save(payload(index), id: EventID())
            }

            let pending = try await store.pending()

            #expect(pending.count == 10)
            #expect(try Data(contentsOf: #require(pending.first).url) == payload(3))
            #expect(try Data(contentsOf: #require(pending.last).url) == payload(12))
        }
    }

    @Test("removes one envelope or all of them")
    func removal() async throws {
        try await withTemporaryDirectory { directory in
            let store = EventStore(directory: directory)
            let first = EventID()

            try await store.save(payload(1), id: first)
            try await store.save(payload(2), id: EventID())
            try await store.remove(#require(store.pending().first))

            #expect(try await store.pending().map(\.id) != [first])
            #expect(try await store.pending().count == 1)

            try await store.removeAll()

            #expect(try await store.pending().isEmpty)
        }
    }

    @Test("survives a new launch and ignores files it did not write")
    func persistence() async throws {
        try await withTemporaryDirectory { directory in
            try await EventStore(directory: directory).save(payload(1), id: EventID())
            try Data("notes".utf8).write(to: directory.appendingPathComponent("notes.txt"))

            let pending = try await EventStore(directory: directory).pending()

            #expect(pending.count == 1)
        }
    }
}
