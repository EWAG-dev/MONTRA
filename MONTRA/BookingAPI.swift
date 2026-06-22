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

    var startDate: Date? {
        ISO8601DateFormatter().date(from: startTime)
    }
}

enum BookingAPI {
    struct SessionResponse: Decodable {
        let session: BookedSession
    }

    struct SessionsResponse: Decodable {
        let sessions: [BookedSession]
    }

    static func bookSession(trainerId: String, clientName: String, startTime: Date, durationMin: Int = 60, token: String) async throws -> BookedSession {
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
        return try JSONDecoder().decode(SessionResponse.self, from: data).session
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

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            if let payload = try? JSONDecoder().decode(ChatAPI.APIError.self, from: data) {
                throw ChatError.server(payload.error)
            }
            throw ChatError.server("Request failed with status \(http.statusCode)")
        }
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
            status: .scheduled,
            durationMin: session.durationMin
        )
    }
}
