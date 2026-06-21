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
    @State private var requestActionError: String? = nil
    @State private var activeRequestActionId: String? = nil
    @State private var chatThreads: [ChatThread] = []
    @State private var selectedThread: ChatThread? = nil
    @State private var chatMessages: [ChatMessage] = []
    @State private var chatLoadingThreads = false
    @State private var chatLoadingMessages = false
    @State private var chatSending = false
    @State private var chatMessageText = ""
    @State private var chatError: String? = nil

    enum Segment: String, CaseIterable {
        case requests      = "Requests"
        case messages      = "Messages"
        case notifications = "Notifications"
    }

    private let conversations: [TrainerConversation] = []
    private let notifications: [AppNotification] = []

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
                        Text(auth.user?.displayName ?? "Trainer")
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
        .task {
            await fetchMatchRequests()
            await refreshChatThreads()
        }
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
                    MatchRequestCard(
                        request: req,
                        actionInFlight: activeRequestActionId == req.id,
                        onMessage: {
                            Task { await openConversationForRequest(req) }
                        },
                        onAccept: {
                            Task { await updateRequestStatus(requestId: req.id, action: "accept") }
                        },
                        onDecline: {
                            Task { await updateRequestStatus(requestId: req.id, action: "decline") }
                        }
                    )
                }

                if let requestActionError {
                    Text(requestActionError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func openConversationForRequest(_ request: TrainerMatchRequest) async {
        selectedSegment = .messages
        requestActionError = nil

        if chatThreads.isEmpty {
            await refreshChatThreads()
        }

        let expectedConversationId: String
        if !(request.conversationId ?? "").isEmpty {
            expectedConversationId = request.conversationId ?? ""
        } else {
            expectedConversationId = ChatAPI.conversationId(trainerId: request.trainerId ?? "", clientUid: request.clientUid)
        }

        if let thread = chatThreads.first(where: { $0.id == expectedConversationId }) {
            selectedThread = thread
            await loadChatMessages(for: thread)
            return
        }

        if let fallback = chatThreads.first(where: { $0.clientUid == request.clientUid }) ?? chatThreads.first {
            selectedThread = fallback
            await loadChatMessages(for: fallback)
            return
        }

        chatError = "Could not open conversation yet. Pull to refresh and try again."
    }

    private func fetchMatchRequests() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: true),
              let url = MontraAPIConfig.url(for: "/api/trainers/my-matches") else { return }
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

    private func updateRequestStatus(requestId: String, action: String) async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: true),
              let url = MontraAPIConfig.url(for: "/api/trainers/matches/\(requestId)/\(action)") else { return }

        activeRequestActionId = requestId
        defer { activeRequestActionId = nil }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(tokenResult.token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else {
                requestActionError = "No response from server"
                return
            }

            guard (200...299).contains(http.statusCode) else {
                struct APIError: Decodable { let error: String }
                let payload = try? JSONDecoder().decode(APIError.self, from: data)
                requestActionError = payload?.error ?? "Unable to update request"
                return
            }

            requestActionError = nil
            await fetchMatchRequests()
        } catch {
            requestActionError = error.localizedDescription
        }
    }

    // MARK: - Messages

    @ViewBuilder
    private var messagesContent: some View {
        VStack(spacing: 14) {
            if chatLoadingThreads {
                HStack { Spacer(); ProgressView().tint(.montraOrange); Spacer() }
                    .padding(.top, 24)
            } else if chatThreads.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 32))
                        .foregroundColor(.montraTextSecondary)
                    Text("No conversations yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.montraTextSecondary)
                    Text("Check the Requests tab for new client requests.")
                        .font(.system(size: 12))
                        .foregroundColor(.montraTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 32)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(chatThreads) { thread in
                            Button {
                                selectedThread = thread
                                Task { await loadChatMessages(for: thread) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(thread.clientName.isEmpty ? "New Client" : thread.clientName)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(selectedThread?.id == thread.id ? .black : .montraTextPrimary)
                                    Text(thread.lastMessage.isEmpty ? "Say hello" : thread.lastMessage)
                                        .font(.system(size: 11))
                                        .foregroundColor(selectedThread?.id == thread.id ? .black.opacity(0.75) : .montraTextSecondary)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(width: 180, alignment: .leading)
                                .background(selectedThread?.id == thread.id ? Color.montraOrange : Color.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
            }

            VStack(spacing: 10) {
                if chatLoadingMessages {
                    ProgressView().tint(.montraOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                } else if chatMessages.isEmpty {
                    Text(chatThreads.isEmpty ? "Select or accept a request to start messaging." : "No messages yet. Send the first one.")
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ForEach(chatMessages) { message in
                        chatBubble(message)
                    }
                }
            }

            if let chatError {
                Text(chatError)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                TextField(chatThreads.isEmpty ? "No thread available yet" : "Write a message...", text: $chatMessageText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.montraTextPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .montraCard(radius: 12)
                    .disabled(chatThreads.isEmpty)

                Button {
                    Task { await sendChatMessage() }
                } label: {
                    if chatSending {
                        ProgressView().tint(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.montraOrange)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44)
                            .background(Color.montraOrange)
                            .clipShape(Circle())
                    }
                }
                .disabled(chatThreads.isEmpty || chatSending || chatMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedThread == nil)
            }
        }
    }

    @ViewBuilder
    private func chatBubble(_ message: ChatMessage) -> some View {
        let isMine = message.senderUid == auth.user?.uid
        HStack {
            if isMine { Spacer(minLength: 24) }
            VStack(alignment: .leading, spacing: 4) {
                Text(message.senderName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isMine ? .black.opacity(0.75) : .montraTextSecondary)
                Text(message.text)
                    .font(.system(size: 14))
                    .foregroundColor(isMine ? .black : .montraTextPrimary)
            }
            .padding(12)
            .background(isMine ? Color.montraOrange : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            if !isMine { Spacer(minLength: 24) }
        }
    }

    private func refreshChatThreads() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: true) else { return }

        chatLoadingThreads = true
        defer { chatLoadingThreads = false }

        do {
            let threads = try await ChatAPI.loadMyThreads(token: tokenResult.token)
            chatThreads = threads
            if selectedThread == nil || !threads.contains(where: { $0.id == selectedThread?.id }) {
                selectedThread = threads.first
            }
            if let selectedThread {
                await loadChatMessages(for: selectedThread)
            }
        } catch {
            chatError = error.localizedDescription
        }
    }

    private func loadChatMessages(for thread: ChatThread) async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: true) else { return }

        chatLoadingMessages = true
        defer { chatLoadingMessages = false }

        do {
            let response = try await ChatAPI.loadMessages(conversationId: thread.id, token: tokenResult.token)
            selectedThread = response.conversation
            chatMessages = response.messages
            chatError = nil
        } catch {
            chatError = error.localizedDescription
        }
    }

    private func sendChatMessage() async {
        guard let thread = selectedThread else { return }
        let trimmed = chatMessageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: true) else { return }

        chatSending = true
        defer { chatSending = false }

        do {
            let message = try await ChatAPI.sendMessage(conversationId: thread.id, text: trimmed, token: tokenResult.token)
            chatMessages.append(message)
            chatMessageText = ""
            chatError = nil
            await refreshChatThreads()
        } catch {
            chatError = error.localizedDescription
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
    let trainerId: String?
    let conversationId: String?
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
    let actionInFlight: Bool
    let onMessage: () -> Void
    let onAccept: () -> Void
    let onDecline: () -> Void

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
        .overlay(alignment: .bottomTrailing) {
            HStack(spacing: 8) {
                Button(action: onMessage) {
                    Text("Message")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.montraTextPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                }
                .disabled(actionInFlight)

                if request.status == "pending" {
                    Button(action: onDecline) {
                        Text("Decline")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.montraTextSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .disabled(actionInFlight)

                    Button(action: onAccept) {
                        if actionInFlight {
                            ProgressView()
                                .tint(.black)
                                .frame(width: 58, height: 28)
                                .background(Color.montraOrange)
                                .clipShape(Capsule())
                        } else {
                            Text("Accept")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.montraOrange)
                                .clipShape(Capsule())
                        }
                    }
                    .disabled(actionInFlight)
                }
            }
            .padding(12)
        }
    }
}

#Preview {
    TrainerInboxView()
        .environmentObject(AuthManager())
}
