import SwiftUI

// ─── Model ───────────────────────────────────────────────────────────────────

private struct ClientSubscription: Decodable, Identifiable {
    let id: String
    let stripeSubscriptionId: String
    let trainerName: String
    let programTitle: String
    let monthlyAmountCents: Int
    let months: Int
    let freqPerWeek: Int
    let status: String
    let createdAt: String
    let currentPeriodEnd: String?
    let cancelAtPeriodEnd: Bool?

    var monthlyAmount: String {
        String(format: "$%.0f/mo", Double(monthlyAmountCents) / 100.0)
    }

    var statusLabel: String {
        switch status {
        case "active":      return cancelAtPeriodEnd == true ? "Cancels at period end" : "Active"
        case "past_due":    return "Payment past due"
        case "pending":     return "Activating"
        default:            return status.capitalized
        }
    }

    var statusColor: Color {
        switch status {
        case "active":   return cancelAtPeriodEnd == true ? Color(hex: "#F59E0B") : Color(hex: "#22C55E")
        case "past_due": return Color(hex: "#EF4444")
        default:         return Color(hex: "#94A3B8")
        }
    }

    var renewsLabel: String {
        guard let end = currentPeriodEnd else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: end)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: end)
        }
        guard let d = date else { return "" }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        let label = cancelAtPeriodEnd == true ? "Ends" : "Renews"
        return "\(label) \(display.string(from: d))"
    }
}

private struct SubscriptionListResponse: Decodable {
    let subscriptions: [ClientSubscription]
}

// ─── API ─────────────────────────────────────────────────────────────────────

private enum SubscriptionAPI {
    static func fetchAll(token: String) async throws -> [ClientSubscription] {
        guard let url = MontraAPIConfig.url(for: "/api/client/subscriptions") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        return try JSONDecoder().decode(SubscriptionListResponse.self, from: data).subscriptions
    }

    static func cancel(subscriptionId: String, token: String) async throws {
        guard let url = MontraAPIConfig.url(for: "/api/client/subscriptions/\(subscriptionId)") else { throw URLError(.badURL) }
        var req = URLRequest(url: url)
        req.httpMethod = "DELETE"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (_, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode < 300 else {
            throw URLError(.badServerResponse)
        }
    }
}

// ─── View ─────────────────────────────────────────────────────────────────────

struct SubscriptionManagementView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var subscriptions: [ClientSubscription] = []
    @State private var loading = true
    @State private var errorMessage: String?
    @State private var cancelTarget: ClientSubscription?
    @State private var cancelling = false
    @State private var cancelError: String?

    var body: some View {
        ZStack {
            Color.montraBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Nav
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.montraTextPrimary)
                    }
                    Spacer()
                    Text("My Plan")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                    Spacer()
                    Spacer().frame(width: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                if loading {
                    Spacer()
                    ProgressView().tint(.montraOrange)
                    Spacer()
                } else if let err = errorMessage {
                    Spacer()
                    Text(err)
                        .font(.system(size: 14))
                        .foregroundColor(.montraTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                } else if subscriptions.isEmpty {
                    emptyState
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 16) {
                            ForEach(subscriptions) { sub in
                                subscriptionCard(sub)
                            }
                            billingNote
                            Spacer(minLength: 40)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    }
                }
            }
        }
        .task { await loadSubscriptions() }
        .alert("Cancel Plan?", isPresented: Binding(
            get: { cancelTarget != nil },
            set: { if !$0 { cancelTarget = nil } }
        )) {
            Button("Cancel Plan", role: .destructive) {
                guard let sub = cancelTarget else { return }
                Task { await performCancel(sub) }
            }
            Button("Keep Plan", role: .cancel) { cancelTarget = nil }
        } message: {
            if let sub = cancelTarget {
                Text("Your \(sub.programTitle) plan will stay active until the end of the current billing period, then stop. You won't be charged again.")
            }
        }
        .alert("Error", isPresented: Binding(
            get: { cancelError != nil },
            set: { if !$0 { cancelError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cancelError ?? "")
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.montraBackground)
    }

    // MARK: - Subscription card

    @ViewBuilder
    private func subscriptionCard(_ sub: ClientSubscription) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sub.programTitle)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                    Text("with \(sub.trainerName)")
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)
                }
                Spacer()
                Text(sub.monthlyAmount)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.montraOrange)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)

            // Details
            VStack(spacing: 10) {
                detailRow(icon: "calendar", label: "\(sub.months)-month commitment · \(sub.freqPerWeek)x/week")
                if !sub.renewsLabel.isEmpty {
                    detailRow(icon: "arrow.clockwise", label: sub.renewsLabel)
                }
                HStack(spacing: 8) {
                    Circle()
                        .fill(sub.statusColor)
                        .frame(width: 8, height: 8)
                    Text(sub.statusLabel)
                        .font(.system(size: 13))
                        .foregroundColor(sub.statusColor)
                    Spacer()
                }
                .padding(.leading, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Cancel button — only if not already set to cancel
            if sub.status == "active" && sub.cancelAtPeriodEnd != true {
                Divider().background(Color.white.opacity(0.06)).padding(.horizontal, 16)

                Button {
                    cancelTarget = sub
                } label: {
                    HStack {
                        if cancelling && cancelTarget?.id == sub.id {
                            ProgressView().tint(Color(hex: "#EF4444")).scaleEffect(0.8)
                        }
                        Text("Cancel Plan")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Color(hex: "#EF4444"))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                }
                .disabled(cancelling)
            }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        )
    }

    @ViewBuilder
    private func detailRow(icon: String, label: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.montraTextSecondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.montraTextSecondary)
            Spacer()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "rectangle.stack.badge.minus")
                .font(.system(size: 48))
                .foregroundColor(.montraTextSecondary.opacity(0.4))
            VStack(spacing: 8) {
                Text("No active plans")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.montraTextPrimary)
                Text("When you enroll in a coaching program, your plan details and billing info will appear here.")
                    .font(.system(size: 14))
                    .foregroundColor(.montraTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Spacer()
        }
    }

    // MARK: - Billing note

    private var billingNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle")
                .font(.system(size: 13))
                .foregroundColor(.montraTextSecondary)
                .padding(.top, 1)
            Text("Billing is handled securely by Stripe. MONTRA does not store your payment card details. To update your card, contact support.")
                .font(.system(size: 12))
                .foregroundColor(.montraTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
        )
    }

    // MARK: - Actions

    private func loadSubscriptions() async {
        loading = true
        errorMessage = nil
        do {
            guard let result = try await auth.user?.getIDTokenResult(forcingRefresh: false) else {
                errorMessage = "Sign in to view your plan."
                loading = false
                return
            }
            subscriptions = try await SubscriptionAPI.fetchAll(token: result.token)
        } catch {
            errorMessage = "Couldn't load your plan. Please try again."
        }
        loading = false
    }

    private func performCancel(_ sub: ClientSubscription) async {
        cancelling = true
        do {
            guard let result = try await auth.user?.getIDTokenResult(forcingRefresh: false) else { return }
            try await SubscriptionAPI.cancel(subscriptionId: sub.stripeSubscriptionId, token: result.token)
            await loadSubscriptions()
        } catch {
            cancelError = "Couldn't cancel your plan. Please try again or contact support."
        }
        cancelling = false
        cancelTarget = nil
    }
}
