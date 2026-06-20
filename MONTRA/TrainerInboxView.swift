import SwiftUI
import UIKit

struct TrainerInboxView: View {

    @EnvironmentObject private var auth: AuthManager
    @AppStorage("app.liveDataConnected") private var liveDataConnected = false
    @State private var selectedSegment: Segment = .requests
    @State private var messageText = ""
    @State private var showTrainerMenu = false
    @AppStorage("trainer.profileImageData") private var trainerProfileImageData: Data = Data()
    @State private var matchRequests: [TrainerMatchRequest] = []
    @State private var requestsLoading = false

    enum Segment: String, CaseIterable {
        case requests      = "Requests"
        case messages      = "Messages"
        case notifications = "Notifications"
    }

    // Sample data — replaced when Firestore messaging is wired up
    private let conversations: [TrainerConversation] = [
        TrainerConversation(id: 1, clientName: "Jessica R.",  lastMessage: "See you tomorrow at 10!", time: "2m",        unread: true, tint: Color(hex: "#F97316")),
        TrainerConversation(id: 2, clientName: "Marcus D.",   lastMessage: "Can we move Friday's session?", time: "1h", unread: true, tint: Color(hex: "#3B82F6")),
        TrainerConversation(id: 3, clientName: "Priya S.",    lastMessage: "Thanks for the program notes.", time: "3h", unread: false, tint: Color(hex: "#A855F7")),
        TrainerConversation(id: 4, clientName: "Dwayne K.",   lastMessage: "Feeling good after yesterday!", time: "Yesterday", unread: false, tint: Color(hex: "#10B981")),
    ]

    private let notifications: [AppNotification] = [
        AppNotification(id: 1, title: "New booking request", detail: "Jessica R. requested a session on May 27 at 10:00 AM.", time: "5m",        isUnread: true),
        AppNotification(id: 2, title: "Session cancelled",   detail: "Marcus D. cancelled the May 25 12:00 PM session.",       time: "30m",       isUnread: true),
        AppNotification(id: 3, title: "Program completed",   detail: "Priya S. completed week 4 of Mobility Reset.",          time: "2h",        isUnread: false),
        AppNotification(id: 4, title: "New client signup",   detail: "Dwayne K. has joined MONTRA and is assigned to you.",   time: "Yesterday", isUnread: false),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {

                TrainerCompactTopBar(
                    title: "Inbox",
                    onMenuTap: { showTrainerMenu = true }
                )

                if !liveDataConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.montraOrange)
                        Text("Preview data only. Live trainer inbox data is not connected yet.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.montraTextSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // MARK: Profile Header
                HStack(spacing: 14) {
                    ZStack {
                        if let image = UIImage(data: trainerProfileImageData), !trainerProfileImageData.isEmpty {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 54, height: 54)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.montraOrange.opacity(0.15))
                                .frame(width: 54, height: 54)
                                .overlay(
                                    Text("T")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.montraOrange)
                                )
                        }
                    }
                    .overlay(Circle().stroke(Color.montraOrange, lineWidth: 1.5))

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Alex Morgan")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.montraTextPrimary)
                        Text("Personal Trainer · MONTRA")
                            .font(.system(size: 13))
                            .foregroundColor(.montraTextSecondary)
                    }

                    Spacer()
                }
                .padding(.top, 8)

                // MARK: Segment Picker
                HStack(spacing: 0) {
                    ForEach(Segment.allCases, id: \.self) { seg in
                        Button { selectedSegment = seg } label: {
                            VStack(spacing: 8) {
                                Text(seg.rawValue)
                                    .font(.system(size: 14, weight: selectedSegment == seg ? .semibold : .regular))
                                    .foregroundColor(selectedSegment == seg ? .montraOrange : .montraTextSecondary)
                                Rectangle()
                                    .fill(selectedSegment == seg ? Color.montraOrange : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 4)

                // MARK: Content
                switch selectedSegment {
                case .requests:      requestsContent
                case .messages:      messagesContent
                case .notifications: notificationsContent
                }

                Spacer(minLength: 90)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.montraBackground)
        .task { await fetchMatchRequests() }
        .sheet(isPresented: $showTrainerMenu) {
            ProfileMenuSheet(isClient: false)
        }
    }

    // MARK: - Requests (live)

    @ViewBuilder
    private var requestsContent: some View {
        if requestsLoading {
            HStack { Spacer(); ProgressView().tint(.montraOrange); Spacer() }.padding(.top, 24)
        } else if matchRequests.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "tray")
                    .font(.system(size: 32))
                    .foregroundColor(.montraTextSecondary)
                Text("No client requests yet")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.montraTextSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 40)
        } else {
            VStack(spacing: 10) {
                ForEach(matchRequests) { req in
                    MatchRequestCard(request: req)
                }
            }
        }
    }

    private func fetchMatchRequests() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let url = MontraAPIConfig.url(for: "/api/trainers/my-profile") else { return }
        requestsLoading = true
        defer { requestsLoading = false }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(tokenResult.token)", forHTTPHeaderField: "Authorization")
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return }
        struct Response: Decodable { let matches: [TrainerMatchRequest] }
        if let response = try? JSONDecoder().decode(Response.self, from: data) {
            matchRequests = response.matches
        }
    }

    // MARK: - Messages

    @ViewBuilder
    private var messagesContent: some View {
        VStack(spacing: 10) {
            ForEach(conversations) { convo in
                ConversationRow(convo: convo)
            }
        }
    }

    // MARK: - Notifications

    @ViewBuilder
    private var notificationsContent: some View {
        VStack(spacing: 10) {
            ForEach(notifications) { item in
                NotificationRow(item: item)
            }
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let convo: TrainerConversation

    var body: some View {
        HStack(spacing: 14) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(convo.tint.opacity(0.15))
                    .frame(width: 46, height: 46)
                    .overlay(
                        Text(convo.initials)
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(convo.tint)
                    )
                    .overlay(Circle().stroke(convo.tint.opacity(0.8), lineWidth: 1))
                if convo.unread {
                    Circle()
                        .fill(Color.montraOrange)
                        .frame(width: 9, height: 9)
                        .offset(x: 2, y: -2)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(convo.clientName)
                    .font(.system(size: 14, weight: convo.unread ? .semibold : .regular))
                    .foregroundColor(.montraTextPrimary)
                Text(convo.lastMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.montraTextSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(convo.time)
                .font(.system(size: 11))
                .foregroundColor(.montraTextSecondary)
        }
        .padding(14)
        .montraCard(radius: 14)
    }
}

// MARK: - Data Model

struct TrainerConversation: Identifiable {
    let id: Int
    let clientName: String
    let lastMessage: String
    let time: String
    let unread: Bool
    let tint: Color

    var initials: String {
        clientName
            .split(separator: " ")
            .compactMap { $0.first }
            .prefix(2)
            .map(String.init)
            .joined()
    }
}

// MARK: - Match Request Model

struct TrainerMatchRequest: Identifiable, Decodable {
    let id: String
    let clientUid: String
    let clientEmail: String
    let clientProfile: ClientProfile
    let status: String
    let createdAt: String
    let trainerName: String

    struct ClientProfile: Decodable {
        let firstName: String
        let goal: String
        let location: String
        let coachPreference: String
        let availability: [String]
    }

    var initials: String {
        String(clientProfile.firstName.prefix(1)).uppercased()
    }
    var timeAgo: String {
        let formatter = ISO8601DateFormatter()
        guard let date = formatter.date(from: createdAt) else { return "" }
        let diff = Int(Date().timeIntervalSince(date))
        if diff < 3600  { return "\(diff / 60)m ago" }
        if diff < 86400 { return "\(diff / 3600)h ago" }
        return "\(diff / 86400)d ago"
    }
}

// MARK: - Match Request Card

struct MatchRequestCard: View {
    let request: TrainerMatchRequest

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.montraOrange.opacity(0.15))
                    .frame(width: 46, height: 46)
                Text(request.initials)
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(.montraOrange)
            }
            .overlay(Circle().stroke(Color.montraOrange.opacity(0.6), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(request.clientProfile.firstName.isEmpty ? "New Client" : request.clientProfile.firstName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.montraTextPrimary)
                    Text(request.status.capitalized)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(request.status == "pending" ? .montraOrange : .green)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background((request.status == "pending" ? Color.montraOrange : Color.green).opacity(0.12))
                        .clipShape(Capsule())
                }
                Text("\(request.clientProfile.goal) · \(request.clientProfile.location)")
                    .font(.system(size: 12))
                    .foregroundColor(.montraTextSecondary)
                    .lineLimit(1)
                if !request.clientProfile.availability.isEmpty {
                    Text(request.clientProfile.availability.joined(separator: ", "))
                        .font(.system(size: 11))
                        .foregroundColor(.montraTextSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(request.timeAgo)
                .font(.system(size: 11))
                .foregroundColor(.montraTextSecondary)
        }
        .padding(14)
        .montraCard(radius: 14)
    }
}

#Preview {
    TrainerInboxView()
        .environmentObject(AuthManager())
}
