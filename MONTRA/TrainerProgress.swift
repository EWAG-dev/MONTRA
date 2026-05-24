import SwiftUI

enum UserGoalType: String, CaseIterable {
    case buildStrength = "Build Strength"
    case improveEndurance = "Improve Endurance"
    case weightLoss = "Weight Loss"
    case mobility = "Mobility"
    case athleticPerformance = "Athletic Performance"
    case consistency = "Consistency"
}

struct GoalMetricDisplay {
    let icon: String
    let value: String
    let label: String
    let ringProgress: Double
}

struct TrainerSessionRecord: Identifiable {
    let id: Int
    let date: Date
    let durationMin: Int
    let calories: Int
    let completed: Bool
}

struct TrainerProgressSnapshot {
    let membershipStart: Date
    let weeklyGoalSessions: Int
    let sessions: [TrainerSessionRecord]

    private var completedSessions: [TrainerSessionRecord] {
        sessions.filter { $0.completed }
    }

    var completedSessionsThisWeek: Int {
        completedSessions.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }.count
    }

    var weeklyCalories: Int {
        completedSessions
            .filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.calories }
    }

    var weeklyCompletedMinutes: Int {
        completedSessions
            .filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .weekOfYear) }
            .reduce(0) { $0 + $1.durationMin }
    }

    var monthlyCompletedSessions: Int {
        completedSessions
            .filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
            .count
    }

    var attendancePercent: Int {
        guard !sessions.isEmpty else { return 0 }
        let completed = sessions.filter(\.completed).count
        return Int((Double(completed) / Double(sessions.count) * 100).rounded())
    }

    var totalMembershipMinutes: Int {
        completedSessions.reduce(0) { $0 + $1.durationMin }
    }

    var totalMembershipHours: Double {
        Double(totalMembershipMinutes) / 60.0
    }

    var membershipHoursDisplay: String {
        String(format: "%.1fh", totalMembershipHours)
    }

    var weeklyCaloriesDisplay: String {
        weeklyCalories.formatted(.number.grouping(.automatic))
    }

    var weeklyGoalProgress: Double {
        min(Double(completedSessionsThisWeek) / Double(max(weeklyGoalSessions, 1)), 1.0)
    }

    func dashboardGoalMetric(
        primaryGoal: UserGoalType?,
        goalCount: Int,
        currentWeight: Double?,
        startWeight: Double?,
        goalWeight: Double?,
        strengthTargetSessions: Int,
        mobilityTargetSessions: Int,
        performanceTargetMonthly: Int,
        consistencyTargetPercent: Int
    ) -> GoalMetricDisplay {
        if goalCount > 1 {
            return GoalMetricDisplay(
                icon: "line.3.horizontal.decrease.circle.fill",
                value: "\(goalCount)",
                label: "Active\nGoals",
                ringProgress: weeklyGoalProgress
            )
        }

        switch primaryGoal {
        case .weightLoss:
            let inferredStartWeight = startWeight ?? currentWeight
            let remainingText: String
            if let currentWeight, let goalWeight {
                remainingText = "\(max(Int((currentWeight - goalWeight).rounded()), 0)) lb"
            } else {
                remainingText = "--"
            }

            let progress: Double
            if let inferredStartWeight, let currentWeight, let goalWeight, inferredStartWeight > goalWeight {
                let achieved = inferredStartWeight - currentWeight
                let total = inferredStartWeight - goalWeight
                progress = min(max(achieved / max(total, 0.001), 0.0), 1.0)
            } else if let currentWeight, let goalWeight {
                progress = currentWeight <= goalWeight ? 1.0 : 0.0
            } else {
                progress = 0.0
            }

            return GoalMetricDisplay(
                icon: "flag.checkered",
                value: remainingText,
                label: "Lbs\nLeft",
                ringProgress: progress
            )

        case .improveEndurance:
            return GoalMetricDisplay(
                icon: "flame.fill",
                value: weeklyCaloriesDisplay,
                label: "Weekly\nCalories",
                ringProgress: weeklyGoalProgress
            )

        case .mobility:
            return GoalMetricDisplay(
                icon: "figure.walk",
                value: "\(completedSessionsThisWeek)/\(mobilityTargetSessions)",
                label: "Mobility\nTarget",
                ringProgress: min(Double(completedSessionsThisWeek) / Double(max(mobilityTargetSessions, 1)), 1.0)
            )

        case .athleticPerformance:
            return GoalMetricDisplay(
                icon: "bolt.fill",
                value: "\(monthlyCompletedSessions)/\(performanceTargetMonthly)",
                label: "Monthly\nSessions",
                ringProgress: min(Double(monthlyCompletedSessions) / Double(max(performanceTargetMonthly, 1)), 1.0)
            )

        case .consistency:
            return GoalMetricDisplay(
                icon: "checkmark.seal.fill",
                value: "\(attendancePercent)%",
                label: "Attendance",
                ringProgress: min(Double(attendancePercent) / Double(max(consistencyTargetPercent, 1)), 1.0)
            )

        case .buildStrength, .none:
            return GoalMetricDisplay(
                icon: "target",
                value: "\(completedSessionsThisWeek)/\(strengthTargetSessions)",
                label: "Session\nTarget",
                ringProgress: min(Double(completedSessionsThisWeek) / Double(max(strengthTargetSessions, 1)), 1.0)
            )
        }
    }

    static var sample: TrainerProgressSnapshot {
        let calendar = Calendar.current
        let today = Date()

        func daysFromToday(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        func monthsFromToday(_ offset: Int) -> Date {
            calendar.date(byAdding: .month, value: offset, to: today) ?? today
        }

        return TrainerProgressSnapshot(
            membershipStart: monthsFromToday(-4),
            weeklyGoalSessions: 5,
            sessions: [
                TrainerSessionRecord(id: 1, date: daysFromToday(-2), durationMin: 60, calories: 580, completed: true),
                TrainerSessionRecord(id: 2, date: daysFromToday(-1), durationMin: 55, calories: 520, completed: true),
                TrainerSessionRecord(id: 3, date: today,             durationMin: 65, calories: 610, completed: true),
                TrainerSessionRecord(id: 4, date: daysFromToday(-7), durationMin: 45, calories: 430, completed: true),
                TrainerSessionRecord(id: 5, date: daysFromToday(-12), durationMin: 60, calories: 570, completed: true),
                TrainerSessionRecord(id: 6, date: daysFromToday(-18), durationMin: 50, calories: 480, completed: true),
                TrainerSessionRecord(id: 7, date: daysFromToday(-24), durationMin: 60, calories: 560, completed: true),
                TrainerSessionRecord(id: 8, date: daysFromToday(-30), durationMin: 45, calories: 410, completed: true),
                TrainerSessionRecord(id: 9, date: daysFromToday(-36), durationMin: 60, calories: 595, completed: true),
                TrainerSessionRecord(id: 10, date: daysFromToday(2), durationMin: 60, calories: 590, completed: false),
            ]
        )
    }
}
