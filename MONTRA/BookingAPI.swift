import Foundation

struct BookedSession: Identifiable, Decodable, Hashable {
    let id: String
    let trainerId: String
    let trainerName: String
    let clientUid: String
    let clientEmail: String
    let clientName: String
    let startTime: String
    let durationMin: Int
    let status: String
    let createdAt: String
    let updatedAt: String
    let completedAt: String?
    let completionNotes: String?

    var startDate: Date? {
        ISO8601DateFormatter().date(from: startTime)
    }

    /// True once the session's scheduled start time has passed.
    var hasStarted: Bool {
        guard let startDate else { return false }
        return startDate <= Date()
    }

    var isCompleted: Bool { status == "completed" }
    var isCancelled: Bool { status == "cancelled" }

    /// A started, non-cancelled, not-yet-completed session can be marked complete.
    var canMarkComplete: Bool {
        hasStarted && !isCancelled && !isCompleted
    }
}

enum BookingAPI {
    struct SessionResponse: Decodable {
        let session: BookedSession
        let impactCredit: ImpactCredit?
    }

    struct SessionsResponse: Decodable {
        let sessions: [BookedSession]
    }

    static func bookSession(trainerId: String, clientName: String, startTime: Date, durationMin: Int = 60, token: String) async throws -> (session: BookedSession, impactCredit: ImpactCredit?) {
        guard let url = MontraAPIConfig.url(for: "/api/client/sessions") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let isoStartTime = ISO8601DateFormatter().string(from: startTime)
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "trainerId": trainerId,
            "clientName": clientName,
            "startTime": isoStartTime,
            "durationMin": durationMin,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        let decoded = try JSONDecoder().decode(SessionResponse.self, from: data)
        return (decoded.session, decoded.impactCredit)
    }

    static func loadMySessions(token: String) async throws -> [BookedSession] {
        guard let url = MontraAPIConfig.url(for: "/api/client/sessions") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(SessionsResponse.self, from: data).sessions
    }

    static func loadTrainerSessions(token: String) async throws -> [BookedSession] {
        guard let url = MontraAPIConfig.url(for: "/api/trainers/my-sessions") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(SessionsResponse.self, from: data).sessions
    }

    static func cancelClientSession(id: String, token: String) async throws -> BookedSession {
        guard let url = MontraAPIConfig.url(for: "/api/client/sessions/\(id)/cancel") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(SessionResponse.self, from: data).session
    }

    static func cancelTrainerSession(id: String, token: String) async throws -> BookedSession {
        guard let url = MontraAPIConfig.url(for: "/api/trainers/sessions/\(id)/cancel") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(SessionResponse.self, from: data).session
    }

    static func completeTrainerSession(id: String, notes: String? = nil, token: String) async throws -> BookedSession {
        try await completeSession(path: "/api/trainers/sessions/\(id)/complete", notes: notes, token: token)
    }

    static func reportTrainerSessionIssue(id: String, reason: String, detail: String?, token: String) async throws {
        guard let url = MontraAPIConfig.url(for: "/api/trainers/sessions/\(id)/report") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "reason": reason.trimmingCharacters(in: .whitespacesAndNewlines),
            "detail": detail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    static func completeClientSession(id: String, notes: String? = nil, token: String) async throws -> BookedSession {
        try await completeSession(path: "/api/client/sessions/\(id)/complete", notes: notes, token: token)
    }

    private static func completeSession(path: String, notes: String?, token: String) async throws -> BookedSession {
        guard let url = MontraAPIConfig.url(for: path) else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedNotes.isEmpty {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: ["notes": trimmedNotes])
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(SessionResponse.self, from: data).session
    }

    static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            if let payload = try? JSONDecoder().decode(ChatAPI.APIError.self, from: data) {
                throw ChatError.server(payload.error)
            }
            throw ChatError.server("Request failed with status \(http.statusCode)")
        }
    }

    /// A verified review a client leaves after completing a session.
    struct Review: Identifiable, Decodable, Hashable {
        let id: String
        let trainerId: String
        let rating: Int
        let text: String
    }

    private struct ReviewResponse: Decodable { let review: Review }

    /// Submits a verified review for a completed session. The backend enforces
    /// that the session is the caller's and is completed (one review per session).
    static func submitReview(sessionId: String, rating: Int, text: String, token: String) async throws -> Review {
        guard let url = MontraAPIConfig.url(for: "/api/client/reviews") else {
            throw ChatError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "sessionId": sessionId,
            "rating": rating,
            "text": text.trimmingCharacters(in: .whitespacesAndNewlines),
        ])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ReviewResponse.self, from: data).review
    }

    /// Maps a backend session to the trainer-side display model used by
    /// TrainerDashboardView/TrainerSessionsView.
    static func asTrainerClientSession(_ session: BookedSession) -> TrainerClientSession? {
        guard let date = session.startDate else { return nil }
        let dayFormatter = DateFormatter(); dayFormatter.dateFormat = "EEE"
        let timeFormatter = DateFormatter(); timeFormatter.dateFormat = "h:mm a"
        return TrainerClientSession(
            id: session.id,
            clientName: session.clientName.isEmpty ? "Client" : session.clientName,
            time: "\(dayFormatter.string(from: date)) \(timeFormatter.string(from: date))",
            type: "Training Session",
            status: session.isCompleted ? .completed : .scheduled,
            durationMin: session.durationMin
        )
    }
}
