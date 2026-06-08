import SwiftUI

// MARK: - Trainer Tab Root

struct TrainerTabView: View {

    @EnvironmentObject private var auth: AuthManager
    @State private var selectedTab: TrainerTab = .dashboard

    enum TrainerTab {
        case dashboard, sessions, storefront, programs, inbox
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.montraBackground.ignoresSafeArea()

            TabView(selection: $selectedTab) {
                TrainerDashboardView()
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

    private let monthRevenue: Double = 4820
    private let pendingPayout: Double = 1260

    private let services: [TrainerServiceItem] = [
        .init(title: "Intro Session", description: "Quick assessment and goal mapping for new clients.", mode: "In-Person / Online", price: "$49", accent: .montraOrange),
        .init(title: "1:1 Coaching", description: "Personalized training plans built around each client.", mode: "In-Person / Online", price: "$120 / session", accent: Color(hex: "#30D158")),
        .init(title: "Virtual Coaching", description: "Remote check-ins, programming, and accountability.", mode: "Online Only", price: "$100 / session", accent: Color(hex: "#64D2FF")),
        .init(title: "Semi-Private", description: "Partner sessions with shared goals and focused coaching.", mode: "In-Person", price: "$85 / session", accent: Color(hex: "#0A84FF")),
    ]

    private let packages: [TrainerPackageItem] = [
        .init(
            title: "3 Month Coaching",
            subtitle: "Commit to the process. See real results.",
            weeklyRows: [
                .init(label: "1x / week", total: "$1,080", perSession: "$90 / session"),
                .init(label: "2x / week", total: "$2,040", perSession: "$85 / session"),
                .init(label: "3x / week", total: "$2,970", perSession: "$82 / session"),
                .init(label: "4x / week", total: "$3,840", perSession: "$80 / session"),
            ],
            highlights: ["Personalized Programming", "Coach Support", "Accountability Check-ins"],
            color: Color(hex: "#30D158")
        ),
        .init(
            title: "6 Month Coaching",
            subtitle: "Stay consistent. Transform your life.",
            weeklyRows: [
                .init(label: "1x / week", total: "$1,920", perSession: "$80 / session"),
                .init(label: "2x / week", total: "$3,600", perSession: "$75 / session"),
                .init(label: "3x / week", total: "$5,220", perSession: "$72 / session"),
                .init(label: "4x / week", total: "$6,720", perSession: "$70 / session"),
            ],
            highlights: ["Personalized Programming", "Coach Support", "Progress Tracking"],
            color: .montraOrange,
            badge: "MOST POPULAR"
        ),
        .init(
            title: "12 Month Coaching",
            subtitle: "The ultimate commitment. Best long-term value.",
            weeklyRows: [
                .init(label: "1x / week", total: "$3,600", perSession: "$75 / session"),
                .init(label: "2x / week", total: "$6,840", perSession: "$71 / session"),
                .init(label: "3x / week", total: "$9,960", perSession: "$69 / session"),
                .init(label: "4x / week", total: "$12,840", perSession: "$67 / session"),
            ],
            highlights: ["Personalized Programming", "Coach Support", "MONTRA App Access"],
            color: Color(hex: "#0A84FF"),
            badge: "BEST VALUE"
        )
    ]

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
                        value: "$\(Int(monthRevenue))",
                        icon: "chart.line.uptrend.xyaxis",
                        tint: .montraOrange
                    )
                    StorefrontMetricCard(
                        title: "Pending Payout",
                        value: "$\(Int(pendingPayout))",
                        icon: "banknote.fill",
                        tint: Color(hex: "#4CAF50")
                    )
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "SERVICES")
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(services) { service in
                            TrainerServiceCard(service: service)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    SectionHeader(title: "COACHING PACKAGES")
                    VStack(spacing: 12) {
                        ForEach(packages) { package in
                            TrainerPackageCard(package: package)
                        }
                    }
                }

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

private struct TrainerServiceItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let mode: String
    let price: String
    let accent: Color
}

private struct TrainerServiceCard: View {
    let service: TrainerServiceItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(service.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.montraTextPrimary)
                Spacer()
                Circle()
                    .fill(service.accent)
                    .frame(width: 8, height: 8)
            }

            Text(service.description)
                .font(.system(size: 12))
                .foregroundColor(.montraTextSecondary)
                .lineLimit(3)

            Text(service.mode)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.montraTextSecondary)

            Text(service.price)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(service.accent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 154, alignment: .topLeading)
        .padding(14)
        .montraCard(radius: 14)
    }
}

private struct TrainerPackageItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let weeklyRows: [TrainerPackageRow]
    let highlights: [String]
    let color: Color
    var badge: String? = nil
}

private struct TrainerPackageRow: Identifiable {
    let id = UUID()
    let label: String
    let total: String
    let perSession: String
}

private struct TrainerPackageCard: View {
    let package: TrainerPackageItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(package.title)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(.montraTextPrimary)
                    Text(package.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)
                        .lineLimit(2)
                }
                Spacer()
                if let badge = package.badge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(package.color)
                        .clipShape(Capsule())
                }
            }

            VStack(spacing: 6) {
                ForEach(package.weeklyRows) { row in
                    VStack(spacing: 2) {
                        HStack(spacing: 8) {
                            Circle()
                                .stroke(Color.montraTextSecondary, lineWidth: 1)
                                .frame(width: 14, height: 14)
                            Text(row.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.montraTextSecondary)
                            Spacer()
                            Text(row.total)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.montraTextPrimary)
                        }

                        HStack {
                            Spacer()
                            Text(row.perSession)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.montraTextSecondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Divider().background(Color.montraDivider)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(package.highlights, id: \.self) { item in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(package.color)
                        Text(item)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.montraTextSecondary)
                    }
                }
            }

            Button {
            } label: {
                Text("Choose Plan")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(package.color)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(package.color.opacity(0.85), lineWidth: 1)
        )
    }
}
