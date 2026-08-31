import Foundation

struct SystemClock: Clock {
    func now() -> Date { Date() }
}
