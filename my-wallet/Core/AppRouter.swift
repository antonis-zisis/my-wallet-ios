import Foundation

@Observable
final class AppRouter {
    static let dashboardTab = 0
    static let reportsTab = 1

    private static let tabKey = "selectedTab"

    var selectedTab: Int {
        didSet { UserDefaults.standard.set(selectedTab, forKey: Self.tabKey) }
    }

    var reportsPath: [Report] = []

    init() {
        selectedTab = UserDefaults.standard.integer(forKey: Self.tabKey)
    }

    /// Opens a report inside the Reports tab so the tab bar reflects where the report lives.
    func openReport(_ report: Report) {
        reportsPath = [report]
        selectedTab = Self.reportsTab
    }
}
