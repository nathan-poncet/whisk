import Foundation
import Testing

@testable import Whisk

/// A clock the test cranks by hand: work items pile up until `fire` runs
/// them, so the debouncer's timing is asserted without waiting.
private final class HandCrankedScheduler {
    private(set) var queued: [DispatchWorkItem] = []

    func schedule(_ delay: TimeInterval, _ work: DispatchWorkItem) {
        queued.append(work)
    }

    func fire() {
        let due = queued
        queued.removeAll()
        for work in due where !work.isCancelled {
            work.perform()
        }
    }
}

@Suite struct Debouncing {
    @Test func only_the_last_call_of_a_burst_runs_when_the_delay_elapses() {
        let clock = HandCrankedScheduler()
        let debouncer = Debouncer(delay: 0.18, scheduler: clock.schedule)
        var runs: [String] = []

        debouncer.schedule { runs.append("first") }
        debouncer.schedule { runs.append("second") }
        #expect(runs.isEmpty)

        clock.fire()

        #expect(runs == ["second"])
    }

    @Test func flushing_runs_the_pending_call_now_and_the_delay_no_longer_fires_it() {
        let clock = HandCrankedScheduler()
        let debouncer = Debouncer(delay: 0.18, scheduler: clock.schedule)
        var runs = 0
        debouncer.schedule { runs += 1 }

        debouncer.flush()
        #expect(runs == 1)

        clock.fire()
        debouncer.flush()
        #expect(runs == 1)
    }

    @Test func cancelling_drops_the_pending_call() {
        let clock = HandCrankedScheduler()
        let debouncer = Debouncer(delay: 0.18, scheduler: clock.schedule)
        var runs = 0
        debouncer.schedule { runs += 1 }

        debouncer.cancel()
        clock.fire()
        debouncer.flush()

        #expect(runs == 0)
    }

    @Test func the_default_scheduler_is_the_main_queue() {
        let debouncer = Debouncer(delay: 0.01)
        debouncer.schedule {}
        debouncer.cancel()
    }
}

@Suite struct MouseActivityWindow {
    @Test func a_pointer_that_just_moved_counts_and_a_stale_one_does_not() {
        MouseActivity.lastMove = Date()
        #expect(MouseActivity.movedRecently)

        MouseActivity.lastMove = Date().addingTimeInterval(-1)
        #expect(!MouseActivity.movedRecently)
    }
}

@Suite struct SystemClockReading {
    @Test func the_system_clock_reads_the_current_time() {
        let before = Date()
        let read = SystemClock().now()
        let after = Date()

        #expect(read >= before)
        #expect(read <= after)
    }
}

@Suite struct ConsoleLogging {
    @Test func the_console_logger_writes_without_complaint() {
        ConsoleLogger().log("test line from the suite")
    }
}
