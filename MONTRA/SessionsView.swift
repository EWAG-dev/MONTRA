import SwiftUI
import UIKit

// MARK: - Sessions / Booking View

struct SessionsView: View {
    let onOpenCoachChat: () -> Void

    @EnvironmentObject private var auth: AuthManager
    private let cal = Calendar.current

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var pendingSlot: BookingSlot? = nil
    @State private var showConfirm = false
    @State private var showProfileSheet = false
    @State private var showNotifications = false
    @State private var bookedSessions: [BookedSession] = []
    @State private var bookingError: String? = nil
    @State private var isBooking = false

    @AppStorage("client.schedule.days")      private var scheduleDaysRaw: String = ""
    @AppStorage("client.schedule.time")      private var scheduleTimeRaw: String = ""
    @AppStorage("trainer.availableDays")     private var trainerDaysRaw: String = ""
    @AppStorage("trainer.availableHours")    private var trainerHoursRaw: String = ""
    @AppStorage("quiz.requestedTrainerName") private var trainerFullName: String = ""
    @AppStorage("quiz.requestedTrainer")     private var requestedTrainerId: String = ""
    @AppStorage("quiz.firstName")            private var clientFirstName: String = ""

    private func loadTrainerAvailability() async {
        guard let profile = await fetchPublicTrainerProfile(trainerId: requestedTrainerId) else { return }
        if !profile.availabilityDays.isEmpty {
            trainerDaysRaw = profile.availabilityDays.joined(separator: ",")
        }
        if let start = profile.workingHours?.start, let end = profile.workingHours?.end {
            let startHour = parseHour(start)
            let endHour = parseHour(end)
            if startHour >= 0, endHour > startHour {
                trainerHoursRaw = Array(startHour..<endHour).map(String.init).joined(separator: ",")
            }
        }
    }

    private var trainerFirstName: String {
        let name = trainerFullName.isEmpty ? "Your Trainer" : trainerFullName
        return name.components(separatedBy: " ").first ?? "Trainer"
    }

    private var trainerDisplayName: String {
        trainerFullName.isEmpty ? "Your Trainer" : trainerFullName
    }

    private var trainerInitials: String {
        trainerDisplayName.components(separatedBy: " ")
            .compactMap { $0.first }.prefix(2).map(String.init).joined()
    }

    private var trainerAvailableDays: Set<String> {
        Set(trainerDaysRaw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    private var trainerHours: [Int] {
        trainerHoursRaw.split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }.sorted()
    }

    private var bookedKeys: Set<String> {
        Set(bookedSessions.compactMap { session -> String? in
            guard session.status == "scheduled", let date = session.startDate else { return nil }
            return slotKey(date: date, hour: cal.component(.hour, from: date))
        })
    }

    private var scheduleDays: Set<String> {
        Set(scheduleDaysRaw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    private var scheduleHour: Int {
        parseHour(scheduleTimeRaw)
    }

    // 14 days starting from today — past days are excluded so the calendar
    // never presents slots the backend will reject as "in the past".
    private var calendarDays: [Date] {
        let today = cal.startOfDay(for: Date())
        return (0..<14).compactMap { cal.date(byAdding: .day, value: $0, to: today) }
    }

    private func slotsFor(_ date: Date) -> [BookingSlot] {
        let dayName = fullDayName(date)
        guard trainerAvailableDays.contains(dayName) else { return [] }
        return trainerHours.map { hour in
            let key = slotKey(date: date, hour: hour)
            let isBooked = bookedKeys.contains(key)
            let isScheduled = scheduleDays.contains(dayName) && scheduleHour == hour
            return BookingSlot(date: date, hour: hour, key: key, isBooked: isBooked, isScheduled: isScheduled)
        }
    }

    private var upcomingBooked: [BookedSession] {
        let now = Date()
        return bookedSessions
            .filter { $0.status == "scheduled" }
            .compactMap { session -> (BookedSession, Date)? in
                guard let date = session.startDate, date >= now else { return nil }
                return (session, date)
            }
            .sorted { $0.1 < $1.1 }
            .map { $0.0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Header ────────────────────────────────────────
                    ClientMessagesStyleHeader(
                        title: "Sessions",
                        onNotificationTap: { showNotifications = true },
                        onProfileTap: { showProfileSheet = true }
                    )

                    if requestedTrainerId.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No trainer matched yet")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.montraTextPrimary)
                            Text("Complete matching to see your trainer's availability and book a session.")
                                .font(.system(size: 13))
                                .foregroundColor(.montraTextSecondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .montraCard(radius: 16)
                    } else {
                    // ── Trainer banner ────────────────────────────────
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.montraOrange.opacity(0.15))
                            .frame(width: 42, height: 42)
                            .overlay(
                                Text(trainerInitials)
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundColor(.montraOrange)
                            )
                            .overlay(Circle().stroke(Color.montraOrange, lineWidth: 1))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(trainerDisplayName)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.montraTextPrimary)
                            Text(trainerDaysRaw.isEmpty ? "Loading availability…" : "Available \(trainerDaysRaw.components(separatedBy: ",").map { String($0.trimmingCharacters(in: .whitespaces).prefix(3)) }.joined(separator: " · "))")
                                .font(.system(size: 12))
                                .foregroundColor(.montraTextSecondary)
                        }
                        Spacer()
                        HStack(spacing: 4) {
                            Circle().fill(Color(hex: "#22C55E")).frame(width: 6, height: 6)
                            Text("Available")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.montraTextSecondary)
                        }
                    }
                    .padding(14)
                    .montraCard(radius: 14)

                    // ── Calendar strip ────────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(monthYearLabel(selectedDate))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.montraTextPrimary)
                            Spacer()
                            if !scheduleDaysRaw.isEmpty {
                                HStack(spacing: 4) {
                                    Circle().fill(Color(hex: "#22C55E")).frame(width: 6, height: 6)
                                    Text("Recurring")
                                        .font(.system(size: 11))
                                        .foregroundColor(.montraTextSecondary)
                                }
                            }
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(calendarDays, id: \.self) { day in
                                    CalendarDayCell(
                                        date: day,
                                        isSelected: cal.isDate(day, inSameDayAs: selectedDate),
                                        isToday: cal.isDateInToday(day),
                                        isAvailable: trainerAvailableDays.contains(fullDayName(day)),
                                        hasBooking: hasBooking(on: day),
                                        isRecurring: scheduleDays.contains(fullDayName(day))
                                    ) {
                                        selectedDate = day
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .padding(16)
                    .montraCard(radius: 16)

                    // ── Time slots ────────────────────────────────────
                    let slots = slotsFor(selectedDate)
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            SectionHeader(title: "TIMES — \(shortDateLabel(selectedDate).uppercased())")
                            Spacer()
                        }
                        if slots.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 20))
                                    .foregroundColor(.montraTextSecondary)
                                Text("\(trainerFirstName) is not available on \(fullDayName(selectedDate))s.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.montraTextSecondary)
                            }
                            .padding(.vertical, 8)
                        } else {
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 10
                            ) {
                                ForEach(slots) { slot in
                                    TimeSlotButton(slot: slot) {
                                        guard !slot.isBooked else { return }
                                        pendingSlot = slot
                                        showConfirm = true
                                    }
                                }
                            }
                        }
                    }

                    // ── Upcoming booked sessions ───────────────────────
                    if !upcomingBooked.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "YOUR UPCOMING SESSIONS")
                            ForEach(upcomingBooked.prefix(8)) { session in
                                BookedSessionRow(
                                    session: session,
                                    trainerName: trainerDisplayName
                                ) {
                                    Task { await cancelSession(session) }
                                }
                            }
                        }
                    }
                    } // requestedTrainerId else-branch

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.montraBackground)
        }
        .task {
            await loadTrainerAvailability()
            await loadMySessions()
        }
        .confirmationDialog(
            pendingSlot.map { "Book \($0.timeLabel) with \(trainerFirstName)?" } ?? "",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            if let slot = pendingSlot {
                Button("Confirm Booking") { Task { await confirmBook(slot) } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let slot = pendingSlot {
                Text("\(longDateLabel(slot.date)) · 60 min")
            }
        }
        .alert("Booking", isPresented: Binding(get: { bookingError != nil }, set: { if !$0 { bookingError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(bookingError ?? "")
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileMenuSheet(isClient: true)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
    }

    // MARK: - Helpers

    private func loadMySessions() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let sessions = try? await BookingAPI.loadMySessions(token: tokenResult.token) else { return }
        bookedSessions = sessions
    }

    private func confirmBook(_ slot: BookingSlot) async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else {
            bookingError = "You need to be signed in to book a session."
            return
        }

        let startDate = cal.date(bySettingHour: slot.hour, minute: 0, second: 0, of: slot.date) ?? slot.date
        isBooking = true
        defer { isBooking = false }

        do {
            _ = try await BookingAPI.bookSession(
                trainerId: requestedTrainerId,
                clientName: clientFirstName,
                startTime: startDate,
                token: tokenResult.token
            )
            await loadMySessions()
        } catch {
            bookingError = error.localizedDescription
        }
    }

    private func cancelSession(_ session: BookedSession) async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }
        do {
            _ = try await BookingAPI.cancelClientSession(id: session.id, token: tokenResult.token)
            await loadMySessions()
        } catch {
            bookingError = error.localizedDescription
        }
    }

    private func slotKey(date: Date, hour: Int) -> String {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0, hour)
    }

    private func hasBooking(on date: Date) -> Bool {
        let c = cal.dateComponents([.year, .month, .day], from: date)
        let prefix = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        return bookedKeys.contains { $0.hasPrefix(prefix) }
    }

    private func fullDayName(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: date)
    }

    private func monthYearLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"; return f.string(from: date)
    }

    private func shortDateLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE, MMM d"; return f.string(from: date)
    }

    private func longDateLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE, MMMM d"; return f.string(from: date)
    }

    private func parseHour(_ s: String) -> Int {
        guard !s.isEmpty else { return -1 }
        let parts = s.components(separatedBy: ":")
        guard let h = Int(parts.first?.trimmingCharacters(in: .whitespaces) ?? "") else { return -1 }
        if s.contains("PM") && h != 12 { return h + 12 }
        if s.contains("AM") && h == 12 { return 0 }
        return h
    }
}

// MARK: - Booking Slot Model

struct BookingSlot: Identifiable {
    let date: Date
    let hour: Int
    let key: String
    let isBooked: Bool
    let isScheduled: Bool
    var id: String { key }

    var isPast: Bool {
        let slotDate = Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: date) ?? date
        return slotDate <= Date()
    }

    var timeLabel: String {
        let h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(h):00 \(hour >= 12 ? "PM" : "AM")"
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isAvailable: Bool
    let hasBooking: Bool
    let isRecurring: Bool
    let action: () -> Void

    private let cal = Calendar.current

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Text(abbrev)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(isSelected ? .black : .montraTextSecondary)
                Text(dayNum)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isSelected ? .black : (isToday ? .montraOrange : .montraTextPrimary))
                // dot indicator
                Circle()
                    .fill(dotColor)
                    .frame(width: 5, height: 5)
                    .opacity((hasBooking || isAvailable) ? 1 : 0)
            }
            .frame(width: 44, height: 68)
            .background(cellBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var abbrev: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return String(f.string(from: date).prefix(2)).uppercased()
    }
    private var dayNum: String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
    private var dotColor: Color {
        hasBooking ? Color(hex: "#22C55E") :
        isRecurring ? Color(hex: "#22C55E").opacity(0.7) :
        Color.montraOrange.opacity(0.6)
    }
    private var cellBackground: Color {
        isSelected ? Color.montraOrange :
        isToday ? Color.montraOrange.opacity(0.08) :
        Color.white.opacity(0.05)
    }
    private var borderColor: Color {
        isSelected ? Color.montraOrange :
        isRecurring ? Color(hex: "#22C55E").opacity(0.4) :
        isAvailable ? Color.montraOrange.opacity(0.25) :
        Color.clear
    }
}

// MARK: - Time Slot Button

struct TimeSlotButton: View {
    let slot: BookingSlot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                if slot.isScheduled && !slot.isBooked {
                    Image(systemName: "repeat")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(hex: "#22C55E"))
                }
                Text(slot.timeLabel)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(labelColor)
                Text(slot.isBooked ? "Booked ✓" : slot.isScheduled ? "Recurring" : "Available")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(subColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: slot.isBooked || slot.isScheduled ? 1.5 : 0.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(slot.isBooked || slot.isPast)
        .opacity(slot.isPast ? 0.35 : 1)
    }

    private var labelColor: Color {
        slot.isBooked ? Color(hex: "#22C55E") : .montraTextPrimary
    }
    private var subColor: Color {
        slot.isBooked || slot.isScheduled ? Color(hex: "#22C55E") : .montraTextSecondary
    }
    private var bgColor: Color {
        slot.isBooked ? Color(hex: "#22C55E").opacity(0.1) :
        slot.isScheduled ? Color(hex: "#22C55E").opacity(0.07) :
        Color.white.opacity(0.05)
    }
    private var borderColor: Color {
        slot.isBooked ? Color(hex: "#22C55E") :
        slot.isScheduled ? Color(hex: "#22C55E").opacity(0.45) :
        Color.montraCardBorder
    }
}

// MARK: - Booked Session Row

struct BookedSessionRow: View {
    let session: BookedSession
    let trainerName: String
    let onCancel: () -> Void

    @State private var showCancelConfirm = false

    private var date: Date { session.startDate ?? Date() }

    var body: some View {
        HStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(dayAbbrev)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.montraOrange)
                Text(dayNum)
                    .font(.system(size: 20, weight: .black))
                    .foregroundColor(.montraTextPrimary)
            }
            .frame(width: 46, height: 52)
            .background(Color.montraOrange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(Color.montraOrange.opacity(0.3), lineWidth: 1))

            VStack(alignment: .leading, spacing: 4) {
                Text("Training Session")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.montraTextPrimary)
                HStack(spacing: 10) {
                    Label(timeLabel, systemImage: "clock")
                    Label(trainerName, systemImage: "person.fill")
                }
                .font(.system(size: 12))
                .foregroundColor(.montraTextSecondary)
            }

            Spacer()

            Button { showCancelConfirm = true } label: {
                Image(systemName: "xmark.circle")
                    .font(.system(size: 18))
                    .foregroundColor(.montraTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.07), lineWidth: 0.8))
        .confirmationDialog(
            "Cancel this session?",
            isPresented: $showCancelConfirm,
            titleVisibility: .visible
        ) {
            Button("Cancel Session", role: .destructive, action: onCancel)
            Button("Keep Session", role: .cancel) {}
        }
    }

    private var dayAbbrev: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }
    private var dayNum: String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
    private var timeLabel: String {
        let f = DateFormatter(); f.dateFormat = "h:mm a"; return f.string(from: date)
    }
}

struct SessionItem: Identifiable {
    let id: Int
    let day: String
    let date: Int
    let month: String
    let time: String
    let endTime: String
    let title: String
    let trainer: String
    var trainerId: String? = nil
    let location: String
    var address: String?   = nil
    var focus: String      = "To be confirmed with your trainer"
    var durationMin: Int   = 60
    var level: String      = "To be confirmed"
    var equipment: String  = "To be confirmed with your trainer"
    var calories: String   = "—"
}

struct SessionCard: View {
    let session: SessionItem
    var isNext: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            VStack(spacing: 2) {
                Text(session.month)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.montraOrange)
                Text("\(session.date)")
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.montraTextPrimary)
                Text(session.day)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.montraTextSecondary)
            }
            .frame(width: 56)
            .padding(.vertical, 10)
            .background(isNext ? Color.montraOrange.opacity(0.12) : Color.montraBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                if isNext {
                    Text("NEXT UP")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.montraOrange)
                        .kerning(0.8)
                }
                Text(session.time)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.montraOrange)
                Text(session.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                Text("with \(session.trainer)")
                    .font(.system(size: 13))
                    .foregroundColor(.montraTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.montraTextSecondary)
        }
        .padding(16)
        .background(isNext ? Color.montraOrange.opacity(0.06) : Color.montraSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isNext ? Color.montraOrange.opacity(0.42) : Color.montraCardBorder, lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

#Preview {
    SessionsView(onOpenCoachChat: {})
}
