import Foundation
import WhiskKernel

struct SystemClock: Clock {
    func now() -> Date { Date() }
}
