import SwiftUI
import UIKit

enum ChatTarget: String, CaseIterable, Identifiable {
    case coach = "Coach"
    case montraTeam = "MONTRA Team"
    case support = "Support"

    var id: String { rawValue }
}

struct CoachChatSheet: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var selectedTarget: ChatTarget = .coach
    @State private var messageText = ""
    @State private var showProfileSheet = false
    @State private var showNotifications = false
    @State private var threads: [ChatThread] = []
    @State private var selectedThread: ChatThread? = nil
    @State private var messages: [ChatMessage] = []
    @State private var loadingThreads = false
    @State private var loadingMessages = false
    @State private var sendingMessage = false
    @State private var chatError: String? = nil
    @AppStorage("dashboardProfileImageData") private var profileImageData: Data = Data()

    var body: some View {
        VStack(spacing: 16) {
            ClientMessagesStyleHeader(
                title: "Messages",
                onNotificationTap: { showNotifications = true },
                onProfileTap: { showProfileSheet = true }
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

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Contact us directly:")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.montraTextSecondary)

                            Link(destination: URL(string: "mailto:hello@eliteinhomefitness.com")!) {
                                HStack(spacing: 10) {
                                    Image(systemName: "envelope.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.montraOrange)
                                    Text("hello@eliteinhomefitness.com")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.montraOrange)
                                }
                            }

                            Text("In-app messaging with the MONTRA team is coming in a future update.")
                                .font(.system(size: 12))
                                .foregroundColor(.montraTextSecondary)
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
        .task {
            await refreshThreads()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 8_000_000_000)
                if Task.isCancelled { break }
                if let thread = selectedThread {
                    await loadMessages(for: thread)
                } else {
                    await refreshThreads()
                }
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
            .background(isMine ? Color.montraOrange : Color.montraFrostedSurface)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            if !isMine { Spacer(minLength: 24) }
        }
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

    private var headerTitle: String {
        switch selectedTarget {
        case .coach:
            return "Chat with Your Coach"
        case .montraTeam:
            return "Chat with MONTRA Team"
        case .support:
            return "Chat with Support"
        }
    }

    private var headerSubtitle: String {
        switch selectedTarget {
        case .coach:
            return "Training questions, schedule changes, and workout feedback."
        case .montraTeam:
            return "Insights, accountability, and personalized support."
        case .support:
            return "Technical help and issue reporting."
        }
    }

    private func targetIcon(for target: ChatTarget) -> String {
        switch target {
        case .coach: return "bubble.left"
        case .montraTeam: return "sparkles"
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
        case .montraTeam:
            MontraAIBotAvatar(size: 42)
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

#Preview {
    CoachChatSheet()
}
