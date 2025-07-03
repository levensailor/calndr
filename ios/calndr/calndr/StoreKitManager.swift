import Foundation
import StoreKit

@MainActor
class StoreKitManager: NSObject, ObservableObject {
    @Published var products: [Product] = []
    @Published var purchasedProducts: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var productIds: Set<String> = [
        "com.calndr.premium.monthly",
        "com.calndr.premium.yearly"
        // Add your actual product IDs here
    ]
    
    override init() {
        super.init()
        Task {
            await requestProducts()
            await updatePurchasedProducts()
            await observeTransactions()
        }
    }
    
    // MARK: - Product Loading
    func requestProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let products = try await Product.products(for: productIds)
            self.products = products.sorted { $0.price < $1.price }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - Purchase Management
    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    await updatePurchasedProducts()
                    return true
                }
            case .userCancelled:
                errorMessage = "Purchase cancelled"
            case .pending:
                errorMessage = "Purchase pending approval"
            @unknown default:
                errorMessage = "Unknown purchase result"
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }
        
        return false
    }
    
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            errorMessage = "Failed to restore purchases: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Subscription Status
    func updatePurchasedProducts() async {
        var purchasedProducts: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.revocationDate == nil {
                    purchasedProducts.insert(transaction.productID)
                }
            }
        }
        
        self.purchasedProducts = purchasedProducts
    }
    
    func isPremiumActive() -> Bool {
        return !purchasedProducts.isEmpty
    }
    
    func getActiveSubscription() -> String? {
        if purchasedProducts.contains("com.calndr.premium.yearly") {
            return "Premium Yearly"
        } else if purchasedProducts.contains("com.calndr.premium.monthly") {
            return "Premium Monthly"
        }
        return nil
    }
    
    // MARK: - Transaction Observation
    private func observeTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
                await updatePurchasedProducts()
            }
        }
    }
    
    // MARK: - Helper Methods
    func formatPrice(for product: Product) -> String {
        return product.displayPrice
    }
    
    func getProductTitle(for product: Product) -> String {
        switch product.id {
        case "com.calndr.premium.monthly":
            return "Premium Monthly"
        case "com.calndr.premium.yearly":
            return "Premium Yearly"
        default:
            return product.displayName
        }
    }
    
    func getProductDescription(for product: Product) -> String {
        switch product.id {
        case "com.calndr.premium.monthly":
            return "Full access to all premium features, billed monthly"
        case "com.calndr.premium.yearly":
            return "Full access to all premium features, billed yearly (Save 20%)"
        default:
            return product.description
        }
    }
} 