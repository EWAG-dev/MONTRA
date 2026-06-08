import SwiftUI

// MARK: - Dashboard

struct DashboardView: View {
    enum ViewerRole {
        case user
        case trainer
    }

    @Binding var selectedTab: ContentView.Tab
    let onOpenCoachChat: () -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var showProfileSheet = false
    @State private var showNotifications = false
    @State private var mapButtonOffset: CGSize = .zero
    @State private var mapButtonDragOffset: CGSize = .zero
    @State private var mapButtonDidDrag = false
    @State private var showFloatingMap = false
    @AppStorage("dashboardProfileImageData") private var profileImageData: Data = Data()
    @AppStorage("progress.selectedGoals") private var selectedGoalsStorage: String = "Build Strength"
    @AppStorage("progress.currentWeight") private var currentWeight: String = ""
    @AppStorage("progress.startWeight") private var startWeight: String = ""
    @AppStorage("progress.goal.weightLoss") private var weightLossGoal: String = ""
    @AppStorage("progress.goal.strengthWeeklySessions") private var strengthWeeklyTarget: String = "5"
    @AppStorage("progress.goal.enduranceMinutes") private var enduranceMinutesTarget: String = "180"
    @AppStorage("progress.goal.mobilitySessions") private var mobilitySessionsTarget: String = "3"
    @AppStorage("progress.goal.performanceMonthlySessions") private var performanceMonthlyTarget: String = "12"
    @AppStorage("progress.goal.consistencyPercent") private var consistencyPercentTarget: String = "90"
    @AppStorage("quiz.firstName") private var firstName: String = ""
    @AppStorage("onboarding.completed") private var onboardingCompleted: Bool = true
    @AppStorage("onboarding.rematchActive") private var rematchActive: Bool = false
    @AppStorage("quiz.requestedTrainer") private var requestedTrainerId: String = ""
    @AppStorage("quiz.requestedTrainerName") private var requestedTrainerName: String = ""
    private let viewerRole: ViewerRole = .user

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
                        NotificationBellButton(action: { showNotifications = true }, size: 38)

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
                                            Group {
                                                if viewerRole == .user {
                                                    Text("Add\nPhoto")
                                                        .font(.system(size: 7, weight: .semibold))
                                                        .foregroundColor(.montraOrange)
                                                        .multilineTextAlignment(.center)
                                                        .lineSpacing(0)
                                                } else {
                                                    Text("J")
                                                        .font(.system(size: 16, weight: .bold))
                                                        .foregroundColor(.montraOrange)
                                                }
                                            }
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
                    Text("\(timeGreeting), \(firstName.isEmpty ? "there" : firstName)! 👋")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                    Text("Ready to crush your goals today?")
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)
                }

                // ── CTA Buttons ───────────────────────────────────────
                HStack(spacing: 10) {
                    Button { selectedTab = .sessions } label: {
                        HStack(spacing: 6) {
                            Text("Book a Session")
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
                        rematchActive = true
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
                NavigationLink {
                    SessionDetailView(
                        session: nextSession,
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
                            Text("MAY")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.montraOrange)
                            Text("24")
                                .font(.system(size: 30, weight: .black))
                                .foregroundColor(.montraTextPrimary)
                            Text("FRI")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.montraTextSecondary)
                        }
                        .frame(width: 58)
                        .padding(.vertical, 10)
                        .background(Color.montraBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Tomorrow")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.montraOrange)
                            Text("10:00 AM")
                                .font(.system(size: 21, weight: .bold))
                                .foregroundColor(.montraTextPrimary)
                            Text("Full Body Strength")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.montraTextPrimary)
                            Text("with Alex Morgan")
                                .font(.system(size: 13))
                                .foregroundColor(.montraTextSecondary)
                            Text("In-home session")
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
                            Text("Confirmed")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.green.opacity(0.15))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .frame(height: 80)
                    }
                }
                .padding(18)
                .montraCard(radius: 16)
                } // NavigationLink label
                .buttonStyle(.plain)

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

                Spacer(minLength: 90)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.montraBackground)
        .overlay {
            GeometryReader { proxy in
                let buttonSize = CGSize(width: 86, height: 40)
                let baseX = proxy.size.width - 22 - (buttonSize.width / 2)
                let baseBottomInset = max(140, proxy.safeAreaInsets.bottom + 110)
                let baseY = proxy.size.height - baseBottomInset - (buttonSize.height / 2)
                let rawX = baseX + mapButtonOffset.width + mapButtonDragOffset.width
                let rawY = baseY + mapButtonOffset.height + mapButtonDragOffset.height

                let minX = buttonSize.width / 2 + 12
                let maxX = proxy.size.width - (buttonSize.width / 2) - 12
                let minY = buttonSize.height / 2 + 72
                let maxY = proxy.size.height - (buttonSize.height / 2) - 96

                Button {
                    if !mapButtonDidDrag {
                        showFloatingMap = true
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Map")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundColor(colorScheme == .light ? .montraPrimaryButtonText : .black)
                    .frame(width: buttonSize.width, height: buttonSize.height)
                    .background(colorScheme == .light ? Color.montraFrostedOrangeFill : Color.montraOrange)
                    .overlay(
                        Capsule()
                            .stroke(
                                colorScheme == .light ? Color.montraFrostedOrangeStroke : Color.clear,
                                lineWidth: colorScheme == .light ? 1 : 0
                            )
                    )
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .position(
                    x: min(max(rawX, minX), maxX),
                    y: min(max(rawY, minY), maxY)
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            mapButtonDragOffset = value.translation
                            let dragDistance = hypot(value.translation.width, value.translation.height)
                            if dragDistance > 8 {
                                mapButtonDidDrag = true
                            }
                        }
                        .onEnded { value in
                            let proposed = CGSize(
                                width: mapButtonOffset.width + value.translation.width,
                                height: mapButtonOffset.height + value.translation.height
                            )

                            let clampedX = min(max(baseX + proposed.width, minX), maxX) - baseX
                            let clampedY = min(max(baseY + proposed.height, minY), maxY) - baseY

                            mapButtonOffset = CGSize(width: clampedX, height: clampedY)
                            mapButtonDragOffset = .zero
                            DispatchQueue.main.async {
                                mapButtonDidDrag = false
                            }
                        }
                )
            }
        }
        .navigationDestination(isPresented: $showFloatingMap) {
            SessionDetailView(
                session: nextSession,
                onOpenCoachChat: onOpenCoachChat
            )
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileMenuSheet(isClient: true)
        }
        } // NavigationStack
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

    private let trainerProgress = TrainerProgressSnapshot.sample

    private let nextSession = SessionItem(
        id: 0, day: "FRI", date: 24, month: "MAY",
        time: "10:00 AM", endTime: "11:00 AM",
        title: "Full Body Strength", trainer: "Alex Morgan",
        location: "At Your Home", address: "123 Main St, Miami, FL",
        focus: "Full Body Strength", durationMin: 60,
        level: "Intermediate", equipment: "Dumbbells, Mat, Bands",
        calories: "500–600"
    )

    private let scheduledSessions: [ScheduleSession] = [
        ScheduleSession(id: 1, month: "MAY", date: 27, day: "MON", title: "HIIT & Core",        trainer: "Alex Morgan", time: "9:00 AM",  status: .confirmed),
        ScheduleSession(id: 2, month: "MAY", date: 31, day: "FRI", title: "Lower Body Power",   trainer: "Alex Morgan", time: "11:00 AM", status: .scheduled),
        ScheduleSession(id: 3, month: "JUN", date:  3, day: "MON", title: "Upper Body Strength", trainer: "Alex Morgan", time: "9:00 AM",  status: .scheduled),
        ScheduleSession(id: 4, month: "JUN", date:  7, day: "FRI", title: "Full Body Strength",  trainer: "Alex Morgan", time: "10:00 AM", status: .scheduled),
    ]
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
