import SwiftUI

struct TrainerDashboardView: View {

    @Binding var selectedTab: TrainerTabView.TrainerTab
    @EnvironmentObject private var auth: AuthManager

    @State private var bookedSessions: [BookedSession] = []

    @State private var showProfileSheet = false
    @State private var showSchedules = false
    @State private var activeClientCount = 0
    @State private var pendingRequestCount = 0
    @State private var hasLoadedMatches = false
    @State private var completionTarget: BookedSession?
    @State private var completionSummary = ""
    @State private var completionExercises = ""
    @State private var completingSession = false

    private func loadSessions() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let sessions = try? await BookingAPI.loadTrainerSessions(token: tokenResult.token) else { return }
        bookedSessions = sessions
    }

    private func complete(_ session: BookedSession, notes: String?) async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }
        _ = try? await BookingAPI.completeTrainerSession(id: session.id, notes: notes, token: tokenResult.token)
        await loadSessions()
    }

    private var scheduledSessionsByDate: [(BookedSession, Date)] {
        bookedSessions
            .filter { $0.status == "scheduled" }
            .compactMap { session -> (BookedSession, Date)? in
                guard let date = session.startDate else { return nil }
                return (session, date)
            }
            .sorted { $0.1 < $1.1 }
    }

    private var todaySessions: [(BookedSession, TrainerClientSession)] {
        let cal = Calendar.current
        return scheduledSessionsByDate
            .filter { cal.isDateInToday($0.1) }
            .compactMap { booked in
                BookingAPI.asTrainerClientSession(booked.0).map { (booked.0, $0) }
            }
    }

    private var upcomingSessions: [(BookedSession, TrainerClientSession)] {
        let now = Date()
        let cal = Calendar.current
        return scheduledSessionsByDate
            .filter { $0.1 >= now && !cal.isDateInToday($0.1) }
            .compactMap { booked in
                BookingAPI.asTrainerClientSession(booked.0).map { (booked.0, $0) }
            }
    }

    private func loadMatchCounts() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let url = MontraAPIConfig.url(for: "/api/trainers/my-matches") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(tokenResult.token)", forHTTPHeaderField: "Authorization")

        struct Response: Decodable { let matches: [TrainerMatchRequest] }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let payload = try? JSONDecoder().decode(Response.self, from: data) else { return }

        activeClientCount = Set(payload.matches.filter { $0.status == "accepted" }.map(\.clientUid)).count
        pendingRequestCount = payload.matches.filter { $0.status == "pending" }.count
        hasLoadedMatches = true
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                TrainerCompactTopBar(
                    title: "Dashboard",
                    onMenuTap: { showProfileSheet = true }
                )

                if !hasLoadedMatches {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.montraOrange)
                        Text("Can't reach the MONTRA server right now — pull to refresh once you're back online.")
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
                    TrainerStatTile(value: "\(activeClientCount)",   label: "Active\nClients",      icon: "person.2.fill",        color: Color(hex: "#4CAF50"))
                    TrainerStatTile(value: "\(pendingRequestCount)", label: "Pending\nRequests",     icon: "tray.fill",            color: Color(hex: "#4A90D9"))
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
                        ForEach(Array(todaySessions.enumerated()), id: \.element.1.id) { index, pair in
                            let (booked, session) = pair
                            TrainerSessionRow(
                                session: session,
                                onComplete: booked.canMarkComplete
                                    ? {
                                        completionTarget = booked
                                        completionSummary = ""
                                        completionExercises = ""
                                    }
                                    : nil
                            )
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

                    ForEach(Array(upcomingSessions.enumerated()), id: \.element.1.id) { index, pair in
                        let (_, session) = pair
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
                        TrainerActionButton(icon: "calendar.badge.clock", label: "Schedules") { showSchedules = true }
                        TrainerActionButton(icon: "tray.fill",            label: "Requests")  { selectedTab = .inbox }
                        TrainerActionButton(icon: "bubble.left.fill",     label: "Message")   { selectedTab = .inbox }
                    }
                }
                .padding(18)
                .montraCard(radius: 16)

                Spacer(minLength: 90)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.montraBackground)
        .task {
            await loadMatchCounts()
            await loadSessions()
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileMenuSheet(isClient: false)
        }
        .sheet(isPresented: $showSchedules) {
            ClientSchedulesView()
        }
        .sheet(item: $completionTarget) { session in
            TrainerSessionCompletionSheet(
                session: session,
                summary: $completionSummary,
                exercises: $completionExercises,
                isSubmitting: completingSession,
                onSubmit: {
                    let summary = completionSummary.trimmingCharacters(in: .whitespacesAndNewlines)
                    let exercises = completionExercises.trimmingCharacters(in: .whitespacesAndNewlines)
                    let notes = [
                        summary.isEmpty ? nil : "Workout Summary:\n\(summary)",
                        exercises.isEmpty ? nil : "Exercises Completed:\n\(exercises)"
                    ]
                    .compactMap { $0 }
                    .joined(separator: "\n\n")

                    completingSession = true
                    Task {
                        await complete(session, notes: notes.isEmpty ? nil : notes)
                        completingSession = false
                        completionTarget = nil
                    }
                }
            )
        }
    }
}

struct TrainerSessionRow: View {
    let session: TrainerClientSession
    var showsDuration: Bool = false
    var onCancel: (() -> Void)? = nil
    var onComplete: (() -> Void)? = nil
    var onReport: (() -> Void)? = nil

    private var statusLabel: String {
        switch session.status {
        case .confirmed: return "Confirmed"
        case .scheduled: return "Scheduled"
        case .completed: return "Completed"
        }
    }

    private var statusColor: Color {
        switch session.status {
        case .confirmed, .completed: return .green
        case .scheduled: return .montraTextSecondary
        }
    }

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

            VStack(alignment: .trailing, spacing: 6) {
                Text(session.time)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                HStack(spacing: 4) {
                    if session.status == .completed {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    Text(statusLabel)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(statusColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 6))

                if let onComplete {
                    Button(action: onComplete) {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Mark Complete")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.montraOrange)
                    }
                    .buttonStyle(.plain)
                }

                if let onCancel {
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.montraTextSecondary)
                    }
                    .buttonStyle(.plain)
                }

                if let onReport {
                    Button(action: onReport) {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.bubble")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Report")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.montraTextSecondary)
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

private struct TrainerSessionCompletionSheet: View {
    let session: BookedSession
    @Binding var summary: String
    @Binding var exercises: String
    let isSubmitting: Bool
    let onSubmit: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Log workout and mark complete")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.montraTextPrimary)

                Text("\(session.clientName) • \(session.durationMin) min")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.montraTextSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Session summary")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.montraTextSecondary)
                    TextEditor(text: $summary)
                        .frame(minHeight: 90)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Exercises completed")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.montraTextSecondary)
                    TextEditor(text: $exercises)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: onSubmit) {
                    HStack {
                        if isSubmitting {
                            ProgressView().tint(.black)
                        }
                        Text(isSubmitting ? "Saving…" : "Save & Mark Complete")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.montraOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSubmitting)

                Spacer()
            }
            .padding(20)
            .background(Color.montraBackground)
            .navigationTitle("Complete Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

// MARK: - Data Model

struct TrainerClientSession: Identifiable {
    let id: String
    let clientName: String
    let time: String
    let type: String
    let status: TrainerSessionStatus
    let durationMin: Int
}

enum TrainerSessionStatus { case confirmed, scheduled, completed }

#Preview {
    TrainerDashboardView(selectedTab: .constant(.dashboard))
        .environmentObject(AuthManager())
}
