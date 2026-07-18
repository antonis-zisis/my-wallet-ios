import Foundation

extension Date {
    /// Formats a date as "Aug 2, 2026" — abbreviated month, day, full year.
    /// Uses en_US locale explicitly so the ordering is consistent regardless of device locale.
    var appFormatted: String {
        formatted(.dateTime.month(.abbreviated).day().year().locale(Locale(identifier: "en_US")))
    }
}
