import SwiftUI

// MARK: - Trainer Tab Root

struct TrainerTabView: View {

    @EnvironmentObject private var auth: AuthManager
    @AppStorage("trainer.inbox.initialSegment") private var inboxInitialSegment = "requests"
    @State private var selectedTab: TrainerTab = .dashboard

    enum TrainerTab {
        case dashboard, sessions, storefront, programs, inbox
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.montraBackground.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                TrainerDashboardView(selectedTab: $selectedTab)
                    .tag(TrainerTab.dashboard)

                TrainerSessionsView()
                    .tag(TrainerTab.sessions)

                TrainerStorefrontView()
                    .tag(TrainerTab.storefront)

                TrainerProgramsView()
                    .tag(TrainerTab.programs)

                TrainerInboxView()
                    .tag(TrainerTab.inbox)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            TrainerTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(edges: .bottom)
        .onReceive(NotificationCenter.default.publisher(for: .montraPushTapped)) { note in
            let category = note.userInfo?["category"] as? String ?? ""
            switch category {
            case "request":
                inboxInitialSegment = "requests"
                selectedTab = .inbox
            case "message":
                inboxInitialSegment = "messages"
                selectedTab = .inbox
            case "session": selectedTab = .sessions
            default:        selectedTab = .dashboard
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .montraOpenTrainerInbox)) { note in
            let segment = (note.userInfo?["segment"] as? String)?.lowercased() ?? "requests"
            inboxInitialSegment = segment
            selectedTab = .inbox
        }
    }
}

// MARK: - Trainer Tab Bar

struct TrainerTabBar: View {
    @Binding var selectedTab: TrainerTabView.TrainerTab

    private let items: [(tab: TrainerTabView.TrainerTab, icon: String, label: String)] = [
        (.dashboard, "house.fill",                   "Dashboard"),
        (.sessions,  "calendar",                     "Sessions"),
        (.storefront, "storefront.fill",             "Storefront"),
        (.programs,  "doc.text.fill",                "Programs"),
        (.inbox,     "bubble.left.and.bubble.right.fill", "Inbox"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.label) { item in
                Button { selectedTab = item.tab } label: {
                    Image(systemName: item.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(selectedTab == item.tab ? .montraOrange : .montraTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
        }
        .padding(.bottom, 16)
        .background(
            Color.montraTabBarBackground
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.montraDivider),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct TrainerStorefrontView: View {
    @State private var showTrainerMenu = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                TrainerCompactTopBar(
                    title: "Storefront",
                    onMenuTap: { showTrainerMenu = true }
                )

                HStack(spacing: 12) {
                    StorefrontMetricCard(
                        title: "Total Earnings",
                        value: "$0",
                        icon: "chart.line.uptrend.xyaxis",
                        tint: .montraOrange
                    )
                    StorefrontMetricCard(
                        title: "Pending Payout",
                        value: "$0",
                        icon: "banknote.fill",
                        tint: Color(hex: "#4CAF50")
                    )
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Storefront setup is coming soon")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.montraTextPrimary)
                    Text("Earnings will appear here once you complete paid sessions. Pricing and package setup for your services is coming soon.")
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .montraCard(radius: 16)

                Spacer(minLength: 90)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.montraBackground)
        .sheet(isPresented: $showTrainerMenu) {
            ProfileMenuSheet(isClient: false)
        }
    }
}

private struct StorefrontMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(tint)
            Text(value)
                .font(.system(size: 24, weight: .black))
                .foregroundColor(.montraTextPrimary)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.montraTextSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .montraCard(radius: 14)
    }
}
