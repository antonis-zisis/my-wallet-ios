import Foundation

extension Double {
    func maskedCurrency(hidden: Bool) -> String {
        hidden ? "***" : self.formatted(.currency(code: "EUR"))
    }
}
