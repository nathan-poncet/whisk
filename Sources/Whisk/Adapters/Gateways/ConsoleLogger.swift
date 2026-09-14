import Foundation

/// Reports to the unified log through NSLog, prefixed like every other
/// line Whisk writes there.
struct ConsoleLogger: Logger {
    init() {}

    func log(_ message: String) {
        NSLog("Whisk: %@", message)
    }
}
