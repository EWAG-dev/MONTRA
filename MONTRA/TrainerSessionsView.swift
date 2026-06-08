import SwiftUI

struct TrainerSessionsView: View {

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("app.liveDataConnected") private var liveDataConnected = false
    @State private var selectedFilter: SessionFilter = .upcoming
    @State private var showTrainerMenu = false

    enum SessionFilter: String, CaseIterable {
        case upcoming = "Upcoming"
        case today    = "Today"
        case past     = "Past"
    }

    // Sample sessions — replaced when Firestore data model is wired up
    private let allSessions: [TrainerClientSession] = [
        TrainerClientSession(id: 1,  clientName: "Jessica R.",  time: "10:00 AM", type: "Full Body Strength",  status: .confirmed, durationMin: 60),
        TrainerClientSession(id: 2,  clientName: "Marcus D.",   time: "12:00 PM", type: "HIIT & Core",         status: .confirmed, durationMin: 60),
        TrainerClientSession(id: 3,  clientName: "Priya S.",    time: "2:00 PM",  type: "Lower Body Power",    status: .scheduled, durationMin: 60),
        TrainerClientSession(id: 4,  clientName: "Dwayne K.",   time: "11:00 AM", type: "Mobility Reset",      status: .scheduled, durationMin: 45),
        TrainerClientSession(id: 5,  clientName: "Jessica R.",  time: "10:00 AM", type: "Upper Body Strength", status: .confirmed, durationMin: 60),
        TrainerClientSession(id: 6,  clientName: "Marcus D.",   time: "9:00 AM",  type: "HIIT Conditioning",   status: .confirmed, durationMin: 60),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    TrainerCompactTopBar(
                        title: "Sessions",
                        onMenuTap: { showTrainerMenu = true },
                        trailingIcon: "plus"
                    ) {
                        // Add session action — wired when booking is built
                    }

                    if !liveDataConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.montraOrange)
                            Text("Preview data only. Live trainer session data is not connected yet.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.montraTextSecondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // MARK: Filter Pills
                    HStack(spacing: 8) {
                        ForEach(SessionFilter.allCases, id: \.self) { filter in
                            Button { selectedFilter = filter } label: {
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(
                                        selectedFilter == filter
                                            ? (colorScheme == .light ? .montraOrange : .black)
                                            : .montraTextSecondary
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        selectedFilter == filter
                                            ? (colorScheme == .light ? Color.montraAccentFrost : Color.montraOrange)
                                            : (colorScheme == .light ? Color.montraFrostedSurface : Color.white.opacity(0.07))
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(
                                                selectedFilter == filter
                                                    ? (colorScheme == .light ? Color.montraAccentBorder : Color.clear)
                                                    : (colorScheme == .light ? Color.montraCardBorder : Color.clear),
                                                lineWidth: colorScheme == .light ? 1 : 0
                                            )
                                    )
                            }
                        }
                    }

                    // MARK: Session Cards
                    VStack(alignment: .leading, spacing: 14) {
                        SectionHeader(title: "SESSION LIST")

                        VStack(spacing: 0) {
                            ForEach(Array(allSessions.enumerated()), id: \.element.id) { index, session in
                                TrainerSessionRow(
                                    session: session,
                                    showsDuration: true,
                                    showsCompleteAction: true
                                )
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)

                                if index < allSessions.count - 1 {
                                    Divider()
                                        .background(Color.montraDivider)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .montraCard(radius: 16)
                    }

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.montraBackground)
        }
        .sheet(isPresented: $showTrainerMenu) {
            ProfileMenuSheet(isClient: false)
        }
    }
}

#Preview {
    TrainerSessionsView()
        .environmentObject(AuthManager())
}
