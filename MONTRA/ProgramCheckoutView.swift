import SwiftUI
import StripePaymentSheet

// MARK: - Models

struct ProgramPackage: Decodable {
    let commitments: [ProgramCommitment]
    let introSession: IntroSessionInfo?
}

struct ProgramCommitment: Decodable, Identifiable {
    let months: Int
    let title: String
    let emoji: String?
    let monthlyFrom: Double
    let freqStep: Double
    let features: [String]?
    var id: Int { months }
}

struct IntroSessionInfo: Decodable {
    let price: Double
    let durationMin: Int?
    let freeWithProgram: Bool?
}

enum PaymentPlan: String, CaseIterable, Identifiable {
    case monthly = "Monthly"
    case split = "Split (3-Pay)"
    case payInFull = "Pay in Full"
    var id: String { rawValue }
}

// MARK: - Main View

struct ProgramCheckoutView: View {
    let trainer: OnboardingTrainer
    let preselectedMonths: Int?
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var pkg: ProgramPackage? = nil
    @State private var loading = true
    @State private var commitment: ProgramCommitment? = nil
    @State private var freq: Int = 3
    @State private var paymentPlan: PaymentPlan = .monthly
    @State private var checkoutStep: CheckoutStep = .summary
    @State private var paymentSheet: PaymentSheet? = nil
    @State private var paymentSheetResult: PaymentSheetResult? = nil
    @State private var paymentLoading = false
    @State private var errorMessage: String? = nil

    enum CheckoutStep { case summary, plan, pay, booked }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if loading {
                    ProgressView().tint(.montraOrange)
                } else if let pkg, let commitment {
                    switch checkoutStep {
                    case .summary:  summaryStep(pkg: pkg, commitment: commitment)
                    case .plan:     planStep(pkg: pkg, commitment: commitment)
                    case .pay:      payStep(commitment: commitment)
                    case .booked:   bookedStep(commitment: commitment)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 14, weight: .bold)).foregroundColor(.montraTextSecondary)
                    }
                }
            }
        }
        .task { await loadPackages() }
    }

    // ── Step 1: Program Summary ───────────────────────────────────────────

    private func summaryStep(pkg: ProgramPackage, commitment: ProgramCommitment) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 4) {
                    Text("Start Your Program").font(.system(size: 26, weight: .black)).foregroundColor(.montraTextPrimary)
                    Text("with \(trainer.name.components(separatedBy: " ").first ?? trainer.name)").font(.system(size: 16)).foregroundColor(.montraTextSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 24)
                .padding(.bottom, 20)

                // Coach card
                HStack(spacing: 14) {
                    coachAvatar(size: 56, cornerRadius: 16)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(trainer.name).font(.system(size: 16, weight: .bold)).foregroundColor(.montraTextPrimary)
                        Text(trainer.certification).font(.system(size: 13)).foregroundColor(.montraTextSecondary)
                        Label((trainer.locations.first ?? ""), systemImage: "mappin.fill").font(.system(size: 12)).foregroundColor(.montraTextSecondary)
                    }
                    Spacer()
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 20)

                Spacer().frame(height: 20)

                // Program card selector
                Text("Choose Your Program").font(.system(size: 15, weight: .bold)).foregroundColor(.montraTextPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 20).padding(.bottom, 10)

                ForEach(pkg.commitments) { c in
                    commitmentCard(c, selected: c.months == commitment.months)
                        .padding(.horizontal, 20).padding(.bottom, 8)
                        .onTapGesture { self.commitment = c }
                }

                // Free intro banner
                if pkg.introSession?.freeWithProgram == true {
                    HStack(spacing: 10) {
                        Image(systemName: "gift.fill").foregroundColor(.montraOrange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("FREE Intro Session Included").font(.system(size: 14, weight: .bold)).foregroundColor(.montraTextPrimary)
                            Text("Your first session (\(Int(pkg.introSession?.price ?? 149)) value) is FREE when you start a program.").font(.system(size: 12)).foregroundColor(.montraTextSecondary)
                        }
                    }
                    .padding(14)
                    .background(Color.montraOrange.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.montraOrange.opacity(0.3), lineWidth: 1))
                    .padding(.horizontal, 20).padding(.top, 4)
                }

                Spacer().frame(height: 28)
                ctaButton("Continue") { checkoutStep = .plan }
                    .padding(.horizontal, 20).padding(.bottom, 40)
            }
        }
    }

    private func commitmentCard(_ c: ProgramCommitment, selected: Bool) -> some View {
        let monthlyPrice = Int((c.monthlyFrom + Double(max(freq - 1, 0)) * c.freqStep).rounded(.toNearestOrAwayFromZero) / 10) * 10
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(c.emoji ?? "🏆").font(.system(size: 22))
                VStack(alignment: .leading, spacing: 2) {
                    Text(c.title).font(.system(size: 15, weight: .bold)).foregroundColor(.montraTextPrimary)
                    Text("\(c.months) month commitment").font(.system(size: 12)).foregroundColor(.montraTextSecondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("from $\(monthlyPrice)").font(.system(size: 15, weight: .black)).foregroundColor(.montraTextPrimary)
                    Text("/month").font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                }
                if selected {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 18)).foregroundColor(.montraOrange)
                }
            }
            if let features = c.features, !features.isEmpty {
                HStack(spacing: 8) {
                    ForEach(features.prefix(2), id: \.self) { f in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(.green)
                            Text(f).font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(selected ? Color.montraOrange.opacity(0.1) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? Color.montraOrange : Color.white.opacity(0.12), lineWidth: selected ? 2 : 1))
    }

    // ── Step 2: Payment Plan ──────────────────────────────────────────────

    private func planStep(pkg: ProgramPackage, commitment: ProgramCommitment) -> some View {
        let monthlyPrice = roundedMonthly(commitment)
        let totalPrice = monthlyPrice * commitment.months
        return ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                stepHeader("Choose Payment Plan", subtitle: commitment.title, back: { checkoutStep = .summary })

                // Freq picker
                VStack(alignment: .leading, spacing: 10) {
                    Text("Sessions Per Week").font(.system(size: 14, weight: .semibold)).foregroundColor(.montraTextSecondary)
                    HStack(spacing: 8) {
                        ForEach([2, 3, 4, 5], id: \.self) { n in
                            Button {
                                freq = n
                            } label: {
                                Text("\(n)x").font(.system(size: 14, weight: .bold))
                                    .frame(maxWidth: .infinity).frame(height: 40)
                                    .background(freq == n ? Color.montraOrange : Color.white.opacity(0.07))
                                    .foregroundColor(freq == n ? .black : .montraTextPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20).padding(.bottom, 14)

                // Plan options
                VStack(alignment: .leading, spacing: 10) {
                    Text("Payment Structure").font(.system(size: 14, weight: .semibold)).foregroundColor(.montraTextSecondary)
                    ForEach(PaymentPlan.allCases) { plan in
                        planOptionRow(plan: plan, monthlyPrice: monthlyPrice, totalPrice: totalPrice, months: commitment.months)
                            .onTapGesture { paymentPlan = plan }
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 24)

                // Summary
                orderSummary(commitment: commitment, monthlyPrice: monthlyPrice, totalPrice: totalPrice, introFree: pkg.introSession?.freeWithProgram == true, introPrice: pkg.introSession?.price ?? 149)
                    .padding(.horizontal, 20)

                Spacer().frame(height: 28)
                ctaButton("Proceed to Checkout") {
                    Task { await preparePayment(commitment: commitment) }
                }
                .padding(.horizontal, 20).padding(.bottom, 40)

                if paymentLoading {
                    HStack(spacing: 10) {
                        ProgressView().tint(.montraOrange)
                        Text("Preparing checkout…").font(.system(size: 13)).foregroundColor(.montraTextSecondary)
                    }
                    .padding(.bottom, 20)
                }

                if let err = errorMessage {
                    Text(err).font(.system(size: 13, weight: .semibold)).foregroundColor(.red)
                        .multilineTextAlignment(.center).padding(.horizontal, 20).padding(.bottom, 12)
                }
            }
        }
    }

    private func planOptionRow(plan: PaymentPlan, monthlyPrice: Int, totalPrice: Int, months: Int) -> some View {
        let selected = paymentPlan == plan
        let (label, detail, badge): (String, String, String?) = {
            switch plan {
            case .monthly: return ("$\(monthlyPrice)/month", "\(months) monthly payments", nil)
            case .split:
                let payment = (totalPrice / 3).roundedToNearest(10)
                return ("$\(payment)", "3 payments over \(months) months", "Save \(savePct(monthly: monthlyPrice, months: months, splitCount: 3))%")
            case .payInFull:
                let fullPrice = (Double(totalPrice) * 0.90).roundedToNearest(10)
                return ("$\(fullPrice) total", "One payment, best value", "Save 10%")
            }
        }()
        return HStack(spacing: 12) {
            ZStack {
                Circle().stroke(selected ? Color.montraOrange : Color.white.opacity(0.25), lineWidth: 2)
                    .frame(width: 20, height: 20)
                if selected {
                    Circle().fill(Color.montraOrange).frame(width: 11, height: 11)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(plan.rawValue).font(.system(size: 15, weight: .bold)).foregroundColor(.montraTextPrimary)
                    if let badge {
                        Text(badge).font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.green.opacity(0.15)).foregroundColor(.green)
                            .clipShape(Capsule())
                    }
                }
                Text(detail).font(.system(size: 12)).foregroundColor(.montraTextSecondary)
            }
            Spacer()
            Text(label).font(.system(size: 14, weight: .black)).foregroundColor(.montraTextPrimary)
        }
        .padding(14)
        .background(selected ? Color.montraOrange.opacity(0.08) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? Color.montraOrange.opacity(0.6) : Color.white.opacity(0.1), lineWidth: 1))
    }

    private func orderSummary(commitment: ProgramCommitment, monthlyPrice: Int, totalPrice: Int, introFree: Bool, introPrice: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Order Summary").font(.system(size: 13, weight: .bold)).foregroundColor(.montraTextSecondary)
            row("Program", value: commitment.title)
            row("\(freq)x sessions/week", value: "")
            row("Coach", value: trainer.name)
            if introFree {
                HStack {
                    Text("Intro Session (60 min)")
                        .font(.system(size: 13)).foregroundColor(.montraTextSecondary)
                    Spacer()
                    Text("$\(Int(introPrice))").font(.system(size: 13)).foregroundColor(.montraTextSecondary).strikethrough()
                    Text("FREE").font(.system(size: 13, weight: .bold)).foregroundColor(.green).padding(.leading, 4)
                }
            }
            Divider().background(Color.white.opacity(0.1))
            HStack {
                Text("First Payment").font(.system(size: 14, weight: .black)).foregroundColor(.montraTextPrimary)
                Spacer()
                Text(firstPaymentLabel(monthlyPrice: monthlyPrice, totalPrice: totalPrice)).font(.system(size: 16, weight: .black)).foregroundColor(.montraOrange)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // ── Step 3: Payment (Stripe PaymentSheet) ─────────────────────────────

    private func payStep(commitment: ProgramCommitment) -> some View {
        VStack(spacing: 0) {
            stepHeader("Checkout", subtitle: nil, back: { checkoutStep = .plan })
            Spacer()
            VStack(spacing: 20) {
                Image(systemName: "creditcard.fill").font(.system(size: 48)).foregroundColor(.montraOrange)
                Text("Payment Ready").font(.system(size: 22, weight: .black)).foregroundColor(.montraTextPrimary)
                Text("Tap below to complete your payment securely.").font(.system(size: 14)).foregroundColor(.montraTextSecondary).multilineTextAlignment(.center)
                if let paymentSheet {
                    PaymentSheet.PaymentButton(paymentSheet: paymentSheet, onCompletion: handlePaymentResult) {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill").font(.system(size: 14))
                            Text("Pay Securely with Stripe")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.montraOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 28)
                    }
                } else if paymentLoading {
                    ProgressView().tint(.montraOrange)
                } else {
                    Text(errorMessage ?? "Unable to initialize payment. Please try again.")
                        .font(.system(size: 13)).foregroundColor(.red).multilineTextAlignment(.center).padding(.horizontal, 28)
                    ctaButton("Try Again") { Task { await preparePayment(commitment: commitment) } }.padding(.horizontal, 28)
                }
            }
            .padding(.horizontal, 20)
            Spacer()
            Text("🔒 Secured by Stripe").font(.system(size: 12)).foregroundColor(.montraTextSecondary).padding(.bottom, 40)
        }
    }

    // ── Step 4: Booked! ────────────────────────────────────────────────────

    private func bookedStep(commitment: ProgramCommitment) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color.green.opacity(0.15)).frame(width: 100, height: 100)
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 64)).foregroundColor(.green)
                }
                Text("You're All Set! 🎉").font(.system(size: 28, weight: .black)).foregroundColor(.montraTextPrimary)
                Text("Your \(commitment.title) program with \(trainer.name.components(separatedBy: " ").first ?? trainer.name) is confirmed.").font(.system(size: 15)).foregroundColor(.montraTextSecondary).multilineTextAlignment(.center)

                // Summary card
                VStack(spacing: 12) {
                    bookedRow(icon: "person.fill", label: "Coach", value: trainer.name)
                    bookedRow(icon: "calendar", label: "Program", value: commitment.title)
                    bookedRow(icon: "repeat", label: "Frequency", value: "\(freq)x sessions/week")
                    bookedRow(icon: "gift.fill", label: "Free Intro", value: "Included · Scheduling Soon")
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 24)

                // App download CTA
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12).fill(Color.montraOrange).frame(width: 48, height: 48)
                        Text("M").font(.system(size: 22, weight: .black)).foregroundColor(.black)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Get the full MONTRA experience").font(.system(size: 13, weight: .bold)).foregroundColor(.montraTextPrimary)
                        Text("Track progress, chat with your coach, and more.").font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                    }
                }
                .padding(14)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)

                ctaButton("Go to Dashboard") { dismiss() }.padding(.horizontal, 20)
            }
            Spacer()
        }
    }

    // ── Helpers ──────────────────────────────────────────────────────────

    private func stepHeader(_ title: String, subtitle: String?, back: (() -> Void)?) -> some View {
        HStack(spacing: 12) {
            if let back {
                Button(action: back) {
                    Image(systemName: "chevron.left").font(.system(size: 14, weight: .semibold)).foregroundColor(.montraTextSecondary)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 22, weight: .black)).foregroundColor(.montraTextPrimary)
                if let subtitle {
                    Text(subtitle).font(.system(size: 13)).foregroundColor(.montraTextSecondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 16)
    }

    @ViewBuilder
    private func coachAvatar(size: CGFloat, cornerRadius: CGFloat) -> some View {
        if !trainer.photoDataUrl.isEmpty, let data = Data(base64Encoded: trainer.photoDataUrl.components(separatedBy: ",").last ?? ""), let uiImg = UIImage(data: data) {
            Image(uiImage: uiImg).resizable().scaledToFill().frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius).fill(Color(hex: trainer.accentHex))
                Text(trainer.initials).font(.system(size: size * 0.36, weight: .black)).foregroundColor(.white)
            }
            .frame(width: size, height: size)
        }
    }

    private func ctaButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.system(size: 16, weight: .bold)).foregroundColor(.black)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(Color.montraOrange).clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func row(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundColor(.montraTextSecondary)
            Spacer()
            if !value.isEmpty { Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(.montraTextPrimary) }
        }
    }

    private func bookedRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 14)).foregroundColor(.montraOrange).frame(width: 20)
            Text(label).font(.system(size: 13)).foregroundColor(.montraTextSecondary)
            Spacer()
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundColor(.montraTextPrimary).multilineTextAlignment(.trailing)
        }
    }

    private func roundedMonthly(_ c: ProgramCommitment) -> Int {
        Int((c.monthlyFrom + Double(max(freq - 1, 0)) * c.freqStep).rounded(.toNearestOrAwayFromZero) / 10) * 10
    }

    private func firstPaymentLabel(monthlyPrice: Int, totalPrice: Int) -> String {
        switch paymentPlan {
        case .monthly: return "$\(monthlyPrice)"
        case .split:   return "$\((totalPrice / 3).roundedToNearest(10))"
        case .payInFull: return "$\(Int((Double(totalPrice) * 0.90).roundedToNearest(10)))"
        }
    }

    private func savePct(monthly: Int, months: Int, splitCount: Int) -> Int {
        let fullCost = monthly * months
        let splitCost = (fullCost / splitCount).roundedToNearest(10) * splitCount
        let saved = fullCost - splitCost
        return Int((Double(saved) / Double(fullCost) * 100).rounded())
    }

    // ── Networking ────────────────────────────────────────────────────────

    private func loadPackages() async {
        guard let url = MontraAPIConfig.url(for: "/api/trainers/\(trainer.id)/packages") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let result = try JSONDecoder().decode(ProgramPackage.self, from: data)
            await MainActor.run {
                pkg = result
                commitment = result.commitments.first(where: { $0.months == preselectedMonths }) ?? result.commitments.first
                loading = false
            }
        } catch {
            await MainActor.run { loading = false }
        }
    }

    private func preparePayment(commitment: ProgramCommitment) async {
        await MainActor.run { paymentLoading = true; errorMessage = nil }
        do {
            // Fetch publishable key
            guard let cfgURL = MontraAPIConfig.url(for: "/api/stripe/config") else { throw URLError(.badURL) }
            let (cfgData, _) = try await URLSession.shared.data(from: cfgURL)
            struct StripeConfig: Decodable { let publishableKey: String? }
            let cfg = try JSONDecoder().decode(StripeConfig.self, from: cfgData)
            guard let pk = cfg.publishableKey else {
                await MainActor.run {
                    paymentLoading = false
                    errorMessage = "Payment is being configured. Please contact us to complete your enrollment."
                    checkoutStep = .pay
                }
                return
            }

            // Create PaymentIntent
            guard let piURL = MontraAPIConfig.url(for: "/api/payments/program") else { throw URLError(.badURL) }
            var req = URLRequest(url: piURL)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: [
                "trainerId": trainer.id,
                "months": commitment.months,
                "freqPerWeek": freq
            ])
            let (piData, _) = try await URLSession.shared.data(for: req)
            struct PIResponse: Decodable { let clientSecret: String }
            let pi = try JSONDecoder().decode(PIResponse.self, from: piData)

            // Configure Stripe
            STPAPIClient.shared.publishableKey = pk
            var config = PaymentSheet.Configuration()
            config.merchantDisplayName = "Elite Home Fitness / MONTRA"
            config.primaryButtonColor = UIColor(Color.montraOrange)
            config.allowsDelayedPaymentMethods = false

            let sheet = PaymentSheet(paymentIntentClientSecret: pi.clientSecret, configuration: config)
            await MainActor.run {
                paymentSheet = sheet
                paymentLoading = false
                checkoutStep = .pay
            }
        } catch {
            await MainActor.run {
                paymentLoading = false
                errorMessage = "Could not prepare checkout: \(error.localizedDescription)"
                checkoutStep = .pay
            }
        }
    }

    private func handlePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            checkoutStep = .booked
        case .canceled:
            break
        case .failed(let error):
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Extensions

extension Int {
    func roundedToNearest(_ nearest: Int) -> Int {
        guard nearest > 0 else { return self }
        return (self + nearest / 2) / nearest * nearest
    }
}

extension Double {
    func roundedToNearest(_ nearest: Int) -> Double {
        let n = Double(nearest)
        return (self / n).rounded() * n
    }
}


#Preview {
    ProgramCheckoutView(trainer: OnboardingTrainer(
        id: "preview", name: "Alex Rivera", initials: "AR",
        certification: "NASM-CPT", bio: "", specialties: ["Strength Training"],
        locations: ["Boston, MA"], gender: "Male", accentHex: "#E85D04"
    ), preselectedMonths: 6)
}
