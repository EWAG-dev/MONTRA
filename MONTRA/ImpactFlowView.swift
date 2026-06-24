import SwiftUI

/// The post-booking Impact Credit experience: Session Confirmed → Direct Your
/// Impact → Impact Confirmed. Also reusable to direct a still-pending credit
/// later (pass `startAtDirect: true`).
struct ImpactFlowView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    let session: BookedSession?
    @State private var credit: ImpactCredit
    private let startAtDirect: Bool

    enum Step { case confirmed, direct, thanks }
    @State private var step: Step = .confirmed
    @State private var splitMode = false
    @State private var isDirecting = false
    @State private var directingCauseId: String?
    @State private var actionError: String?
    @State private var showGiftPrompt = false
    @State private var giftEmail = ""
    @State private var showSummary = false

    private let gold = Color(hex: "#C9A063")

    init(session: BookedSession?, credit: ImpactCredit, startAtDirect: Bool = false) {
        self.session = session
        self._credit = State(initialValue: credit)
        self.startAtDirect = startAtDirect
    }

    var body: some View {
        ZStack {
            Color.montraBackground.ignoresSafeArea()
            switch step {
            case .confirmed: confirmedScreen
            case .direct: directScreen
            case .thanks: thanksScreen
            }
        }
        .onAppear {
            if credit.isDirected { step = .thanks }
            else if startAtDirect { step = .direct }
        }
        .alert("Gift this credit", isPresented: $showGiftPrompt) {
            TextField("Friend's email", text: $giftEmail)
                .textInputAutocapitalization(.never)
                .keyboardType(.emailAddress)
            Button("Cancel", role: .cancel) {}
            Button("Send Gift") { Task { await direct(type: "gift", giftEmail: giftEmail) } }
        } message: {
            Text("We'll let them know a MONTRA Impact Credit is waiting for them.")
        }
        .sheet(isPresented: $showSummary) {
            ImpactSummaryView()
        }
    }

    // MARK: - Screen 1: Session Confirmed

    private var confirmedScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                ZStack {
                    Circle().stroke(gold, lineWidth: 3).frame(width: 116, height: 116)
                    Image(systemName: "checkmark").font(.system(size: 46, weight: .bold)).foregroundColor(gold)
                }
                .padding(.top, 44)

                VStack(spacing: 6) {
                    Text("You're all set!").font(.system(size: 26, weight: .bold)).foregroundColor(.montraTextPrimary)
                    Text("Your session is confirmed.").font(.system(size: 15)).foregroundColor(.montraTextSecondary)
                }

                sessionDetailsCard
                impactUnlockedCard

                Button { withAnimation { step = .direct } } label: {
                    Text("DIRECT MY IMPACT")
                        .font(.system(size: 15, weight: .bold)).kerning(0.5)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(gold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button("View Booking Details") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(gold)

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 22)
        }
    }

    private var sessionDetailsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Session Details").font(.system(size: 15, weight: .bold)).foregroundColor(gold)
            detailRow(icon: "person", title: "Coach", value: session?.trainerName.isEmpty == false ? session!.trainerName : "Your Coach")
            detailRow(icon: "calendar", title: "Date", value: dateText)
            detailRow(icon: "clock", title: "Time", value: timeText)
            detailRow(icon: "mappin.and.ellipse", title: "Location", value: "In-Home Session")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .montraCard(radius: 16)
    }

    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).font(.system(size: 15)).foregroundColor(gold).frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                Text(value).font(.system(size: 14, weight: .semibold)).foregroundColor(.montraTextPrimary)
            }
            Spacer()
        }
    }

    private var impactUnlockedCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("You've unlocked a").font(.system(size: 12)).foregroundColor(.montraTextSecondary)
                Text("\(credit.amountLabel) Impact Credit").font(.system(size: 19, weight: .bold)).foregroundColor(gold)
            }
            Spacer()
            Image(systemName: "heart.circle.fill").font(.system(size: 30)).foregroundColor(gold)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(gold.opacity(0.10))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(gold.opacity(0.35), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Screen 2: Direct Your Impact

    private var directScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Button { withAnimation { step = .confirmed } } label: {
                        Image(systemName: "chevron.left").font(.system(size: 18, weight: .semibold)).foregroundColor(.montraTextPrimary)
                    }
                    Spacer()
                    VStack(spacing: 2) {
                        Text("DIRECT YOUR").font(.system(size: 12, weight: .semibold)).foregroundColor(.montraTextSecondary).kerning(1)
                        Text("\(credit.amountLabel) Impact Credit").font(.system(size: 20, weight: .bold)).foregroundColor(gold)
                    }
                    Spacer()
                    Image(systemName: "chevron.left").opacity(0)
                }
                .padding(.top, 18)

                Text("Choose a cause that matters most to you.")
                    .font(.system(size: 14)).foregroundColor(.montraTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)

                Picker("", selection: $splitMode) {
                    Text("Donate fully").tag(false)
                    Text("Split 50/50").tag(true)
                }
                .pickerStyle(.segmented)

                if splitMode {
                    Text("Half goes to your chosen cause, half toward your future coaching.")
                        .font(.system(size: 12)).foregroundColor(.montraTextSecondary)
                }

                VStack(spacing: 12) {
                    ForEach(ImpactCause.all) { cause in
                        causeRow(cause)
                    }
                }

                Text("OTHER WAYS TO DIRECT")
                    .font(.system(size: 11, weight: .semibold)).foregroundColor(.montraTextSecondary).kerning(0.8)
                    .padding(.top, 6)

                optionRow(icon: "figure.strengthtraining.traditional", color: Color(hex: "#4CAF50"),
                          title: "Apply toward future coaching",
                          subtitle: "Put your credit toward your own training.") {
                    Task { await direct(type: "coaching") }
                }
                optionRow(icon: "gift.fill", color: gold,
                          title: "Gift to a friend",
                          subtitle: "Pass your credit on to someone you care about.") {
                    showGiftPrompt = true
                }

                if let actionError {
                    Text(actionError).font(.system(size: 12, weight: .semibold)).foregroundColor(.red)
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 22)
        }
    }

    private func causeRow(_ cause: ImpactCause) -> some View {
        Button {
            Task { await direct(type: splitMode ? "split" : "donate", causeId: cause.id) }
        } label: {
            HStack(spacing: 14) {
                causeIcon(cause.color, symbol: cause.symbol)
                VStack(alignment: .leading, spacing: 3) {
                    Text(cause.label.uppercased()).font(.system(size: 13, weight: .bold)).foregroundColor(.montraTextPrimary)
                    Text(cause.description).font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                        .lineLimit(2).multilineTextAlignment(.leading)
                }
                Spacer()
                if isDirecting && directingCauseId == cause.id {
                    ProgressView().tint(gold)
                } else {
                    Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.montraTextSecondary)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .montraCard(radius: 14)
        }
        .buttonStyle(.plain)
        .disabled(isDirecting)
    }

    private func optionRow(icon: String, color: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                causeIcon(color, symbol: icon)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 13, weight: .bold)).foregroundColor(.montraTextPrimary)
                    Text(subtitle).font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13)).foregroundColor(.montraTextSecondary)
            }
            .padding(14)
            .frame(maxWidth: .infinity)
            .montraCard(radius: 14)
        }
        .buttonStyle(.plain)
        .disabled(isDirecting)
    }

    private func causeIcon(_ color: Color, symbol: String) -> some View {
        ZStack {
            Circle().fill(color).frame(width: 44, height: 44)
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
        }
    }

    // MARK: - Screen 3: Impact Confirmed

    private var thanksScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                ZStack {
                    Circle().fill(Color(hex: "#4CAF50")).frame(width: 96, height: 96)
                    Image(systemName: "heart.fill").font(.system(size: 40)).foregroundColor(.white)
                }
                .padding(.top, 54)

                Text("Thank you!").font(.system(size: 28, weight: .bold)).foregroundColor(.montraTextPrimary)

                Text(supportingText)
                    .font(.system(size: 16)).foregroundColor(.montraTextSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)

                destinationCard

                VStack(spacing: 8) {
                    Text("\u{201C}The smallest act of kindness creates the biggest ripple.\u{201D}")
                        .font(.system(size: 13, weight: .medium)).italic()
                        .foregroundColor(.montraTextSecondary).multilineTextAlignment(.center)
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill").font(.system(size: 12)).foregroundColor(Color(hex: "#4CAF50"))
                        Text("Together, we make an impact.").font(.system(size: 13, weight: .semibold)).foregroundColor(Color(hex: "#4CAF50"))
                    }
                }
                .padding(.top, 6)

                Button { showSummary = true } label: {
                    Text("VIEW IMPACT SUMMARY")
                        .font(.system(size: 15, weight: .bold)).kerning(0.5)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(gold)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.top, 6)

                Button("Back to Home") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(gold)

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 22)
        }
    }

    private var destinationCard: some View {
        HStack(alignment: .top, spacing: 14) {
            causeIcon(cause?.color ?? gold, symbol: destinationSymbol)
            VStack(alignment: .leading, spacing: 4) {
                Text(destinationTitle).font(.system(size: 13, weight: .bold)).foregroundColor(.montraTextPrimary)
                Text(destinationDescription).font(.system(size: 12)).foregroundColor(.montraTextSecondary)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .montraCard(radius: 14)
    }

    // MARK: - Derived

    private var allocation: ImpactAllocation? { credit.allocation }
    private var cause: ImpactCause? { ImpactCause.by(id: allocation?.causeId) }

    private var supportingText: String {
        let amount = credit.amountLabel
        switch allocation?.type {
        case "donate": return "Your \(amount) Impact Credit is supporting \(allocation?.causeLabel ?? "your cause")."
        case "split":  return "Your \(amount) Impact Credit is supporting \(allocation?.causeLabel ?? "your cause") and your coaching."
        case "coaching": return "Your \(amount) Impact Credit is supporting your coaching journey."
        case "gift": return "Your \(amount) Impact Credit is on its way to \(allocation?.giftEmail ?? "your friend")."
        default: return "Your \(amount) Impact Credit has been directed."
        }
    }

    private var destinationSymbol: String {
        if let cause { return cause.symbol }
        switch allocation?.type {
        case "coaching": return "figure.strengthtraining.traditional"
        case "gift": return "gift.fill"
        default: return "heart.fill"
        }
    }

    private var destinationTitle: String {
        if let cause { return cause.label.uppercased() }
        switch allocation?.type {
        case "coaching": return "FUTURE COACHING"
        case "gift": return "GIFTED"
        default: return "DIRECTED"
        }
    }

    private var destinationDescription: String {
        if let cause { return cause.description }
        switch allocation?.type {
        case "coaching": return "Your credit is reserved toward your own training journey."
        case "gift": return "Your friend will receive a MONTRA Impact Credit to use."
        default: return "Your credit has been directed."
        }
    }

    private var dateText: String {
        guard let date = session?.startDate else { return "—" }
        let f = DateFormatter(); f.dateFormat = "MMM d, yyyy"; return f.string(from: date)
    }
    private var timeText: String {
        guard let date = session?.startDate else { return "—" }
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: date)
    }

    // MARK: - Action

    private func direct(type: String, causeId: String? = nil, giftEmail: String? = nil) async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }
        isDirecting = true
        directingCauseId = causeId
        defer { isDirecting = false; directingCauseId = nil }
        do {
            let updated = try await ImpactAPI.directCredit(id: credit.id, type: type, causeId: causeId, giftEmail: giftEmail, token: tokenResult.token)
            credit = updated
            actionError = nil
            withAnimation { step = .thanks }
        } catch {
            actionError = error.localizedDescription
        }
    }
}
