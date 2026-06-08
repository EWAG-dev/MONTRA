import SwiftUI
import UIKit

enum ChatTarget: String, CaseIterable, Identifiable {
    case coach = "Coach"
    case montraTeam = "MONTRA Team"
    case support = "Support"

    var id: String { rawValue }
}

struct CoachChatSheet: View {
    @State private var selectedTarget: ChatTarget = .coach
    @State private var messageText = ""
    @State private var showProfileSheet = false
    @State private var showNotifications = false
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

                HStack(spacing: 12) {
                    targetAvatar

                    VStack(alignment: .leading, spacing: 6) {
                        Text(headerTitle)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.montraTextPrimary)

                        Text(headerSubtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.montraTextSecondary)

                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(hex: "#22C55E"))
                                .frame(width: 7, height: 7)
                            Text("Always here for you")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(Color(hex: "#22C55E"))
                        }
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .montraFrostedCard(radius: 12)
            }
            .padding(.horizontal, 20)
            .padding(.top, 2)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                TextField("Write a message...", text: $messageText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.montraTextPrimary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .montraFrostedCard(radius: 12)

                Button {
                    messageText = ""
                } label: {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44)
                        .background(Color.montraOrange)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.montraBackground.ignoresSafeArea())
        .sheet(isPresented: $showProfileSheet) {
            ProfileMenuSheet(isClient: true)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
    }

    private var headerTitle: String {
        switch selectedTarget {
        case .coach:
            return "Chat with Alex Morgan"
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
            return "AI-powered insights, accountability, and personalized support."
        case .support:
            return "Technical help and urgent issue reporting."
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
