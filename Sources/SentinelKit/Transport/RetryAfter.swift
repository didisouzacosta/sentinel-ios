import Foundation

/// Reads the `Retry-After` header: delay seconds (`120`) or an HTTP date.
enum RetryAfter {

    // MARK: - Parsing

    static func seconds(from value: String?, now: Date) -> TimeInterval? {
        guard let value = value?.trimmingCharacters(in: .whitespaces), !value.isEmpty else {
            return nil
        }

        if let seconds = Int(value) {
            return seconds >= 0 ? TimeInterval(seconds) : nil
        }

        guard let date = httpDate(value) else {
            return nil
        }

        return max(0, date.timeIntervalSince(now))
    }

    // MARK: - Private Methods

    private static func httpDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: value)
    }
}
