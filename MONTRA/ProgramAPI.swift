import Foundation

struct ProgramExercise: Codable, Hashable, Identifiable {
    var name: String
    var sets: String
    var reps: String
    var notes: String

    // Stable identity for SwiftUI list editing; not part of the wire format.
    var id = UUID()

    enum CodingKeys: String, CodingKey { case name, sets, reps, notes }

    init(name: String = "", sets: String = "", reps: String = "", notes: String = "") {
        self.name = name; self.sets = sets; self.reps = reps; self.notes = notes
    }
}

struct ProgramWorkout: Codable, Hashable, Identifiable {
    var day: String
    var title: String
    var exercises: [ProgramExercise]

    var id = UUID()

    enum CodingKeys: String, CodingKey { case day, title, exercises }

    init(day: String = "", title: String = "", exercises: [ProgramExercise] = []) {
        self.day = day; self.title = title; self.exercises = exercises
    }
}

/// A trainer-authored program template.
struct Program: Decodable, Identifiable, Hashable {
    let id: String
    let trainerId: String
    let title: String
    let description: String
    let weeks: Int
    let workouts: [ProgramWorkout]
    let createdAt: String?
    let updatedAt: String?
}

/// A program assigned to a client (immutable snapshot of the template at assign time).
struct AssignedProgram: Decodable, Identifiable, Hashable {
    let id: String
    let programId: String?
    let trainerName: String
    let title: String
    let description: String
    let weeks: Int
    let workouts: [ProgramWorkout]
    let status: String
    let assignedAt: String?
}

enum ProgramAPI {
    private struct ProgramsResponse: Decodable { let programs: [Program] }
    private struct ProgramResponse: Decodable { let program: Program }
    private struct AssignedResponse: Decodable { let programs: [AssignedProgram] }

    static func loadTrainerPrograms(token: String) async throws -> [Program] {
        try await getJSON(path: "/api/trainers/programs", token: token, as: ProgramsResponse.self).programs
    }

    static func loadClientPrograms(token: String) async throws -> [AssignedProgram] {
        try await getJSON(path: "/api/client/programs", token: token, as: AssignedResponse.self).programs
    }

    @discardableResult
    static func createProgram(title: String, description: String, weeks: Int, workouts: [ProgramWorkout], token: String) async throws -> Program {
        try await sendProgram(path: "/api/trainers/programs", method: "POST", title: title, description: description, weeks: weeks, workouts: workouts, token: token)
    }

    @discardableResult
    static func updateProgram(id: String, title: String, description: String, weeks: Int, workouts: [ProgramWorkout], token: String) async throws -> Program {
        try await sendProgram(path: "/api/trainers/programs/\(id)", method: "PUT", title: title, description: description, weeks: weeks, workouts: workouts, token: token)
    }

    static func deleteProgram(id: String, token: String) async throws {
        guard let url = MontraAPIConfig.url(for: "/api/trainers/programs/\(id)") else { throw ChatError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    static func assignProgram(id: String, clientUid: String, token: String) async throws {
        guard let url = MontraAPIConfig.url(for: "/api/trainers/programs/\(id)/assign") else { throw ChatError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["clientUid": clientUid])
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
    }

    // MARK: - Helpers

    private static func sendProgram(path: String, method: String, title: String, description: String, weeks: Int, workouts: [ProgramWorkout], token: String) async throws -> Program {
        guard let url = MontraAPIConfig.url(for: path) else { throw ChatError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let workoutPayload: [[String: Any]] = workouts.map { workout in
            [
                "day": workout.day,
                "title": workout.title,
                "exercises": workout.exercises.map { ex in
                    ["name": ex.name, "sets": ex.sets, "reps": ex.reps, "notes": ex.notes]
                },
            ]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "title": title,
            "description": description,
            "weeks": weeks,
            "workouts": workoutPayload,
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ProgramResponse.self, from: data).program
    }

    private static func getJSON<T: Decodable>(path: String, token: String, as type: T.Type) async throws -> T {
        guard let url = MontraAPIConfig.url(for: path) else { throw ChatError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(T.self, from: data)
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
