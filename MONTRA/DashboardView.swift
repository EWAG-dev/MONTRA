import SwiftUI

// MARK: - Dashboard

struct DashboardView: View {
    @Binding var selectedTab: ContentView.Tab
    let onOpenCoachChat: () -> Void
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var showProfileSheet = false
    @State private var showNotifications = false
    @State private var showCoachTracking = false
    @State private var showIntroBooking = false
    @AppStorage("dashboardProfileImageData") private var profileImageData: Data = Data()
    @State private var selectedGoalsStorage: String = "Build Strength"
    @State private var currentWeight: String = ""
    @State private var startWeight: String = ""
    @State private var weightLossGoal: String = ""
    @State private var strengthWeeklyTarget: String = "5"
    @State private var enduranceMinutesTarget: String = "180"
    @State private var mobilitySessionsTarget: String = "3"
    @State private var performanceMonthlyTarget: String = "12"
    @State private var consistencyPercentTarget: String = "90"
    @AppStorage("quiz.firstName") private var firstName: String = ""
    @AppStorage("onboarding.completed") private var onboardingCompleted: Bool = true
    @AppStorage("quiz.requestedTrainer") private var requestedTrainerId: String = ""
    @AppStorage("quiz.requestedTrainerName") private var requestedTrainerName: String = ""
    @AppStorage("notif.unreadCount") private var unreadCount = 0

    private var timeGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        default:       return "Good evening"
        }
    }

    private var montraLogoAsset: String {
        colorScheme == .dark ? "MontraLogoDark" : "MontraLogoLight"
    }

    var body: some View {
        NavigationStack {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {

                // ── Top nav ──────────────────────────────────────────
                HStack(alignment: .center) {
                    Image(montraLogoAsset)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 94, height: 40)
                        .opacity(0.88)

                    Spacer()

                    HStack(spacing: 14) {
                        // Notifications (next to profile photo)
                        NotificationBellButton(
                            action: { showNotifications = true },
                            showsBadge: unreadCount > 0,
                            badgeCount: unreadCount,
                            size: 38
                        )

                        Button { showProfileSheet = true } label: {
                            ZStack {
                                if let uiImage = UIImage(data: profileImageData), !profileImageData.isEmpty {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 40, height: 40)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.montraSurface)
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Text("Add\nPhoto")
                                                .font(.system(size: 7, weight: .semibold))
                                                .foregroundColor(.montraOrange)
                                                .multilineTextAlignment(.center)
                                                .lineSpacing(0)
                                        )
                                }
                            }
                            .overlay(Circle().stroke(Color.montraOrange, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 4)

                // ── Greeting ─────────────────────────────────────────
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(timeGreeting), \(firstName.isEmpty ? "there" : firstName)!")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                    Text("Ready to crush your goals today?")
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)
                }

                // ── CTA Buttons ───────────────────────────────────────
                HStack(spacing: 10) {
                    Button { showIntroBooking = true } label: {
                        HStack(spacing: 6) {
                            Text("Book Intro Session")
                                .font(.system(size: 14, weight: .semibold))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(colorScheme == .light ? .montraOrange : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(colorScheme == .light ? Color.montraFrostedOrangeFill : Color.montraOrange)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(
                                    colorScheme == .light ? Color.montraFrostedOrangeStroke : Color.clear,
                                    lineWidth: colorScheme == .light ? 1 : 0
                                )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        requestedTrainerId = ""
                        requestedTrainerName = ""
                        UserDefaults.standard.set(1, forKey: "quiz.step")
                        onboardingCompleted = false
                    } label: {
                        Text("Rematch")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.montraOrange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.montraOrange, lineWidth: 1.5)
                            )
                    }
                }

                // ── Coach on the Way pill (Uber-style) ───────────────
                if let eta = coachETA, let next = nextSession {
                    CoachOnTheWayPill(
                        trainerName: next.trainer,
                        etaMinutes: eta
                    ) {
                        showCoachTracking = true
                    }
                }

                // ── This Week's Progress ──────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("THIS WEEK'S PROGRESS")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.montraTextSecondary)
                            .kerning(1.2)
                        Spacer()
                        NavigationLink {
                            ProgressProfileView(progress: trainerProgress)
                        } label: {
                            Text("View All")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.montraOrange)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 0) {
                        WeeklyStatCell(icon: "dumbbell.fill",  value: "\(trainerProgress.completedSessionsThisWeek)", label: "Sessions\nCompleted")
                        statDivider
                        WeeklyStatCell(icon: "clock.fill", value: trainerProgress.membershipHoursDisplay, label: "Hours\nCompleted")
                        statDivider
                        WeeklyStatCell(icon: goalMetric.icon, value: goalMetric.value, label: goalMetric.label)
                        statDivider
                        GoalRingCell(progress: goalMetric.ringProgress)
                    }
                }
                .padding(18)
                .montraCard(radius: 16)

                // ── Next Session ──────────────────────────────────────
                if let next = nextSession {
                    NavigationLink {
                        SessionDetailView(
                            session: next,
                            onOpenCoachChat: onOpenCoachChat
                        )
                    } label: {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("NEXT SESSION")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.montraTextSecondary)
                            .kerning(1.2)

                        HStack(spacing: 14) {
                            // Date badge
                            VStack(spacing: 2) {
                                Text(next.month)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.montraOrange)
                                Text("\(next.date)")
                                    .font(.system(size: 30, weight: .black))
                                    .foregroundColor(.montraTextPrimary)
                                Text(next.day)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.montraTextSecondary)
                            }
                            .frame(width: 58)
                            .padding(.vertical, 10)
                            .background(Color.montraBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(nextSessionRelativeDayLabel)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.montraOrange)
                                Text(next.time)
                                    .font(.system(size: 21, weight: .bold))
                                    .foregroundColor(.montraTextPrimary)
                                Text(next.title)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.montraTextPrimary)
                                Text("with \(next.trainer)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.montraTextSecondary)
                                Text(next.location)
                                    .font(.system(size: 12))
                                    .foregroundColor(.montraTextSecondary)
                                    .padding(.top, 2)
                            }

                            Spacer()

                            VStack(spacing: 8) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.montraTextSecondary)
                                Spacer()
                                Text("Scheduled")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(hex: "#5E9BF0"))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color(hex: "#5E9BF0").opacity(0.15))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .frame(height: 80)
                        }
                    }
                    .padding(18)
                    .montraCard(radius: 16)
                    } // NavigationLink label
                    .buttonStyle(.plain)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("NEXT SESSION")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.montraTextSecondary)
                            .kerning(1.2)
                        Text("No upcoming sessions")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.montraTextPrimary)
                        Text("Book a session to see it here.")
                            .font(.system(size: 13))
                            .foregroundColor(.montraTextSecondary)
                        Button { showIntroBooking = true } label: {
                            Text("Book Intro Session")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.montraOrange)
                        }
                        .padding(.top, 2)
                    }
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .montraCard(radius: 16)
                }

                // ── Schedule ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    Text("SCHEDULE")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.montraTextSecondary)
                        .kerning(1.2)

                    VStack(spacing: 0) {
                        ForEach(scheduledSessions) { session in
                            NavigationLink {
                                SessionDetailView(
                                    session: SessionItem(
                                        id: session.id,
                                        day: session.day,
                                        date: session.date,
                                        month: session.month,
                                        time: session.time,
                                        endTime: "",
                                        title: session.title,
                                        trainer: session.trainer,
                                        location: "In-home session"
                                    ),
                                    onOpenCoachChat: onOpenCoachChat
                                )
                            } label: {
                                ScheduleRow(session: session)
                            }
                            .buttonStyle(.plain)
                            if session.id != scheduledSessions.last?.id {
                                Divider()
                                    .background(Color.montraDivider)
                                    .padding(.horizontal, 4)
                            }
                        }
                    }
                }
                .padding(18)
                .montraCard(radius: 16)

                impactCard

                Spacer(minLength: 90)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.montraBackground)
        .task {
            await loadUnreadNotificationCount()
        }
        .sheet(isPresented: $showIntroBooking) {
            IntroBookingView(preselectedTrainer: nil)
        }
        .sheet(isPresented: $showCoachTracking) {
            if let next = nextSession, let eta = coachETA {
                CoachOnTheWayView(session: next, initialETA: eta)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileMenuSheet(isClient: true)
        }
        .sheet(isPresented: $showImpactSummary) {
            ImpactSummaryView()
        }
        .fullScreenCover(item: $directingCredit, onDismiss: { Task { await loadImpactCredits() } }) { credit in
            ImpactFlowView(session: nil, credit: credit, startAtDirect: true)
                .environmentObject(auth)
        }
        .task {
            await loadBookedSessions()
            await loadProgress()
            await loadImpactCredits()
        }
        } // NavigationStack
    }

    private func loadUnreadNotificationCount() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let notifications = try? await NotificationsAPI.loadMine(token: tokenResult.token) else { return }
        unreadCount = notifications.filter(\.unread).count
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.montraDivider)
            .frame(width: 1, height: 50)
    }

    private var selectedGoalTypes: [UserGoalType] {
        selectedGoalsStorage
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { UserGoalType(rawValue: $0) }
    }

    private var goalMetric: GoalMetricDisplay {
        trainerProgress.dashboardGoalMetric(
            primaryGoal: selectedGoalTypes.first,
            goalCount: selectedGoalTypes.count,
            currentWeight: Double(currentWeight),
            startWeight: Double(startWeight),
            goalWeight: Double(weightLossGoal),
            strengthTargetSessions: Int(strengthWeeklyTarget) ?? 5,
            mobilityTargetSessions: Int(mobilitySessionsTarget) ?? 3,
            performanceTargetMonthly: Int(performanceMonthlyTarget) ?? 12,
            consistencyTargetPercent: Int(consistencyPercentTarget) ?? 90
        )
    }

    private let trainerProgress = TrainerProgressSnapshot.empty

    @State private var bookedSessions: [BookedSession] = []

    private func loadBookedSessions() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let sessions = try? await BookingAPI.loadMySessions(token: tokenResult.token) else { return }
        bookedSessions = sessions
    }

    // MARK: - Impact Credits

    @State private var impactCredits: [ImpactCredit] = []
    @State private var directingCredit: ImpactCredit?
    @State private var showImpactSummary = false

    private var pendingCredits: [ImpactCredit] { impactCredits.filter { !$0.isDirected } }
    private var pendingImpactTotal: Int { pendingCredits.reduce(0) { $0 + $1.amount } }

    private func loadImpactCredits() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let credits = try? await ImpactAPI.loadMyCredits(token: tokenResult.token) else { return }
        impactCredits = credits
    }

    private var impactCard: some View {
        let gold = Color(hex: "#C9A063")
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.circle.fill").font(.system(size: 18)).foregroundColor(gold)
                Text("YOUR IMPACT")
                    .font(.system(size: 12, weight: .bold)).kerning(0.8).foregroundColor(.montraTextPrimary)
                Spacer()
                Button("Community") { showImpactSummary = true }
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(gold)
            }

            if let credit = pendingCredits.first {
                Text(pendingCredits.count > 1
                     ? "You have $\(pendingImpactTotal) in Impact Credits to direct"
                     : "You have a \(credit.amountLabel) Impact Credit to direct")
                    .font(.system(size: 15, weight: .bold)).foregroundColor(.montraTextPrimary)
                Text("Direct it to a cause you care about — donate, gift it, or apply it to your coaching.")
                    .font(.system(size: 12)).foregroundColor(.montraTextSecondary)
                Button { directingCredit = credit } label: {
                    Text("DIRECT MY IMPACT")
                        .font(.system(size: 14, weight: .bold)).foregroundColor(.black)
                        .frame(maxWidth: .infinity).padding(.vertical, 13)
                        .background(gold).clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 2)
            } else {
                Text("Every session you book unlocks an Impact Credit you can direct to a cause that matters to you.")
                    .font(.system(size: 12)).foregroundColor(.montraTextSecondary)
                Button { showImpactSummary = true } label: {
                    Text("View Community Impact")
                        .font(.system(size: 13, weight: .semibold)).foregroundColor(gold)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .montraCard(radius: 16)
    }

    private func loadProgress() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let remote = try? await ProgressAPI.load(token: tokenResult.token) else { return }

        currentWeight = remote.currentWeight
        startWeight = remote.startWeight
        weightLossGoal = remote.weightLossGoal
        strengthWeeklyTarget = remote.strengthWeeklyTarget
        enduranceMinutesTarget = remote.enduranceMinutesTarget
        mobilitySessionsTarget = remote.mobilitySessionsTarget
        performanceMonthlyTarget = remote.performanceMonthlyTarget
        consistencyPercentTarget = remote.consistencyPercentTarget
        selectedGoalsStorage = remote.selectedGoals.isEmpty ? "Build Strength" : remote.selectedGoals.joined(separator: ",")
    }

    /// Returns the ETA in minutes when the coach is realistically en route (0–90 min window).
    /// Nil when the session is too far away or already started.
    private var coachETA: Int? {
        guard let date = nextBookedDate else { return nil }
        let mins = Int(date.timeIntervalSinceNow / 60)
        guard mins > 0 && mins <= 90 else { return nil }
        return mins
    }

    private var nextBookedDate: Date? {
        let now = Date()
        return bookedSessions
            .filter { $0.status == "scheduled" }
            .compactMap { $0.startDate }
            .filter { $0 >= now }
            .sorted()
            .first
    }

    private var nextSession: SessionItem? {
        let now = Date()
        guard let booked = bookedSessions
            .filter({ $0.status == "scheduled" })
            .filter({ $0.startDate.map { $0 >= now } ?? false })
            .sorted(by: { ($0.startDate ?? .distantFuture) < ($1.startDate ?? .distantFuture) })
            .first,
              let date = booked.startDate else { return nil }

        let cal = Calendar.current
        let dayFormatter = DateFormatter(); dayFormatter.dateFormat = "EEE"
        let monthFormatter = DateFormatter(); monthFormatter.dateFormat = "MMM"
        let timeFormatter = DateFormatter(); timeFormatter.dateFormat = "h:mm a"
        let durationMins = booked.durationMin > 0 ? booked.durationMin : 60
        let endDate = cal.date(byAdding: .minute, value: durationMins, to: date) ?? date
        let trainerName = booked.trainerName.isEmpty ? "Your Trainer" : booked.trainerName

        return SessionItem(
            id: 0,
            day: dayFormatter.string(from: date).uppercased(),
            date: cal.component(.day, from: date),
            month: monthFormatter.string(from: date).uppercased(),
            time: timeFormatter.string(from: date),
            endTime: timeFormatter.string(from: endDate),
            title: "Training Session",
            trainer: trainerName,
            trainerId: booked.trainerId.isEmpty ? nil : booked.trainerId,
            location: "In-home session"
        )
    }

    private var nextSessionRelativeDayLabel: String {
        guard let date = nextBookedDate else { return "" }
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInTomorrow(date) { return "Tomorrow" }
        let f = DateFormatter(); f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    private let scheduledSessions: [ScheduleSession] = []
}

// MARK: - Weekly Stat Cell

struct WeeklyStatCell: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.montraOrange)
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.montraTextPrimary)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.montraTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Goal Ring Cell

struct GoalRingCell: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 5) {
            ZStack {
                Circle()
                    .stroke(Color.montraBackground, lineWidth: 5)
                    .frame(width: 40, height: 40)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.montraOrange, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.montraTextPrimary)
            }
            Text("Goal\nProgress")
                .font(.system(size: 10))
                .foregroundColor(.montraTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Schedule Row

enum SessionStatus { case confirmed, scheduled }

struct ScheduleSession: Identifiable {
    let id: Int
    let month: String
    let date: Int
    let day: String
    let title: String
    let trainer: String
    let time: String
    let status: SessionStatus
}

struct ScheduleRow: View {
    let session: ScheduleSession

    var body: some View {
        HStack(spacing: 14) {
            // Date badge
            VStack(spacing: 1) {
                Text(session.month)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.montraOrange)
                Text("\(session.date)")
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.montraTextPrimary)
                Text(session.day)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.montraTextSecondary)
            }
            .frame(width: 44)
            .padding(.vertical, 8)
            .background(Color.montraBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(session.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                Text("with \(session.trainer)")
                    .font(.system(size: 12))
                    .foregroundColor(.montraTextSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(session.time)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.montraTextSecondary)
                StatusBadge(status: session.status)
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.montraTextSecondary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
    }
}

struct StatusBadge: View {
    let status: SessionStatus

    var label: String  { status == .confirmed ? "Confirmed" : "Scheduled" }
    var color: Color   { status == .confirmed ? .green : Color(hex: "#5E9BF0") }

    var body: some View {
        Text(label)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    DashboardView(selectedTab: .constant(.dashboard), onOpenCoachChat: {})
}
