import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @StateObject private var storeManager = StoreKitManager()
    @Environment(\.dismiss) private var dismiss
    @State private var showingManageSubscriptions = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                        
                        Text("Premium Subscription")
                            .font(.title.bold())
                        
                        Text("Unlock all premium features and get the most out of your calendar app")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)
                    
                    // Current Subscription Status
                    if storeManager.isPremiumActive() {
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Active Subscription")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }
                            
                            if let subscription = storeManager.getActiveSubscription() {
                                Text(subscription)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            
                            Button("Manage Subscription") {
                                showingManageSubscriptions = true
                            }
                            .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Premium Features
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Premium Features")
                            .font(.headline)
                        
                        FeatureRow(icon: "calendar.badge.plus", title: "Unlimited Events", description: "Create as many events as you need")
                        FeatureRow(icon: "person.2.fill", title: "Family Sharing", description: "Share calendars with family members")
                        FeatureRow(icon: "bell.fill", title: "Advanced Notifications", description: "Custom notification settings")
                        FeatureRow(icon: "paintbrush.fill", title: "Custom Themes", description: "Personalize your calendar appearance")
                        FeatureRow(icon: "icloud.fill", title: "Cloud Sync", description: "Sync across all your devices")
                        FeatureRow(icon: "chart.bar.fill", title: "Analytics", description: "Insights into your schedule")
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Subscription Options
                    if !storeManager.isPremiumActive() {
                        VStack(spacing: 16) {
                            Text("Choose Your Plan")
                                .font(.headline)
                            
                            if storeManager.isLoading {
                                ProgressView("Loading subscription options...")
                                    .frame(height: 100)
                            } else {
                                ForEach(storeManager.products, id: \.id) { product in
                                    SubscriptionCard(
                                        product: product,
                                        storeManager: storeManager
                                    )
                                }
                            }
                            
                            if let errorMessage = storeManager.errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    
                    // Restore Purchases Button
                    Button("Restore Purchases") {
                        Task {
                            await storeManager.restorePurchases()
                        }
                    }
                    .foregroundColor(.blue)
                    .padding(.top)
                    
                    // Terms and Privacy
                    VStack(spacing: 8) {
                        Text("By subscribing, you agree to our Terms of Service and Privacy Policy. Subscriptions auto-renew unless cancelled.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 20) {
                            Button("Terms of Service") {
                                // Open terms of service
                            }
                            .font(.caption2)
                            .foregroundColor(.blue)
                            
                            Button("Privacy Policy") {
                                // Open privacy policy
                            }
                            .font(.caption2)
                            .foregroundColor(.blue)
                        }
                    }
                    .padding(.top)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await storeManager.requestProducts()
            }
        }
        .manageSubscriptionsSheet(isPresented: $showingManageSubscriptions)
    }
}

struct SubscriptionCard: View {
    let product: Product
    let storeManager: StoreKitManager
    @State private var isPurchasing = false
    
    var isYearly: Bool {
        product.id.contains("yearly")
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(storeManager.getProductTitle(for: product))
                        .font(.headline)
                    
                    Text(storeManager.getProductDescription(for: product))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(storeManager.formatPrice(for: product))
                        .font(.title2.bold())
                    
                    if isYearly {
                        Text("Save 20%")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            Button(action: {
                Task {
                    isPurchasing = true
                    let success = await storeManager.purchase(product)
                    isPurchasing = false
                    
                    if success {
                        // Purchase successful - the UI will update automatically
                        // via the StoreKitManager's published properties
                    }
                }
            }) {
                HStack {
                    if isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(isPurchasing ? "Processing..." : "Subscribe")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isYearly ? Color.orange : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            .disabled(isPurchasing)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isYearly ? Color.orange : Color.clear, lineWidth: 2)
        )
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    SubscriptionView()
} 