//
//  TransactionHistoryView.swift
//  DreamSpire
//
//  İşlem Geçmişi - Coin harcama ve kazanma geçmişi
//

import SwiftUI
import Shimmer

struct TransactionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = TransactionHistoryViewModel()

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.dwPurple, Color.dwPink]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Custom Navigation Bar - Fixed at top
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.2))
                            .clipShape(Circle())
                    }

                    Spacer()

                    Text("transaction_history".localized)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    // Balance for spacing
                    Color.clear
                        .frame(width: 36, height: 36)
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
                .background(Color.clear) // Keep header transparent but stable

                // Content - This area loads below the fixed header
                ZStack {
                    if viewModel.isLoading {
                        loadingView
                    } else if viewModel.transactions.isEmpty {
                        emptyStateView
                    } else {
                        transactionListView
                    }
                }
                .frame(maxHeight: .infinity) // Fill remaining space
            }
        }
        .task {
            await viewModel.loadTransactions()
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<15, id: \.self) { _ in
                    TransactionSkeletonRow()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.4))

            Text("no_transactions".localized)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("no_transactions_desc".localized)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Transaction List
    private var transactionListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.transactions) { transaction in
                    TransactionRow(transaction: transaction)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8) // DÜZELTME: Tutarlı spacing
            .padding(.bottom, 20)
        }
    }
}

// MARK: - Transaction Skeleton Row
struct TransactionSkeletonRow: View {
    var body: some View {
        HStack(spacing: 12) {
            // Icon placeholder
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 44, height: 44)
                .shimmering(
                    active: true,
                    animation: .easeInOut(duration: 1.8).repeatForever(autoreverses: false)
                )

            // Info placeholders
            VStack(alignment: .leading, spacing: 6) {
                // Title placeholder
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 160, height: 15)
                    .shimmering(
                        active: true,
                        animation: .easeInOut(duration: 1.8).repeatForever(autoreverses: false)
                    )

                // Date placeholder
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 100, height: 13)
                    .shimmering(
                        active: true,
                        animation: .easeInOut(duration: 1.8).repeatForever(autoreverses: false)
                    )
            }

            Spacer()

            // Amount placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.white.opacity(0.2))
                .frame(width: 60, height: 16)
                .shimmering(
                    active: true,
                    animation: .easeInOut(duration: 1.8).repeatForever(autoreverses: false)
                )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.1)) // DÜZELTME: TransactionRow ile aynı background
        )
    }
}

// MARK: - Transaction Row
struct TransactionRow: View {
    let transaction: CoinTransaction

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: iconName)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconColor.opacity(0.2))
                .clipShape(Circle())

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.displayReason)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text(formattedDate)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            // Amount
            Text(amountText)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(amountColor)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.15))
        )
    }

    private var iconName: String {
        transaction.type.icon
    }

    private var iconColor: Color {
        transaction.type.swiftUIColor
    }

    private var amountText: String {
        transaction.displayAmount
    }

    private var amountColor: Color {
        transaction.type.swiftUIColor
    }

    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: transaction.timestamp, relativeTo: Date())
    }
}

// MARK: - ViewModel
@MainActor
class TransactionHistoryViewModel: ObservableObject {
    @Published var transactions: [CoinTransaction] = []
    @Published var isLoading = false
    @Published var error: String?

    // MARK: - Dependencies (Repository Pattern)

    private let repository = CoinTransactionRepository.shared

    // MARK: - State Tracking

    private var hasLoaded = false

    // MARK: - Load Logic

    /// Load transactions with intelligent caching
    /// Only loads once unless forceRefresh is true
    func loadTransactions(forceRefresh: Bool = false) async {
        // Skip if already loaded and not forcing refresh
        guard forceRefresh || !hasLoaded else {
            DWLogger.shared.debug("✅ Transactions already loaded, using cache", category: .coin)
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // Repository automatically handles caching!
            transactions = try await repository.getTransactions(forceRefresh: forceRefresh)
            hasLoaded = true
            DWLogger.shared.info("✅ Loaded \(transactions.count) transactions", category: .coin)
        } catch {
            self.error = error.localizedDescription
            DWLogger.shared.error("Failed to load transactions", error: error, category: .coin)

            // Keep transactions empty on error so empty state shows
            transactions = []
        }
    }

    /// Manual refresh for pull-to-refresh
    func refresh() async {
        await loadTransactions(forceRefresh: true)
    }
}

// MARK: - Preview
#Preview {
    TransactionHistoryView()
}

#Preview("Skeleton Loading") {
    ZStack {
        LinearGradient(
            gradient: Gradient(colors: [Color.dwPurple, Color.dwPink]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<15, id: \.self) { _ in
                    TransactionSkeletonRow()
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
    }
}
