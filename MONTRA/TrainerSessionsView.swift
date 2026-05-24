import SwiftUI

struct TrainerSessionsView: View {

    @State private var selectedFilter: SessionFilter = .upcoming

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

                    // MARK: Header
                    HStack {
                        Text("Sessions")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.montraTextPrimary)
                        Spacer()
                        Button {
                            // Add session action — wired when booking is built
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 26))
                                .foregroundColor(.montraOrange)
                        }
                    }
                    .padding(.top, 8)

                    // MARK: Filter Pills
                    HStack(spacing: 8) {
                        ForEach(SessionFilter.allCases, id: \.self) { filter in
                            Button { selectedFilter = filter } label: {
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(selectedFilter == filter ? .black : .montraTextSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.montraOrange : Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }

                    // MARK: Session Cards
                    VStack(spacing: 12) {
                        ForEach(allSessions) { session in
                            TrainerFullSessionCard(session: session)
                        }
                    }

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.montraBackground)
        }
    }
}

// MARK: - Full Session Card

struct TrainerFullSessionCard: View {
    let session: TrainerClientSession

    var body: some View {
        HStack(spacing: 16) {
            // Client initial badge
            Circle()
                .fill(Color.montraOrange.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(
                    Text(String(session.clientName.prefix(1)))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.montraOrange)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(session.clientName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                Text(session.type)
                    .font(.system(size: 13))
                    .foregroundColor(.montraTextSecondary)
                HStack(spacing: 10) {
                    Label(session.time, systemImage: "clock")
                    Label("\(session.durationMin) min", systemImage: "timer")
                }
                .font(.system(size: 11))
                .foregroundColor(.montraTextSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 6) {
                Text(session.status == .confirmed ? "Confirmed" : "Scheduled")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(session.status == .confirmed ? .green : .montraTextSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background((session.status == .confirmed ? Color.green : Color.white).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                Button {
                    // Mark complete action
                } label: {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.montraOrange)
                }
            }
        }
        .padding(16)
        .montraCard(radius: 16)
    }
}

#Preview {
    TrainerSessionsView()
        .environmentObject(AuthManager())
}
