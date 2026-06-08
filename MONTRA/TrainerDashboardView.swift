import SwiftUI

struct TrainerDashboardView: View {

    @EnvironmentObject private var auth: AuthManager
    @AppStorage("app.liveDataConnected") private var liveDataConnected = false

    // Sample data — replaced when trainer-side data model is wired up
    private let todaySessions: [TrainerClientSession] = [
        TrainerClientSession(id: 1, clientName: "Jessica R.",  time: "10:00 AM", type: "Full Body Strength",  status: .confirmed, durationMin: 60),
        TrainerClientSession(id: 2, clientName: "Marcus D.",   time: "12:00 PM", type: "HIIT & Core",         status: .confirmed, durationMin: 60),
        TrainerClientSession(id: 3, clientName: "Priya S.",    time: "2:00 PM",  type: "Lower Body Power",    status: .scheduled, durationMin: 60),
    ]

    private let upcomingSessions: [TrainerClientSession] = [
        TrainerClientSession(id: 4, clientName: "Jessica R.",  time: "10:00 AM", type: "Upper Body Strength", status: .confirmed, durationMin: 60),
        TrainerClientSession(id: 5, clientName: "Dwayne K.",   time: "11:00 AM", type: "Mobility Reset",      status: .scheduled, durationMin: 45),
    ]

    @State private var showProfileSheet = false
    @State private var showSchedules = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                TrainerCompactTopBar(
                    title: "Dashboard",
                    onMenuTap: { showProfileSheet = true }
                )

                if !liveDataConnected {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.montraOrange)
                        Text("Preview data only. Live trainer data sync is not connected yet.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.montraTextSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                // MARK: Quick Stats
                HStack(spacing: 12) {
                    TrainerStatTile(value: "\(todaySessions.count)", label: "Today's\nSessions",   icon: "calendar.badge.clock", color: .montraOrange)
                    TrainerStatTile(value: "5",                       label: "Active\nClients",     icon: "person.2.fill",        color: Color(hex: "#4CAF50"))
                    TrainerStatTile(value: "12",                      label: "Sessions\nThis Week", icon: "chart.bar.fill",       color: Color(hex: "#4A90D9"))
                }

                // MARK: Today's Schedule
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "TODAY'S SCHEDULE")

                    if todaySessions.isEmpty {
                        Text("No sessions scheduled today.")
                            .font(.system(size: 14))
                            .foregroundColor(.montraTextSecondary)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(Array(todaySessions.enumerated()), id: \.element.id) { index, session in
                            TrainerSessionRow(session: session)
                            if index < todaySessions.count - 1 {
                                Divider().background(Color.montraDivider)
                            }
                        }
                    }
                }
                .padding(18)
                .montraCard(radius: 16)

                // MARK: Upcoming Sessions
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "UPCOMING")

                    ForEach(Array(upcomingSessions.enumerated()), id: \.element.id) { index, session in
                        TrainerSessionRow(session: session)
                        if index < upcomingSessions.count - 1 {
                            Divider().background(Color.montraDivider)
                        }
                    }
                }
                .padding(18)
                .montraCard(radius: 16)

                // MARK: Quick Actions
                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "QUICK ACTIONS")

                    HStack(spacing: 12) {
                        TrainerActionButton(icon: "plus.circle.fill",      label: "Add Session")   { }
                        TrainerActionButton(icon: "person.badge.plus.fill", label: "Add Client")    { }
                        TrainerActionButton(icon: "calendar.badge.clock",    label: "Schedules")     { showSchedules = true }
                        TrainerActionButton(icon: "bubble.left.fill",       label: "Message")       { }
                    }
                }
                .padding(18)
                .montraCard(radius: 16)

                Spacer(minLength: 90)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.montraBackground)
        .sheet(isPresented: $showProfileSheet) {
            ProfileMenuSheet(isClient: false)
        }
        .sheet(isPresented: $showSchedules) {
            ClientSchedulesView()
        }
    }
}

struct TrainerSessionRow: View {
    let session: TrainerClientSession
    var showsDuration: Bool = false
    var showsCompleteAction: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(session.clientName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                Text(session.type)
                    .font(.system(size: 12))
                    .foregroundColor(.montraTextSecondary)

                if showsDuration {
                    Text("\(session.durationMin) min")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.montraTextSecondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(session.time)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                Text(session.status == .confirmed ? "Confirmed" : "Scheduled")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(session.status == .confirmed ? .green : .montraTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background((session.status == .confirmed ? Color.green : Color.white).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                if showsCompleteAction {
                    Button {
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.montraOrange)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct TrainerActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.montraOrange)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.montraTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .montraCard(radius: 12)
        }
    }
}

// MARK: - Data Model

struct TrainerClientSession: Identifiable {
    let id: Int
    let clientName: String
    let time: String
    let type: String
    let status: TrainerSessionStatus
    let durationMin: Int
}

enum TrainerSessionStatus { case confirmed, scheduled }

#Preview {
    TrainerDashboardView()
        .environmentObject(AuthManager())
}
