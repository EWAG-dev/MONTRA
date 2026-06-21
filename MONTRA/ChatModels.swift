import Foundation

struct ChatThread: Identifiable, Decodable, Hashable {
    let id: String
    let trainerId: String
    let clientUid: String
    let trainerName: String
    let clientEmail: String
    let clientName: String
    let lastMessage: String
    let lastMessageAt: String?
    let lastSenderUid: String
    let lastSenderRole: String
    let createdAt: String?
    let updatedAt: String?
}

struct ChatMessage: Identifiable, Decodable, Hashable {
    let id: String
    let conversationId: String
    let senderUid: String
    let senderRole: String
    let senderName: String
    let text: String
    let createdAt: String
}

enum ChatAPI {
    struct ThreadResponse: Decodable {
        let conversations: [ChatThread]
    }

    struct MessageResponse: Decodable {
        let conversation: ChatThread
        let messages: [ChatMessage]
    }

    struct SendResponse: Decodable {
        let message: ChatMessage
    }

    static func loadMyThreads(token: String) async throws -> [ChatThread] {
        guard let url = MontraAPIConfig.url(for: "/api/conversations/my-threads") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(ThreadResponse.self, from: data).conversations
    }

    static func loadMessages(conversationId: String, token: String) async throws -> MessageResponse {
        guard let url = MontraAPIConfig.url(for: "/api/conversations/\(conversationId)/messages") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(MessageResponse.self, from: data)
    }

    static func sendMessage(conversationId: String, text: String, token: String) async throws -> ChatMessage {
        guard let url = MontraAPIConfig.url(for: "/api/conversations/\(conversationId)/messages") else {
            throw ChatError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["text": text])

        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(SendResponse.self, from: data).message
    }

    private static func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            if let payload = try? JSONDecoder().decode(APIError.self, from: data) {
                throw ChatError.server(payload.error)
            }
            throw ChatError.server("Request failed with status \(http.statusCode)")
        }
    }

    struct APIError: Decodable {
        let error: String
    }
}

enum ChatError: LocalizedError {
    case invalidURL
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Chat endpoint URL is invalid."
        case .server(let message):
            return message
        }
    }
}
