import Testing
@testable import SentinelKit

@Suite("Background time")
@MainActor
struct BackgroundTimeTests {

    // MARK: - Pairing

    @Test("ends the task once when the work finishes")
    func endsOnce() {
        let tasks = FakeBackgroundTasks()
        let time = BackgroundTime(runner: tasks)

        time.begin()
        time.end()
        time.end()

        #expect(tasks.log == ["begin SentinelKit.flush #1", "end #1"])
    }

    @Test("ends the task when the time runs out, and not again when the work finishes later")
    func expiration() {
        let tasks = FakeBackgroundTasks()
        let time = BackgroundTime(runner: tasks)

        time.begin()
        tasks.expire()
        time.end()

        #expect(tasks.log == ["begin SentinelKit.flush #1", "end #1"])
    }

    @Test("asks for time only once per request")
    func beginsOnce() {
        let tasks = FakeBackgroundTasks()
        let time = BackgroundTime(runner: tasks)

        time.begin()
        time.begin()
        time.end()

        #expect(tasks.log == ["begin SentinelKit.flush #1", "end #1"])
    }

    @Test("ends nothing when the system gives no time (app extension, no application)")
    func refused() {
        let tasks = FakeBackgroundTasks(grantsTime: false)
        let time = BackgroundTime(runner: tasks)

        time.begin()
        time.end()

        #expect(tasks.log == ["refused SentinelKit.flush"])
    }
}
