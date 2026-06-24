import SwiftUI

// MARK: - Cause catalog (display metadata; ids are the canonical backend keys)

struct ImpactCause: Identifiable, Hashable {
    let id: String
    let label: String
    let description: String
    let symbol: String
    let hex: String

    var color: Color { Color(hex: hex) }

    static let all: [ImpactCause] = [
        ImpactCause(id: "youth_sports", label: "Youth Sports",
                    description: "Support programs and opportunities for young athletes to thrive.",
                    symbol: "figure.basketball", hex: "#E8772E"),
        ImpactCause(id: "fitness_access", label: "Fitness Access",
                    description: "Help provide access to coaching and wellness for those in need.",
                    symbol: "dumbbell.fill", hex: "#4CAF50"),
        ImpactCause(id: "mental_wellness", label: "Mental Wellness",
                    description: "Support mental health resources, education, and community programs.",
                    symbol: "brain.head.profile", hex: "#7E5BD0"),
        ImpactCause(id: "community_health", label: "Community Health",
                    description: "Support local organizations working to improve health and quality of life.",
                    symbol: "heart.fill", hex: "#E0453E"),
        ImpactCause(id: "survivor_support", label: "Survivor Support",
                    description: "Support organizations helping survivors of domestic violence, abuse, and trauma rebuild their lives.",
                    symbol: "shield.lefthalf.filled", hex: "#3E9BD0"),
    ]

    static func by(id: String?) -> ImpactCause? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

// MARK: - Models

struct ImpactAllocation: Decodable, Hashable {
    let type: String          // donate | coaching | gift | split
    let causeId: String?
    let causeLabel: String?
    let giftEmail: String?
    let splitCausePct: Int?
}

struct ImpactCredit: Decodable, Identifiable, Hashable {
    let id: String
    let clientUid: String
    let sessionId: String?
    let amount: Int
    let status: String
    let allocation: ImpactAllocation?
    let createdAt: String?
    let directedAt: String?

    var isDirected: Bool { status == "directed" }
    var amountLabel: String { "$\(amount)" }
}

struct CommunityImpact: Decodable, Hashable {
    let amountDirected: Int
    let creditsActivated: Int
    let causesSupported: Int
    let causesActive: Int
    let livesImpacted: Int
}

// MARK: - API

enum ImpactAPI {
    private struct CreditsResponse: Decodable { let impactCredits: [ImpactCredit] }
    private struct CreditResponse: Decodable { let impactCredit: ImpactCredit }
    private struct CommunityResponse: Decodable { let community: CommunityImpact }

    static func loadMyCredits(token: String) async throws -> [ImpactCredit] {
        guard let url = MontraAPIConfig.url(for: "/api/client/impact-credits") else { throw ChatError.invalidURL }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(CreditsResponse.self, from: data).impactCredits
    }

    static func directCredit(id: String, type: String, causeId: String? = nil, giftEmail: String? = nil, token: String) async throws -> ImpactCredit {
        guard let url = MontraAPIConfig.url(for: "/api/client/impact-credits/\(id)/direct") else { throw ChatError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        var body: [String: Any] = ["type": type]
        if let causeId { body["causeId"] = causeId }
        if let giftEmail { body["giftEmail"] = giftEmail }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(CreditResponse.self, from: data).impactCredit
    }

    static func loadCommunity() async throws -> CommunityImpact {
        guard let url = MontraAPIConfig.url(for: "/api/impact/community") else { throw ChatError.invalidURL }
        let (data, response) = try await URLSession.shared.data(from: url)
        try validate(response: response, data: data)
        return try JSONDecoder().decode(CommunityResponse.self, from: data).community
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
