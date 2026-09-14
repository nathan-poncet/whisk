/// Where the adapters report what the user never sees — a storage failure
/// the session survived, a history that would not load.
protocol Logger {
    func log(_ message: String)
}
