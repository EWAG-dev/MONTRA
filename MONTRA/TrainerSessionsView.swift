import SwiftUI

struct TrainerSessionsView: View {

    @EnvironmentObject private var auth: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedFilter: SessionFilter = .upcoming
    @State private var showTrainerMenu = false
    @State private var bookedSessions: [BookedSession] = []
    @State private var hasLoaded = false
    @State private var cancelError: String?
    @State private var actionError: String?
    @State private var completionTarget: BookedSession?
    @State private var completionSummary = ""
    @State private var completionExercises = ""
    @State private var completingSession = false
    @State private var reportTarget: BookedSession?
    @State private var reportReason = ""
    @State private var reportDetail = ""
    @State private var reportingIssue = false

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
        do {
            _ = try await BookingAPI.cancelTrainerSession(id: session.id, token: tokenResult.token)
            await loadSessions()
        } catch {
            cancelError = error.localizedDescription
        }
    }

    private func complete(_ session: BookedSession, notes: String?) async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }
        do {
            _ = try await BookingAPI.completeTrainerSession(id: session.id, notes: notes, token: tokenResult.token)
            await loadSessions()
        } catch {
            actionError = error.localizedDescription
        }
    }

    private func reportIssue(_ session: BookedSession, reason: String, detail: String?) async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }
        do {
            try await BookingAPI.reportTrainerSessionIssue(
                id: session.id,
                reason: reason,
                detail: detail,
                token: tokenResult.token
            )
        } catch {
            actionError = error.localizedDescription
        }
    }

    private var allSessions: [(BookedSession, TrainerClientSession)] {
        let now = Date()
        let cal = Calendar.current
        return bookedSessions
            // Upcoming/Today show scheduled only; Past also surfaces completed sessions.
            .filter { selectedFilter == .past ? $0.status != "cancelled" : $0.status == "scheduled" }
            .compactMap { session -> (BookedSession, Date)? in
                guard let date = session.startDate else { return nil }
                return (session, date)
            }
            .filter { session, date in
                switch selectedFilter {
                case .upcoming: return date >= now
                case .today: return cal.isDateInToday(date)
                case .past: return date < now || session.isCompleted
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
                                    // Upcoming sessions can be cancelled; started (not-yet-completed)
                                    // sessions can be marked complete; completed ones show neither.
                                    onCancel: bookedSession.canMarkComplete || bookedSession.isCompleted
                                        ? nil
                                        : { Task { await cancel(bookedSession) } },
                                    onComplete: bookedSession.canMarkComplete
                                        ? {
                                            completionTarget = bookedSession
                                            completionSummary = ""
                                            completionExercises = ""
                                        }
                                        : nil,
                                    onReport: {
                                        reportTarget = bookedSession
                                        reportReason = "Client no-show or dispute"
                                        reportDetail = ""
                                    }
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
        .alert("Couldn't cancel session", isPresented: Binding(get: { cancelError != nil }, set: { if !$0 { cancelError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(cancelError ?? "")
        }
        .alert("Couldn't update session", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(actionError ?? "")
        }
        .task {
            await loadSessions()
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
        .sheet(item: $reportTarget) { session in
            TrainerSessionIssueReportSheet(
                session: session,
                reason: $reportReason,
                detail: $reportDetail,
                isSubmitting: reportingIssue,
                onSubmit: {
                    let reason = reportReason.trimmingCharacters(in: .whitespacesAndNewlines)
                    let detail = reportDetail.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !reason.isEmpty else { return }
                    reportingIssue = true
                    Task {
                        await reportIssue(session, reason: reason, detail: detail.isEmpty ? nil : detail)
                        reportingIssue = false
                        reportTarget = nil
                    }
                }
            )
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

private struct TrainerSessionIssueReportSheet: View {
    let session: BookedSession
    @Binding var reason: String
    @Binding var detail: String
    let isSubmitting: Bool
    let onSubmit: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let reasonOptions = [
        "Client no-show or dispute",
        "Safety concern",
        "Harassment or inappropriate behavior",
        "Payment / booking issue",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                Text("Report a client issue")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.montraTextPrimary)

                Text("Session with \(session.clientName)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.montraTextSecondary)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.montraTextSecondary)
                    Picker("Reason", selection: $reason) {
                        ForEach(reasonOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.montraTextSecondary)
                    TextEditor(text: $detail)
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
                        Text(isSubmitting ? "Submitting…" : "Submit Report")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.montraOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isSubmitting || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()
            }
            .padding(20)
            .background(Color.montraBackground)
            .navigationTitle("Report Issue")
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

#Preview {
    TrainerSessionsView()
        .environmentObject(AuthManager())
}
