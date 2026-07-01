import XCTest
@testable import MONTRA

final class TrainerProgressTests: XCTestCase {
    func testWeeklyAndMembershipMetrics() {
        let now = Date()
        let sessions = [
            TrainerSessionRecord(id: 1, date: now, durationMin: 60, calories: 500, completed: true),
            TrainerSessionRecord(id: 2, date: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now, durationMin: 30, calories: 250, completed: true),
            TrainerSessionRecord(id: 3, date: Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now, durationMin: 45, calories: 300, completed: true),
            TrainerSessionRecord(id: 4, date: now, durationMin: 50, calories: 400, completed: false)
        ]

        let snapshot = TrainerProgressSnapshot(
            membershipStart: Calendar.current.date(byAdding: .month, value: -1, to: now) ?? now,
            weeklyGoalSessions: 5,
            sessions: sessions
        )

        XCTAssertEqual(snapshot.completedSessionsThisWeek, 2)
        XCTAssertEqual(snapshot.weeklyCalories, 750)
        XCTAssertEqual(snapshot.totalMembershipMinutes, 135)
        XCTAssertEqual(snapshot.membershipHoursDisplay, "2.2h")
        XCTAssertEqual(snapshot.attendancePercent, 75)
    }

    func testGoalMetricForBuildStrength() {
        let now = Date()
        let sessions = [
            TrainerSessionRecord(id: 1, date: now, durationMin: 60, calories: 500, completed: true),
            TrainerSessionRecord(id: 2, date: Calendar.current.date(byAdding: .day, value: -1, to: now) ?? now, durationMin: 60, calories: 500, completed: true)
        ]

        let snapshot = TrainerProgressSnapshot(membershipStart: now, weeklyGoalSessions: 4, sessions: sessions)
        let metric = snapshot.dashboardGoalMetric(
            primaryGoal: .buildStrength,
            goalCount: 1,
            currentWeight: nil,
            startWeight: nil,
            goalWeight: nil,
            strengthTargetSessions: 4,
            mobilityTargetSessions: 3,
            performanceTargetMonthly: 12,
            consistencyTargetPercent: 90
        )

        XCTAssertEqual(metric.icon, "target")
        XCTAssertEqual(metric.value, "2/4")
        XCTAssertEqual(metric.label, "Session\nTarget")
        XCTAssertEqual(metric.ringProgress, 0.5, accuracy: 0.001)
    }
}
