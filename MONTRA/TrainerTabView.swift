import SwiftUI

// MARK: - Trainer Tab Root

struct TrainerTabView: View {

    @EnvironmentObject private var auth: AuthManager
    @State private var selectedTab: TrainerTab = .dashboard
    @State private var isCoachChatPresented = false

    enum TrainerTab {
        case dashboard, sessions, programs, inbox
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.montraBackground.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                TrainerDashboardView()
                    .tag(TrainerTab.dashboard)

                TrainerSessionsView()
                    .tag(TrainerTab.sessions)

                TrainerProgramsView()
                    .tag(TrainerTab.programs)

                TrainerInboxView()
                    .tag(TrainerTab.inbox)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            TrainerTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Trainer Tab Bar

struct TrainerTabBar: View {
    @Binding var selectedTab: TrainerTabView.TrainerTab

    private let items: [(tab: TrainerTabView.TrainerTab, icon: String, label: String)] = [
        (.dashboard, "house.fill",                   "Dashboard"),
        (.sessions,  "calendar",                     "Sessions"),
        (.programs,  "doc.text.fill",                "Programs"),
        (.inbox,     "bubble.left.and.bubble.right.fill", "Inbox"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.label) { item in
                Button { selectedTab = item.tab } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .medium))
                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(selectedTab == item.tab ? .montraOrange : .montraTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
        }
        .background(
            Color(hex: "#0C0C0C")
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.montraDivider),
                    alignment: .top
                )
        )
    }
}
