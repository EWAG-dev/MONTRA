import SwiftUI
import UIKit

enum ChatTarget: String, CaseIterable, Identifiable {
    case coach = "Coach"
    case support = "MONTRA Support Team"

    var id: String { rawValue }
}

struct CoachChatSheet: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var selectedTarget: ChatTarget = .coach
    @State private var messageText = ""
    @State private var showProfileSheet = false
    @State private var showNotifications = false
    @State private var showCallback = false
    @State private var threads: [ChatThread] = []
    @State private var selectedThread: ChatThread? = nil
    @State private var messages: [ChatMessage] = []
    @State private var loadingThreads = false
    @State private var loadingMessages = false
    @State private var sendingMessage = false
    @State private var chatError: String? = nil
    @AppStorage("notif.unreadCount") private var unreadCount = 0
    @AppStorage("dashboardProfileImageData") private var profileImageData: Data = Data()

    var body: some View {
        VStack(spacing: 16) {
            ClientMessagesStyleHeader(
                title: "Messages",
                onNotificationTap: { showNotifications = true },
                onProfileTap: { showProfileSheet = true },
                notificationBadgeCount: unreadCount
            )
                .padding(.horizontal, 20)

            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(ChatTarget.allCases) { target in
                        Button {
                            selectedTarget = target
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: targetIcon(for: target))
                                    .font(.system(size: 13, weight: .semibold))
                                Text(target.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(selectedTarget == target ? .montraOrange : .montraTextPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(
                                selectedTarget == target
                                    ? Color.montraFrostedOrangeFill
                                    : Color.montraFrostedSurface
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(
                                        selectedTarget == target
                                            ? Color.montraFrostedOrangeStroke
                                            : Color.montraFrostedStroke,
                                        lineWidth: 0.9
                                    )
                            )
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if selectedTarget == .coach {
                    liveCoachChatSection
                } else {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 12) {
                            targetAvatar
                            VStack(alignment: .leading, spacing: 4) {
                                Text(headerTitle)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.montraTextPrimary)
                                Text(headerSubtitle)
                                    .font(.system(size: 13))
                                    .foregroundColor(.montraTextSecondary)
                            }
                            Spacer()
                        }

                        Divider().background(Color.montraDivider)

                        VStack(alignment: .leading, spacing: 12) {
                               Text("Need a hand? A member of the MONTRA Support Team can call you back — usually within 10–15 minutes during business hours.")
                                .font(.system(size: 13))
                                .foregroundColor(.montraTextSecondary)

                            Button {
                                showCallback = true
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("Request a Callback")
                                        .font(.system(size: 15, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.montraOrange)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Link(destination: URL(string: "mailto:hello@eliteinhomefitness.com")!) {
                                Text("Or email hello@eliteinhomefitness.com")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.montraTextSecondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .montraFrostedCard(radius: 12)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)

            if selectedTarget == .coach {
                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    TextField("Write a message...", text: $messageText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.montraTextPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .montraFrostedCard(radius: 12)

                    Button {
                        Task { await sendCurrentMessage() }
                    } label: {
                        if sendingMessage {
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
                    .disabled(sendingMessage || messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedThread == nil)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 60)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.montraBackground.ignoresSafeArea())
        .sheet(isPresented: $showProfileSheet) {
            ProfileMenuSheet(isClient: true)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .sheet(isPresented: $showCallback) {
            CallbackRequestSheet(target: selectedTarget).environmentObject(auth)
        }
        .task {
            await refreshThreads()
            await loadUnreadNotificationCount()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if Task.isCancelled { break }
                if let thread = selectedThread {
                    await loadMessages(for: thread)
                } else {
                    await refreshThreads()
                }
                await loadUnreadNotificationCount()
            }
        }
    }

    @ViewBuilder
    private var liveCoachChatSection: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                targetAvatar

                VStack(alignment: .leading, spacing: 6) {
                    Text(selectedThread?.trainerName.isEmpty == false ? selectedThread?.trainerName ?? "Your Coach" : "Your Coach")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.montraTextPrimary)

                    Text(selectedThread == nil ? "No active coach thread yet" : "Message your coach about workouts, scheduling, and progress.")
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)

                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color(hex: "#22C55E"))
                            .frame(width: 7, height: 7)
                        Text("Live thread")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Color(hex: "#22C55E"))
                    }
                }

                Spacer()
            }
            .padding(14)
            .montraFrostedCard(radius: 12)

            if loadingThreads {
                ProgressView().tint(.montraOrange)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
            } else if threads.isEmpty {
                VStack(spacing: 10) {
                    Text("No active coach conversations yet")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.montraTextPrimary)
                    Text("Request a coach first, then your thread will appear here.")
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .montraFrostedCard(radius: 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(threads) { thread in
                            Button {
                                selectedThread = thread
                                Task { await loadMessages(for: thread) }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(thread.trainerName.isEmpty ? "Coach" : thread.trainerName)
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
                                .background(selectedThread?.id == thread.id ? Color.montraOrange : Color.montraFrostedSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }

                VStack(spacing: 10) {
                    if loadingMessages {
                        ProgressView().tint(.montraOrange)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    } else if messages.isEmpty {
                        Text("No messages yet. Send the first one.")
                            .font(.system(size: 13))
                            .foregroundColor(.montraTextSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(messages) { message in
                            messageBubble(message)
                        }
                    }
                }

                if let chatError {
                    Text(chatError)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        let isMine = isCurrentUserMessage(message)
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
            .background(isMine ? Color.montraOrange : Color.montraFrostedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            if !isMine { Spacer(minLength: 24) }
        }
    }

    private func isCurrentUserMessage(_ message: ChatMessage) -> Bool {
        let role = message.senderRole.lowercased()
        if role == "client" { return true }
        if role == "trainer" { return false }

        if let currentUid = auth.user?.uid, !currentUid.isEmpty, message.senderUid == currentUid {
            return true
        }

        // Fallback for legacy/partially-migrated messages that can have empty senderUid.
        return false
    }

    private func refreshThreads() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }

        if threads.isEmpty { loadingThreads = true }
        defer { loadingThreads = false }

        do {
            let loadedThreads = try await ChatAPI.loadMyThreads(token: tokenResult.token)
            threads = loadedThreads
            if selectedThread == nil || !loadedThreads.contains(where: { $0.id == selectedThread?.id }) {
                selectedThread = loadedThreads.first
            }
            if let selectedThread {
                await loadMessages(for: selectedThread)
            }
        } catch {
            chatError = error.localizedDescription
        }
    }

    private func loadMessages(for thread: ChatThread) async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }

        if messages.isEmpty { loadingMessages = true }
        defer { loadingMessages = false }

        do {
            let response = try await ChatAPI.loadMessages(conversationId: thread.id, token: tokenResult.token)
            selectedThread = response.conversation
            messages = response.messages
            chatError = nil
        } catch {
            chatError = error.localizedDescription
        }
    }

    private func sendCurrentMessage() async {
        guard let thread = selectedThread else { return }
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: true) else { return }

        sendingMessage = true
        defer { sendingMessage = false }

        do {
            let message = try await ChatAPI.sendMessage(conversationId: thread.id, text: trimmed, token: tokenResult.token)
            messages.append(message)
            messageText = ""
            chatError = nil
            await refreshThreads()
        } catch {
            chatError = error.localizedDescription
        }
    }

    private func loadUnreadNotificationCount() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let notifications = try? await NotificationsAPI.loadMine(token: tokenResult.token) else { return }
        unreadCount = notifications.filter(\.unread).count
    }

    private var headerTitle: String {
        switch selectedTarget {
        case .coach:
            return "Chat with Your Coach"
        case .support:
            return "Chat with MONTRA Support Team"
        }
    }

    private var headerSubtitle: String {
        switch selectedTarget {
        case .coach:
            return "Training questions, schedule changes, and workout feedback."
        case .support:
            return "Technical help, account help, and issue reporting."
        }
    }

    private func targetIcon(for target: ChatTarget) -> String {
        switch target {
        case .coach: return "bubble.left"
        case .support: return "headphones"
        }
    }

    @ViewBuilder
    private var targetAvatar: some View {
        switch selectedTarget {
        case .coach:
            Circle()
                .fill(Color.montraOrange.opacity(0.14))
                .frame(width: 42, height: 42)
                .overlay(Text("A").font(.system(size: 16, weight: .black)).foregroundColor(.montraOrange))
                .overlay(Circle().stroke(Color.montraOrange.opacity(0.85), lineWidth: 1))
        case .support:
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 42, height: 42)
                .overlay(Image(systemName: "headset").font(.system(size: 16, weight: .semibold)).foregroundColor(.montraTextPrimary))
                .overlay(Circle().stroke(Color.montraCardBorder, lineWidth: 0.8))
        }
    }

    @ViewBuilder
    private func userAvatar(size: CGFloat) -> some View {
        if let uiImage = UIImage(data: profileImageData), !profileImageData.isEmpty {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.montraOrange.opacity(0.8), lineWidth: 1))
        } else {
            Circle()
                .fill(Color.montraSurface)
                .frame(width: size, height: size)
                .overlay(Image(systemName: "person.fill").font(.system(size: 12, weight: .semibold)).foregroundColor(.montraOrange))
                .overlay(Circle().stroke(Color.montraOrange.opacity(0.8), lineWidth: 1))
        }
    }
}

struct MontraAIBotAvatar: View {
    var size: CGFloat = 42

    var body: some View {
        if let aiImage = UIImage(named: "MontraTeamPFP") {
            Image(uiImage: aiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.montraCardBorder, lineWidth: 0.8))
        } else {
            ZStack {
                Circle()
                    .fill(Color.montraOrange.opacity(0.14))
                    .frame(width: size, height: size)

                RoundedRectangle(cornerRadius: size * 0.24)
                    .fill(Color.white)
                    .frame(width: size * 0.54, height: size * 0.46)

                RoundedRectangle(cornerRadius: size * 0.2)
                    .fill(Color(hex: "#121319"))
                    .frame(width: size * 0.4, height: size * 0.24)

                HStack(spacing: size * 0.09) {
                    Circle().fill(Color.white).frame(width: size * 0.05, height: size * 0.05)
                    Circle().fill(Color.white).frame(width: size * 0.05, height: size * 0.05)
                }

                VStack {
                    Rectangle()
                        .fill(Color.montraOrange)
                        .frame(width: 1.6, height: size * 0.11)
                    Circle()
                        .fill(Color.montraOrange)
                        .frame(width: size * 0.08, height: size * 0.08)
                }
                .offset(y: -(size * 0.34))
            }
            .overlay(Circle().stroke(Color.montraCardBorder, lineWidth: 0.8))
        }
    }
}

// MARK: - Request a Callback (MONTRA Team concierge)

/// Mirrors the website's "Talk to a Human" callback flow inside the app. Posts to
/// the same `/api/leads/callback` endpoint so app + web leads land in one place,
/// with source-based priority routing (Support tab -> support, Team tab -> sales).
struct CallbackRequestSheet: View {
    let target: ChatTarget

    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("quiz.firstName") private var quizFirstName: String = ""

    @State private var firstName = ""
    @State private var phone = ""
    @State private var email = ""
    @State private var message = ""
    @State private var submitting = false
    @State private var submitted = false
    @State private var errorMessage: String? = nil

    private let helpOptions = ["Choosing a coach", "Pricing question", "Booking a consultation", "Something else"]

    var body: some View {
        NavigationStack {
            ScrollView {
                if submitted {
                    confirmation
                } else {
                    form
                }
            }
            .background(Color.montraBackground)
            .navigationTitle("MONTRA Team")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(submitted ? "Done" : "Close") { dismiss() }
                }
            }
        }
        .onAppear {
            if firstName.isEmpty {
                firstName = quizFirstName.isEmpty ? auth.userDisplayName.components(separatedBy: " ").first ?? "" : quizFirstName
            }
            if email.isEmpty { email = auth.user?.email ?? "" }
            if message.isEmpty { message = helpOptions.first ?? "" }
        }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Need help from a real person?")
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.montraTextPrimary)
                Text("A member of the MONTRA Team can call you — usually within 10–15 minutes during business hours.")
                    .font(.system(size: 13))
                    .foregroundColor(.montraTextSecondary)
            }

            field(icon: "person.fill", placeholder: "First Name", text: $firstName)
            field(icon: "phone.fill", placeholder: "Phone Number", text: $phone, keyboard: .phonePad)
            field(icon: "envelope.fill", placeholder: "Email (optional)", text: $email, keyboard: .emailAddress)

            VStack(alignment: .leading, spacing: 8) {
                Text("How can we help?")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.montraTextSecondary)
                Picker("How can we help?", selection: $message) {
                    ForEach(helpOptions, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
            }

            Button { Task { await submit() } } label: {
                HStack {
                    if submitting { ProgressView().tint(.white) }
                    Text(submitting ? "Requesting…" : "Request a Call")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(canSubmit ? Color.montraOrange : Color.montraOrange.opacity(0.5))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canSubmit || submitting)

            Label("Your information is secure and will never be shared.", systemImage: "lock.fill")
                .font(.system(size: 11))
                .foregroundColor(.montraTextSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
    }

    private var confirmation: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Color.montraOrange).frame(width: 64, height: 64)
                Image(systemName: "checkmark").font(.system(size: 28, weight: .black)).foregroundColor(.white)
            }
            .padding(.top, 40)
            Text("Request Received!")
                .font(.system(size: 22, weight: .black))
                .foregroundColor(.montraTextPrimary)
            Text("A member of the MONTRA Team will contact you within ")
                .font(.system(size: 14))
                .foregroundColor(.montraTextSecondary)
            + Text("10–15 minutes").font(.system(size: 14, weight: .black)).foregroundColor(.montraOrange)
            + Text(" during business hours.\n\nFor urgent requests, please call our main office.")
                .font(.system(size: 14))
                .foregroundColor(.montraTextSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(28)
        .frame(maxWidth: .infinity)
    }

    private var canSubmit: Bool {
        !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
        phone.filter(\.isNumber).count >= 7
    }

    private func field(icon: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.montraTextSecondary)
                .frame(width: 18)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .foregroundColor(.montraTextPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .montraFrostedCard(radius: 12)
    }

    private func submit() async {
        submitting = true
        errorMessage = nil
        // Support tab routes to the support team; the Team tab routes to sales.
        let source = target == .support ? "existing_client" : "ios_app"
        do {
            try await CallbackAPI.requestCallback(
                firstName: firstName, phone: phone, email: email, message: message, source: source
            )
            submitted = true
        } catch let ChatError.server(msg) {
            errorMessage = msg
        } catch {
            errorMessage = "Couldn't submit your request. Please try again."
        }
        submitting = false
    }
}

enum CallbackAPI {
    static func requestCallback(firstName: String, phone: String, email: String, message: String, source: String) async throws {
        guard let url = MontraAPIConfig.url(for: "/api/leads/callback") else { throw ChatError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "firstName": firstName.trimmingCharacters(in: .whitespacesAndNewlines),
            "phone": phone.trimmingCharacters(in: .whitespacesAndNewlines),
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "message": message,
            "source": source,
            "sourcePath": "ios-app",
            "context": ["platform": "iOS app"],
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            if let payload = try? JSONDecoder().decode(ChatAPI.APIError.self, from: data) {
                throw ChatError.server(payload.error)
            }
            throw ChatError.server("Request failed")
        }
    }
}

#Preview {
    CoachChatSheet()
}
