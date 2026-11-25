import Foundation
import Testing
@testable import SentinelKit

@Suite("Lifecycle observer")
struct LifecycleObserverTests {

    // MARK: - Helpers

    private static let background = Notification.Name("LifecycleObserverTests.background")

    private static let active = Notification.Name("LifecycleObserverTests.active")

    /// Observes a private center, so nothing reaches the app's real notifications.
    private func observe(tasks: FakeBackgroundTasks, probe: FlushProbe) -> NotificationCenter {
        let center = NotificationCenter()
        let events = LifecycleEvents(
            center: center,
            didEnterBackground: Self.background,
            didBecomeActive: Self.active,
            backgroundTasks: tasks
        )

        LifecycleObserver.observe(
            events,
            flush: { await probe.flush() },
            triggerFlush: { Task { await probe.trigger() } }
        )
        return center
    }

    // MARK: - Background

    @Test("going to the background flushes and holds background time until the flush ends")
    func background() async {
        let tasks = FakeBackgroundTasks()
        let probe = FlushProbe()
        let center = observe(tasks: tasks, probe: probe)

        center.post(name: Self.background, object: nil)
        await probe.wait(flushes: 1)

        #expect(await tasks.log == ["begin SentinelKit.flush #1"])

        await probe.open()
        await tasks.waitForEnds(1)

        #expect(await tasks.log == ["begin SentinelKit.flush #1", "end #1"])
    }

    @Test("a second trip to the background asks for time again while the first flush is still running")
    func overlapping() async {
        let tasks = FakeBackgroundTasks()
        let probe = FlushProbe()
        let center = observe(tasks: tasks, probe: probe)

        center.post(name: Self.background, object: nil)
        center.post(name: Self.background, object: nil)
        await probe.wait(flushes: 2)

        #expect(await tasks.log == ["begin SentinelKit.flush #1", "begin SentinelKit.flush #2"])

        await probe.open()
        await tasks.waitForEnds(2)
    }

    @Test("without background time the flush still runs")
    func refused() async {
        let tasks = FakeBackgroundTasks(grantsTime: false)
        let probe = FlushProbe()
        let center = observe(tasks: tasks, probe: probe)

        await probe.open()
        center.post(name: Self.background, object: nil)
        await probe.wait(flushes: 1)

        #expect(await tasks.log == ["refused SentinelKit.flush"])
    }

    // MARK: - Foreground

    @Test("becoming active starts a send without asking for background time")
    func active() async {
        let tasks = FakeBackgroundTasks()
        let probe = FlushProbe()
        let center = observe(tasks: tasks, probe: probe)

        center.post(name: Self.active, object: nil)
        await probe.wait(triggers: 1)

        #expect(await probe.flushes == 0)
        #expect(await tasks.log.isEmpty)
    }
}
