import SwiftUI

struct TrainerSessionsView: View {

    @EnvironmentObject private var auth: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedFilter: SessionFilter = .upcoming
    @State private var showTrainerMenu = false
    @State private var bookedSessions: [BookedSession] = []
    @State private var hasLoaded = false

    enum SessionFilter: String, CaseIterable {
        case upcoming = "Upcoming"
        case today    = "Today"
        case past     = "Past"
    }

    private func loadSessions() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let sessions = try? await BookingAPI.loadTrainerSessions(token: tokenResult.token) else { return }
        bookedSessions = sessions
        hasLoaded = true
    }

    private func cancel(_ session: BookedSession) async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }
        _ = try? await BookingAPI.cancelTrainerSession(id: session.id, token: tokenResult.token)
        await loadSessions()
    }

    private var allSessions: [(BookedSession, TrainerClientSession)] {
        let now = Date()
        let cal = Calendar.current
        return bookedSessions
            .filter { $0.status == "scheduled" }
            .compactMap { session -> (BookedSession, Date)? in
                guard let date = session.startDate else { return nil }
                return (session, date)
            }
            .filter { _, date in
                switch selectedFilter {
                case .upcoming: return date >= now
                case .today: return cal.isDateInToday(date)
                case .past: return date < now
                }
            }
            .sorted { $0.1 < $1.1 }
            .compactMap { session, _ in
                BookingAPI.asTrainerClientSession(session).map { (session, $0) }
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    TrainerCompactTopBar(
                        title: "Sessions",
                        onMenuTap: { showTrainerMenu = true }
                    )

                    if hasLoaded && allSessions.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.montraOrange)
                            Text("No \(selectedFilter.rawValue.lowercased()) sessions.")
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
                            ForEach(Array(allSessions.enumerated()), id: \.element.1.id) { index, pair in
                                let (bookedSession, displaySession) = pair
                                TrainerSessionRow(
                                    session: displaySession,
                                    showsDuration: true,
                                    onCancel: { Task { await cancel(bookedSession) } }
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
        .task {
            await loadSessions()
        }
    }
}

#Preview {
    TrainerSessionsView()
        .environmentObject(AuthManager())
}
