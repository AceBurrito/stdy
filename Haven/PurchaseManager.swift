import SwiftUI
import Combine

@MainActor
class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()
    @Published var hasFullAccess: Bool = true
    var isPro: Bool { hasFullAccess }
    func restorePurchases() async { }
    func configure() async { }
}