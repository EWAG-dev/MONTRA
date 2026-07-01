import XCTest
@testable import MONTRA

final class BookingAPITests: XCTestCase {
    func testCanMarkCompleteForPastScheduledSession() {
        let session = makeSession(
            startTime: ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -3600)),
            status: "scheduled"
        )

        XCTAssertTrue(session.hasStarted)
        XCTAssertTrue(session.canMarkComplete)
    }

    func testCannotMarkCompleteForFutureSession() {
        let session = makeSession(
            startTime: ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: 3600)),
            status: "scheduled"
        )

        XCTAssertFalse(session.hasStarted)
        XCTAssertFalse(session.canMarkComplete)
    }

    func testCannotMarkCompleteWhenCancelledOrCompleted() {
        let past = ISO8601DateFormatter().string(from: Date(timeIntervalSinceNow: -7200))

        let cancelled = makeSession(startTime: past, status: "cancelled")
        XCTAssertFalse(cancelled.canMarkComplete)

        let completed = makeSession(startTime: past, status: "completed")
        XCTAssertFalse(completed.canMarkComplete)
    }

    private func makeSession(startTime: String, status: String) -> BookedSession {
        BookedSession(
            id: "session_1",
            trainerId: "trainer_1",
            trainerName: "Trainer One",
            clientUid: "client_1",
            clientEmail: "client@example.com",
            clientName: "Client One",
            startTime: startTime,
            durationMin: 60,
            status: status,
            createdAt: startTime,
            updatedAt: startTime,
            completedAt: status == "completed" ? startTime : nil,
            completionNotes: nil
        )
    }
}
