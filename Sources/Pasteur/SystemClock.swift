import Foundation
import PasteurKernel

struct SystemClock: Clock {
    func now() -> Date { Date() }
}
