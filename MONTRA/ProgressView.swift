import SwiftUI
import Charts

// MARK: - Data Models

struct ProgressDataPoint: Identifiable {
    let id = UUID()
    let day: Int
    let dayLabel: String
    let value: Double
}

struct Achievement: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let badgeColor: Color
    let title: String
    let subtitle: String?
    let date: String
}

// MARK: - Main View

struct WorkoutProgressView: View {
    @State private var selectedTab = 0
    @State private var selectedPeriodKey: String = ""
    @State private var showAllAchievements = false
    private let tabs = ["Overview", "Workouts", "Nutrition", "Body Stats"]

    private let trainerProgress = TrainerProgressSnapshot.sample

    // Shared AppStorage keys — same as DashboardView
    @AppStorage("progress.currentWeight") private var currentWeightStr: String = ""
    @AppStorage("progress.startWeight") private var startWeightStr: String = ""
    @AppStorage("progress.goal.strengthWeeklySessions") private var strengthTargetStr: String = "5"

    // MARK: Computed stats

    private var weightLostDisplay: String {
        guard let current = Double(currentWeightStr),
              let start = Double(startWeightStr.isEmpty ? currentWeightStr : startWeightStr)
        else { return "--" }
        let delta = start - current
        if delta == 0 { return "0 lbs" }
        return delta > 0
            ? String(format: "-%.1f lbs", delta)
            : String(format: "+%.1f lbs", abs(delta))
    }

    private var weeklySessionPctDisplay: String {
        let target = max(Int(strengthTargetStr) ?? 5, 1)
        let pct = Int((Double(trainerProgress.completedSessionsThisWeek) / Double(target) * 100).rounded())
        return pct > 0 ? "+\(pct)%" : "0%"
    }

    private var caloriesDisplay: String {
        let cal = trainerProgress.weeklyCalories
        if cal >= 1000 {
            return String(format: "+%.1fk", Double(cal) / 1000.0)
        }
        return cal > 0 ? "+\(cal)" : "0"
    }

    private var monthlySessionsDisplay: String { "\(completedSessionsInSelectedPeriod.count)" }

    private var currentPeriodKey: String {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    private var selectedPeriodDate: Date {
        let key = selectedPeriodKey.isEmpty ? currentPeriodKey : selectedPeriodKey
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1])
        else { return Date() }
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    private var selectedPeriodLabel: String {
        let key = selectedPeriodKey.isEmpty ? currentPeriodKey : selectedPeriodKey
        if key == currentPeriodKey { return "This Month" }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedPeriodDate)
    }

    private var periodOptions: [(key: String, label: String)] {
        let calendar = Calendar.current
        let keys = Set(
            trainerProgress.sessions
                .filter { $0.completed }
                .map {
                    let c = calendar.dateComponents([.year, .month], from: $0.date)
                    return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
                }
        )

        let withCurrent = keys.union([currentPeriodKey])
        let sorted = withCurrent.sorted(by: >)
        return sorted.map { key in
            if key == currentPeriodKey {
                return (key, "This Month")
            }
            let p = key.split(separator: "-")
            if p.count == 2, let year = Int(p[0]), let month = Int(p[1]),
               let d = calendar.date(from: DateComponents(year: year, month: month, day: 1)) {
                let f = DateFormatter()
                f.dateFormat = "MMMM yyyy"
                return (key, f.string(from: d))
            }
            return (key, key)
        }
    }

    private var completedSessionsInSelectedPeriod: [TrainerSessionRecord] {
        let calendar = Calendar.current
        let key = selectedPeriodKey.isEmpty ? currentPeriodKey : selectedPeriodKey
        return trainerProgress.sessions.filter { session in
            guard session.completed else { return false }
            let c = calendar.dateComponents([.year, .month], from: session.date)
            let sKey = String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
            return sKey == key
        }
    }

    // Cumulative completed-sessions curve for the current month
    private var chartData: [ProgressDataPoint] {
        let calendar = Calendar.current
        let selected = selectedPeriodDate
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selected)) else {
            return []
        }
        let isCurrentMonth = calendar.isDate(selected, equalTo: Date(), toGranularity: .month)
        let todayDay = calendar.component(.day, from: Date())
        let dayUpperBound: Int = {
            if isCurrentMonth { return todayDay }
            return calendar.range(of: .day, in: .month, for: selected)?.count ?? 30
        }()

        // Map each completed session this month to its day-of-month
        let sessionDays: [Int] = completedSessionsInSelectedPeriod
            .compactMap {
                guard let day = calendar.dateComponents([.day], from: monthStart, to: calendar.startOfDay(for: $0.date)).day else { return nil }
                return day + 1
            }
            .sorted()

        // Build cumulative count per day that had a session (plus day 1 anchor at 0)
        var result: [ProgressDataPoint] = [.init(day: 1, dayLabel: dayLabel(for: 1, in: selected), value: 0)]
        var cumulative = 0
        for day in sessionDays {
            cumulative += 1
            // Replace last point if same day, otherwise append
            if result.last?.day == day {
                result[result.count - 1] = .init(day: day, dayLabel: dayLabel(for: day, in: selected), value: Double(cumulative))
            } else {
                result.append(.init(day: day, dayLabel: dayLabel(for: day, in: selected), value: Double(cumulative)))
            }
        }
        // Extend line to the end of selected visible range if no session on that day
        if result.last?.day ?? 0 < dayUpperBound {
            result.append(.init(day: dayUpperBound, dayLabel: dayLabel(for: dayUpperBound, in: selected), value: Double(cumulative)))
        }
        return result
    }

    private var chartYMax: Double {
        max(Double(completedSessionsInSelectedPeriod.count + 1), 5)
    }

    private let achievements: [Achievement] = [
        Achievement(
            icon: "flame.fill",
            iconColor: Color(hex: "#E8621A"),
            badgeColor: Color(hex: "#5C2200"),
            title: "Consistency King",
            subtitle: nil,
            date: "M90 /, 2024"
        ),
        Achievement(
            icon: "trophy.fill",
            iconColor: Color(hex: "#4A90D9"),
            badgeColor: Color(hex: "#102040"),
            title: "Early Riser",
            subtitle: "3 early morning sessions",
            date: "May 5, 2024"
        ),
        Achievement(
            icon: "dumbbell.fill",
            iconColor: Color(hex: "#4CAF50"),
            badgeColor: Color(hex: "#0E3B0E"),
            title: "First Milestone",
            subtitle: "Completed 10 sessions",
            date: "May 10, 2024"
        ),
        Achievement(
            icon: "figure.run",
            iconColor: Color(hex: "#22C55E"),
            badgeColor: Color(hex: "#10321B"),
            title: "Cardio Sprint",
            subtitle: "5 cardio sessions in one week",
            date: "Apr 24, 2024"
        ),
        Achievement(
            icon: "heart.fill",
            iconColor: Color(hex: "#EF4444"),
            badgeColor: Color(hex: "#3A0F16"),
            title: "Heart Health Win",
            subtitle: "Resting HR improved by 6 bpm",
            date: "Apr 14, 2024"
        ),
        Achievement(
            icon: "bolt.fill",
            iconColor: Color(hex: "#FACC15"),
            badgeColor: Color(hex: "#3B3208"),
            title: "Power Output PR",
            subtitle: "New personal best in strength circuit",
            date: "Mar 31, 2024"
        )
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Header
                HStack(alignment: .center) {
                    Text("Progress")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                    Spacer()
                    Menu {
                        ForEach(periodOptions, id: \.key) { option in
                            Button {
                                selectedPeriodKey = option.key
                            } label: {
                                if option.key == selectedPeriodKey || (selectedPeriodKey.isEmpty && option.key == currentPeriodKey) {
                                    Label(option.label, systemImage: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(selectedPeriodLabel)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.montraTextPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.montraTextPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 16)

                // MARK: Sub-tab Bar
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button(action: { selectedTab = index }) {
                            VStack(spacing: 8) {
                                Text(tab)
                                    .font(.system(size: 13, weight: selectedTab == index ? .semibold : .regular))
                                    .foregroundColor(selectedTab == index ? .montraOrange : .montraTextSecondary)
                                Rectangle()
                                    .fill(selectedTab == index ? Color.montraOrange : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 20)

                // MARK: Tab Content
                if selectedTab == 0 {
                    overviewContent
                } else {
                    comingSoonContent
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.montraBackground)
        .sheet(isPresented: $showAllAchievements) {
            AllAchievementsSheet(achievements: achievements)
        }
        .onAppear {
            if selectedPeriodKey.isEmpty {
                selectedPeriodKey = currentPeriodKey
            }
        }
    }

    // MARK: - Overview Content

    @ViewBuilder
    private var overviewContent: some View {

        // Progress Overview Card with Chart
        VStack(alignment: .leading, spacing: 14) {
            Text("PROGRESS OVERVIEW")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.montraTextPrimary)
                .kerning(0.8)

            ProgressLineChart(data: chartData, yMax: chartYMax)
                .frame(height: 170)
        }
        .padding(18)
        .montraCard(radius: 16)
        .padding(.bottom, 16)

        // 4 Stat Tiles
        HStack(spacing: 10) {
            ProgressStatTile(
                icon: "scalemass.fill",
                iconColor: .montraOrange,
                value: weightLostDisplay,
                label: "Weight\nLost"
            )
            ProgressStatTile(
                icon: "chart.bar.fill",
                iconColor: Color(hex: "#4CAF50"),
                value: weeklySessionPctDisplay,
                label: "Session\nGoal"
            )
            ProgressStatTile(
                icon: "flame.fill",
                iconColor: Color(hex: "#FFD700"),
                value: caloriesDisplay,
                label: "Weekly\nCalories"
            )
            ProgressStatTile(
                icon: "person.fill",
                iconColor: .montraTextPrimary,
                value: monthlySessionsDisplay,
                label: "Sessions"
            )
        }
        .padding(.bottom, 20)

        // Recent Achievements
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("RECENT ACHIEVEMENTS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                    .kerning(0.8)
                Spacer()
                Button("View All") { showAllAchievements = true }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.montraOrange)
            }
            .padding(.bottom, 16)

            let recentAchievements = Array(achievements.prefix(3))
            ForEach(Array(recentAchievements.enumerated()), id: \.element.id) { index, achievement in
                AchievementRow(achievement: achievement)
                if index < recentAchievements.count - 1 {
                    Divider()
                        .background(Color.montraDivider)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(18)
        .montraCard(radius: 16)
    }

    private func dayLabel(for day: Int, in monthDate: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: monthDate)
        let monthName = DateFormatter().shortMonthSymbols[month - 1]
        return "\(monthName) \(day)"
    }

    private var comingSoonContent: some View {
        VStack {
            Spacer(minLength: 60)
            Text("Coming Soon")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.montraTextSecondary)
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Progress Line Chart

struct ProgressLineChart: View {
    let data: [ProgressDataPoint]
    let yMax: Double

    private var xMax: Int { max(data.map(\.day).max() ?? 2, 2) }
    private var xMarks: [Int] {
        let step = max((xMax - 1) / 4, 1)
        return Array(stride(from: 1, through: xMax, by: step))
    }

    var body: some View {
        Chart {
            ForEach(data) { point in
                AreaMark(
                    x: .value("Day", point.day),
                    y: .value("Sessions", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#E8621A").opacity(0.35),
                            Color(hex: "#E8621A").opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Sessions", point.value)
                )
                .foregroundStyle(Color(hex: "#E8621A"))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day", point.day),
                    y: .value("Sessions", point.value)
                )
                .foregroundStyle(Color(hex: "#E8621A"))
                .symbolSize(30)
            }
        }
        .chartXAxis {
            AxisMarks(values: xMarks) { value in
                AxisValueLabel {
                    if let day = value.as(Int.self) {
                        let label = data.first(where: { $0.day == day })?.dayLabel ?? ""
                        Text(label)
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#8E8E93"))
                    }
                }
                AxisGridLine()
                    .foregroundStyle(Color.clear)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#8E8E93"))
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.07))
            }
        }
        .chartYScale(domain: 0...yMax)
        .chartXScale(domain: 1...xMax)
    }
}

// MARK: - Stat Tile

struct ProgressStatTile: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.montraTextPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#8E8E93"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .montraCard(radius: 14)
    }
}

// MARK: - Achievement Row

struct AchievementRow: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(achievement.badgeColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: achievement.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(achievement.iconColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                if let subtitle = achievement.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#8E8E93"))
                }
            }

            Spacer()

            Text(achievement.date)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#8E8E93"))
        }
    }
}

struct AllAchievementsSheet: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(achievements.enumerated()), id: \.element.id) { index, achievement in
                        AchievementRow(achievement: achievement)
                        if index < achievements.count - 1 {
                            Divider()
                                .background(Color.montraDivider)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(18)
                .montraCard(radius: 16)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .background(Color.montraBackground)
            .navigationTitle("All Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.montraOrange)
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    WorkoutProgressView()
}
