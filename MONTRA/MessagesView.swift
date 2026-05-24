import SwiftUI

enum ChatTarget: String, CaseIterable, Identifiable {
    case coach = "Coach"
    case montraTeam = "MONTRA Team"
    case support = "Support"

    var id: String { rawValue }
}

struct CoachChatSheet: View {
    @State private var selectedTarget: ChatTarget = .coach
    @State private var messageText = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    ForEach(ChatTarget.allCases) { target in
                        Button {
                            selectedTarget = target
                        } label: {
                            Text(target.rawValue)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(selectedTarget == target ? .black : .montraTextPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedTarget == target ? Color.montraOrange : Color.montraSurface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    Text(headerTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.montraTextPrimary)

                    Text(headerSubtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .montraCard(radius: 12)

                Spacer()

                HStack(spacing: 10) {
                    TextField("Write a message...", text: $messageText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.montraTextPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .montraCard(radius: 12)

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
            }
            .padding(20)
            .padding(.bottom, 60)
            .background(Color.montraBackground.ignoresSafeArea())
            .navigationTitle("Messages")
            .navigationBarTitleDisplayMode(.inline)
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
            return "Account setup, membership, and platform questions."
        case .support:
            return "Technical help and urgent issue reporting."
        }
    }
}

#Preview {
    CoachChatSheet()
}
