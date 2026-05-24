import SwiftUI

// MARK: - Sessions / Booking View

struct SessionsView: View {
    let onOpenCoachChat: () -> Void

    private let cal = Calendar.current

    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var pendingSlot: BookingSlot? = nil
    @State private var showConfirm = false

    @AppStorage("sessions.booked")           private var bookedRaw: String = ""
    @AppStorage("client.schedule.days")      private var scheduleDaysRaw: String = ""
    @AppStorage("client.schedule.time")      private var scheduleTimeRaw: String = ""
    @AppStorage("trainer.availableDays")     private var trainerDaysRaw: String = "Monday,Wednesday,Friday"
    @AppStorage("trainer.availableHours")    private var trainerHoursRaw: String = "9,10,11,12,13,14,15,16"
    @AppStorage("quiz.requestedTrainerName") private var trainerFullName: String = ""

    private var trainerFirstName: String {
        let name = trainerFullName.isEmpty ? "Alex Morgan" : trainerFullName
        return name.components(separatedBy: " ").first ?? "Alex"
    }

    private var trainerDisplayName: String {
        trainerFullName.isEmpty ? "Alex Morgan" : trainerFullName
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
        Set(bookedRaw.split(separator: ",").map(String.init).filter { !$0.isEmpty })
    }

    private var scheduleDays: Set<String> {
        Set(scheduleDaysRaw.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty })
    }

    private var scheduleHour: Int {
        parseHour(scheduleTimeRaw)
    }

    // 14 days starting from Monday of the current week
    private var calendarDays: [Date] {
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today) // 1=Sun..7=Sat
        let daysFromMonday = (weekday - 2 + 7) % 7
        let monday = cal.date(byAdding: .day, value: -daysFromMonday, to: today)!
        return (0..<14).compactMap { cal.date(byAdding: .day, value: $0, to: monday) }
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

    private var upcomingBooked: [(Date, Int)] {
        let today = cal.startOfDay(for: Date())
        return bookedKeys.compactMap { key -> (Date, Int)? in
            let p = key.split(separator: "-")
            guard p.count == 4,
                  let yr = Int(p[0]), let mo = Int(p[1]),
                  let dy = Int(p[2]), let hr = Int(p[3]) else { return nil }
            var c = DateComponents(); c.year = yr; c.month = mo; c.day = dy
            guard let d = cal.date(from: c), d >= today else { return nil }
            return (d, hr)
        }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {

                    // ── Header ────────────────────────────────────────
                    HStack {
                        Text("Book a Session")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.montraTextPrimary)
                        Spacer()
                    }
                    .padding(.top, 8)

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
                            Text("Available \(trainerDaysRaw.components(separatedBy: ",").map { String($0.trimmingCharacters(in: .whitespaces).prefix(3)) }.joined(separator: " · "))")
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
                            ForEach(upcomingBooked.prefix(8), id: \.0) { date, hour in
                                BookedSessionRow(
                                    date: date,
                                    hour: hour,
                                    trainerName: trainerDisplayName
                                )
                            }
                        }
                    }

                    Spacer(minLength: 90)
                }
                .padding(.horizontal, 20)
            }
            .background(Color.montraBackground)
        }
        .confirmationDialog(
            pendingSlot.map { "Book \($0.timeLabel) with \(trainerFirstName)?" } ?? "",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            if let slot = pendingSlot {
                Button("Confirm Booking") { confirmBook(slot) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let slot = pendingSlot {
                Text("\(longDateLabel(slot.date)) · 60 min")
            }
        }
    }

    // MARK: - Helpers

    private func confirmBook(_ slot: BookingSlot) {
        var keys = bookedKeys
        keys.insert(slot.key)
        bookedRaw = keys.joined(separator: ",")
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
        .disabled(slot.isBooked)
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
    let date: Date
    let hour: Int
    let trainerName: String

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

            Text("Confirmed")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(hex: "#22C55E"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(hex: "#22C55E").opacity(0.1))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.07), lineWidth: 0.8))
    }

    private var dayAbbrev: String {
        let f = DateFormatter(); f.dateFormat = "EEE"
        return f.string(from: date).uppercased()
    }
    private var dayNum: String {
        let f = DateFormatter(); f.dateFormat = "d"; return f.string(from: date)
    }
    private var timeLabel: String {
        let h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour)
        return "\(h):00 \(hour >= 12 ? "PM" : "AM")"
    }
}

// MARK: - Supporting structs (kept for SessionDetailView)

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.montraTextSecondary)
            .kerning(1.2)
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
    let location: String
    var address: String?   = nil
    var focus: String      = "Full Body Strength"
    var durationMin: Int   = 60
    var level: String      = "Intermediate"
    var equipment: String  = "Dumbbells, Mat, Bands"
    var calories: String   = "500–600"
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

struct ClassProgram: Identifiable {
    let id: Int; let title: String; let subtitle: String; let focus: String; let duration: String
}

#Preview {
    SessionsView(onOpenCoachChat: {})
}
// MARK: - Legacy ProgramCard (kept for reference)
struct ProgramCard: View {
    let program: ClassProgram

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(program.title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.montraTextPrimary)
            Text(program.subtitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.montraOrange)
            Text(program.focus)
                .font(.system(size: 13))
                .foregroundColor(.montraTextSecondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Text(program.duration)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.montraTextSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.montraBackground)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .padding(14)
        .frame(width: 210, height: 132)
        .montraCard(radius: 14)
    }
}
