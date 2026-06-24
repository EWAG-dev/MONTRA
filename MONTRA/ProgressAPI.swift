import Foundation

struct ClientProgress: Decodable, Hashable {
    let clientUid: String
    let currentWeight: String
    let startWeight: String
    let weightLossGoal: String
    let selectedGoals: [String]
    let strengthWeeklyTarget: String
    let enduranceMinutesTarget: String
    let mobilitySessionsTarget: String
    let performanceMonthlyTarget: String
    let consistencyPercentTarget: String
}

struct WeightEntry: Decodable, Hashable, Identifiable {
    let date: String
    let weight: Double

    var id: String { date }
    var parsedDate: Date? { ISO8601DateFormatter().date(from: date) }
}

enum ProgressAPI {
    struct ProgressResponse: Decodable {
        let progress: ClientProgress
    }

    struct WeightHistoryResponse: Decodable {
        let weightLog: [WeightEntry]
    }

    static func loadWeightHistory(token: String) async throws -> [WeightEntry] {
        guard let url = MontraAPIConfig.url(for: "/api/client/progress/weight-history") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(WeightHistoryResponse.self, from: data).weightLog
    }

    @discardableResult
    static func logWeight(_ weight: Double, date: Date? = nil, token: String) async throws -> [WeightEntry] {
        guard let url = MontraAPIConfig.url(for: "/api/client/progress/weight-entry") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = ["weight": weight]
        if let date {
            body["date"] = ISO8601DateFormatter().string(from: date)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(WeightHistoryResponse.self, from: data).weightLog
    }

    static func load(token: String) async throws -> ClientProgress {
        guard let url = MontraAPIConfig.url(for: "/api/client/progress") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ProgressResponse.self, from: data).progress
    }

    static func save(
        currentWeight: String,
        startWeight: String,
        weightLossGoal: String,
        selectedGoals: [String],
        strengthWeeklyTarget: String,
        enduranceMinutesTarget: String,
        mobilitySessionsTarget: String,
        performanceMonthlyTarget: String,
        consistencyPercentTarget: String,
        token: String
    ) async throws -> ClientProgress {
        guard let url = MontraAPIConfig.url(for: "/api/client/progress") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "currentWeight": currentWeight,
            "startWeight": startWeight,
            "weightLossGoal": weightLossGoal,
            "selectedGoals": selectedGoals,
            "strengthWeeklyTarget": strengthWeeklyTarget,
            "enduranceMinutesTarget": enduranceMinutesTarget,
            "mobilitySessionsTarget": mobilitySessionsTarget,
            "performanceMonthlyTarget": performanceMonthlyTarget,
            "consistencyPercentTarget": consistencyPercentTarget,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ProgressResponse.self, from: data).progress
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
}
