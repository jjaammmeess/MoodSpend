import Combine
import StoreKit
import SwiftUI

// MARK: - Product identifiers (App Store Connect)

/// In-App Purchase product IDs for AfterBuy Pro. IDs are immutable after App Store Connect creation.
enum ProProductID {
    /// Auto-renewable subscription (e.g. CN ¥38/year).
    static let annual = "JamesLiu.AfterBuy.pro.annual"
    /// Non-consumable lifetime unlock (e.g. CN ¥58).
    static let lifetime = "JamesLiu.AfterBuy.pro.lifetime"

    static let all: [String] = [annual, lifetime]
}

// MARK: - Purchase outcome (UI-facing, non-throwing for cancel)

/// Result of `purchase(_:)` for paywall / settings UI — cancellation is not an error.
enum PurchaseResult {
    case success
    case cancelled
    case pending
}

// MARK: - Errors

enum SubscriptionManagerError: LocalizedError {
    case failedVerification

    var errorDescription: String? {
        switch self {
        case .failedVerification:
            return "Purchase verification failed."
        }
    }
}

// MARK: - SubscriptionManager

/// StoreKit 2 subscription and lifetime purchase coordinator.
///
/// **Source of truth:** `Transaction.currentEntitlements` (refreshed on launch, restore, and `Transaction.updates`).
/// **`@AppStorage("isProUser")`:** cold-start cache only; always reconciled against entitlements.
@MainActor
final class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    private static let proCacheKey = "isProUser"

    // MARK: Published state

    /// Global Pro gate for premium features. Synced with entitlements and local cache.
    @Published var isPro: Bool = false

    /// Loaded IAP products, sorted ascending by `Product.price`.
    @Published private(set) var products: [Product] = []

    // MARK: Local cache (cold start)

    @AppStorage(SubscriptionManager.proCacheKey) private var cachedIsProUser: Bool = false

    // MARK: Background listening

    private var updatesTask: Task<Void, Never>?

    // MARK: Lifecycle

    private init() {
        // First frame: use cached value so UI can unlock immediately offline.
        isPro = cachedIsProUser
        updatesTask = listenToTransactions()

        // Reconcile with App Store as soon as the singleton exists.
        Task {
            await updatePurchasedIdentifiers()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    // MARK: - Catalog

    /// Fetches configured products from the App Store and stores them sorted by price (low → high).
    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: ProProductID.all)
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            products = []
        }
    }

    // MARK: - Purchase

    /// Starts the StoreKit purchase flow for `product`.
    ///
    /// - Returns: `.success` after verification and `finish()`; `.cancelled` for user dismiss; `.pending` for Ask to Buy, etc.
    /// - Throws: Verification failures and other StoreKit errors (not user cancellation).
    func purchase(_ product: Product) async throws -> PurchaseResult {
        do {
            let result = try await product.purchase()
            return try await handlePurchaseResult(result)
        } catch {
            if isUserCancellation(error) {
                return .cancelled
            }
            throw error
        }
    }

    // MARK: - Entitlements & restore

    /// Recomputes `isPro` from `Transaction.currentEntitlements` (launch, renewals, refunds).
    func updatePurchasedIdentifiers() async {
        let pro = await computeProFromCurrentEntitlements()
        applyProStatus(pro)
    }

    /// Settings “Restore Purchases”: syncs with App Store then refreshes entitlements.
    func restorePurchases() async throws {
        try await AppStore.sync()
        await updatePurchasedIdentifiers()
    }

    // MARK: - Transaction.updates listener

    /// Long-lived listener for out-of-app purchases, renewals, refunds, and parental approvals.
    private func listenToTransactions() -> Task<Void, Never> {
        Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard let self else { return }
                await self.processTransactionUpdate(update)
            }
        }
    }

    // MARK: - Private: entitlement evaluation

    /// Walks current entitlements; lifetime or a valid yearly subscription grants Pro.
    private func computeProFromCurrentEntitlements() async -> Bool {
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(entitlement) else { continue }
            if transactionGrantsPro(transaction) {
                return true
            }
        }
        return false
    }

    /// Whether a verified transaction still grants Pro (not revoked; subscription not expired).
    private func transactionGrantsPro(_ transaction: StoreKit.Transaction) -> Bool {
        guard transaction.revocationDate == nil else { return false }

        switch transaction.productID {
        case ProProductID.lifetime:
            return true
        case ProProductID.annual:
            guard let expiration = transaction.expirationDate else { return false }
            return expiration > Date()
        default:
            return false
        }
    }

    // MARK: - Private: purchase handling

    private func handlePurchaseResult(_ result: Product.PurchaseResult) async throws -> PurchaseResult {
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedIdentifiers()
            await transaction.finish()
            return .success

        case .userCancelled:
            return .cancelled

        case .pending:
            return .pending

        @unknown default:
            return .cancelled
        }
    }

    private func processTransactionUpdate(_ update: VerificationResult<StoreKit.Transaction>) async {
        do {
            let transaction = try checkVerified(update)
            await updatePurchasedIdentifiers()
            await transaction.finish()
        } catch {
            // Unverified updates are ignored; entitlements remain unchanged until a valid transaction arrives.
        }
    }

    // MARK: - Private: Pro status sync

    /// Writes Pro state to `@Published` and `UserDefaults` cache together (upgrade or downgrade).
    private func applyProStatus(_ pro: Bool) {
        guard isPro != pro || cachedIsProUser != pro else { return }
        isPro = pro
        cachedIsProUser = pro
    }

    // MARK: - Private: verification

    /// Unwraps a JWS-verified StoreKit payload; throws on tampering or validation failure.
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionManagerError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    private func isUserCancellation(_ error: Error) -> Bool {
        if let storeKit = error as? StoreKitError, case .userCancelled = storeKit {
            return true
        }
        return false
    }
}
