import SwiftUI

// MARK: - Client Schedules View (Trainer sets recurring schedules per client)

struct ClientSchedulesView: View {
    @Environment(\.dismiss) private var dismiss

    // Storage format: "jessica_r:Monday,Wednesday|9:00 AM;marcus_d:Tuesday,Thursday|10:00 AM"
    @AppStorage("trainerClientSchedules") private var schedulesRaw: String = ""
    // Also write these so SessionsView can read them (demo: represents the "active" client)
    @AppStorage("client.schedule.days") private var clientScheduleDays: String = ""
    @AppStorage("client.schedule.time") private var clientScheduleTime: String = ""

    @State private var expandedClient: String? = nil
    @State private var draftDays: [String: Set<String>] = [:]
    @State private var draftTime: [String: String] = [:]
    @State private var savedClients: Set<String> = []

    private let clients: [(key: String, name: String)] = [
        ("jessica_r", "Jessica R."),
        ("marcus_d",  "Marcus D."),
        ("priya_s",   "Priya S."),
        ("dwayne_k",  "Dwayne K."),
        ("sofia_t",   "Sofia T."),
    ]

    private let allDays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    private let allDaysFull = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
    private let timeOptions = [
        "6:00 AM", "7:00 AM", "8:00 AM", "9:00 AM", "10:00 AM", "11:00 AM",
        "12:00 PM", "1:00 PM", "2:00 PM", "3:00 PM", "4:00 PM", "5:00 PM", "6:00 PM"
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    ForEach(clients, id: \.key) { client in
                        ClientScheduleCard(
                            clientKey: client.key,
                            clientName: client.name,
                            isExpanded: expandedClient == client.key,
                            isSaved: savedClients.contains(client.key),
                            currentDays: draftDays[client.key] ?? [],
                            currentTime: draftTime[client.key] ?? "",
                            allDays: allDays,
                            allDaysFull: allDaysFull,
                            timeOptions: timeOptions,
                            onToggle: {
                                withAnimation(.spring(response: 0.35)) {
                                    expandedClient = (expandedClient == client.key) ? nil : client.key
                                }
                            },
                            onDayToggle: { day in
                                var days = draftDays[client.key] ?? []
                                if days.contains(day) { days.remove(day) } else { days.insert(day) }
                                draftDays[client.key] = days
                                savedClients.remove(client.key)
                            },
                            onTimePick: { time in
                                draftTime[client.key] = time
                                savedClients.remove(client.key)
                            },
                            onSave: { saveSchedule(for: client.key) }
                        )
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
            }
            .background(Color.montraBackground)
            .navigationTitle("Client Schedules")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.montraOrange)
                }
            }
        }
        .onAppear { loadSchedules() }
    }

    // MARK: - Persistence

    private func loadSchedules() {
        guard !schedulesRaw.isEmpty else { return }
        for entry in schedulesRaw.split(separator: ";") {
            let parts = entry.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0])
            let rest = parts[1].split(separator: "|")
            if rest.count >= 1 {
                let days = Set(rest[0].split(separator: ",").map(String.init))
                draftDays[key] = days
            }
            if rest.count >= 2 { draftTime[key] = String(rest[1]) }
            savedClients.insert(key)
        }
    }

    private func saveSchedule(for key: String) {
        let days = draftDays[key] ?? []
        let time = draftTime[key] ?? ""
        guard !days.isEmpty, !time.isEmpty else { return }

        // Update storage
        var schedules: [(String, Set<String>, String)] = []
        // Parse existing
        if !schedulesRaw.isEmpty {
            for entry in schedulesRaw.split(separator: ";") {
                let parts = entry.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { continue }
                let k = String(parts[0])
                guard k != key else { continue } // skip old entry for this client
                let rest = parts[1].split(separator: "|")
                if rest.count >= 2 {
                    schedules.append((k, Set(rest[0].split(separator: ",").map(String.init)), String(rest[1])))
                }
            }
        }
        schedules.append((key, days, time))
        schedulesRaw = schedules.map { "\($0.0):\($0.1.joined(separator: ","))|\($0.2)" }.joined(separator: ";")

        // Simplified demo: the first saved client becomes "the active client" for SessionsView
        let sortedDays = days.sorted { allDaysFull.firstIndex(of: $0) ?? 99 < allDaysFull.firstIndex(of: $1) ?? 99 }
        clientScheduleDays = sortedDays.joined(separator: ",")
        clientScheduleTime = time

        savedClients.insert(key)
        withAnimation { expandedClient = nil }
    }
}

// MARK: - Client Schedule Card

private struct ClientScheduleCard: View {
    let clientKey: String
    let clientName: String
    let isExpanded: Bool
    let isSaved: Bool
    let currentDays: Set<String>
    let currentTime: String
    let allDays: [String]
    let allDaysFull: [String]
    let timeOptions: [String]
    let onToggle: () -> Void
    let onDayToggle: (String) -> Void
    let onTimePick: (String) -> Void
    let onSave: () -> Void

    var summaryText: String {
        guard !currentDays.isEmpty else { return "No schedule set" }
        let dayAbbrevs = currentDays.compactMap { full -> String? in
            guard let idx = ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"]
                .firstIndex(of: full) else { return nil }
            return ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][idx]
        }.joined(separator: " · ")
        return currentTime.isEmpty ? dayAbbrevs : "\(dayAbbrevs)  ·  \(currentTime)"
    }

    var initials: String {
        clientName.components(separatedBy: " ").compactMap { $0.first }.prefix(2).map(String.init).joined()
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button(action: onToggle) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.montraOrange.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Text(initials)
                            .font(.system(size: 14, weight: .black))
                            .foregroundColor(.montraOrange)
                    }
                    .overlay(Circle().stroke(Color.montraOrange.opacity(0.4), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 3) {
                        Text(clientName)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.montraTextPrimary)
                        if isSaved && !currentDays.isEmpty {
                            HStack(spacing: 4) {
                                Circle().fill(Color(hex: "#22C55E")).frame(width: 5, height: 5)
                                Text(summaryText)
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "#22C55E"))
                            }
                        } else {
                            Text(summaryText)
                                .font(.system(size: 11))
                                .foregroundColor(.montraTextSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.montraTextSecondary)
                }
                .padding(16)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(Color.montraCardBorder).padding(.horizontal, 16)

                VStack(alignment: .leading, spacing: 18) {
                    // Day chips
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TRAINING DAYS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.montraTextSecondary)
                            .kerning(1.1)

                        HStack(spacing: 8) {
                            ForEach(Array(zip(allDays, allDaysFull)), id: \.0) { abbrev, full in
                                let selected = currentDays.contains(full)
                                Button {
                                    onDayToggle(full)
                                } label: {
                                    Text(abbrev)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(selected ? .black : .montraTextSecondary)
                                        .frame(width: 36, height: 34)
                                        .background(selected ? Color.montraOrange : Color.white.opacity(0.06))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(selected ? Color.clear : Color.montraCardBorder, lineWidth: 0.8)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Time picker
                    VStack(alignment: .leading, spacing: 10) {
                        Text("SESSION TIME")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.montraTextSecondary)
                            .kerning(1.1)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(timeOptions, id: \.self) { t in
                                    let selected = currentTime == t
                                    Button { onTimePick(t) } label: {
                                        Text(t)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(selected ? .black : .montraTextPrimary)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(selected ? Color.montraOrange : Color.white.opacity(0.06))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(selected ? Color.clear : Color.montraCardBorder, lineWidth: 0.8)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Save button
                    Button(action: onSave) {
                        HStack {
                            Spacer()
                            Text("Save Schedule")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.black)
                            Spacer()
                        }
                        .frame(height: 46)
                        .background(
                            (!currentDays.isEmpty && !currentTime.isEmpty)
                                ? Color.montraOrange
                                : Color.montraOrange.opacity(0.35)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(currentDays.isEmpty || currentTime.isEmpty)
                }
                .padding(16)
            }
        }
        .background(Color.white.opacity(isExpanded ? 0.06 : 0.03))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    isSaved && !isExpanded ? Color(hex: "#22C55E").opacity(0.3) : Color.montraCardBorder,
                    lineWidth: 0.8
                )
        )
    }
}

#Preview {
    ClientSchedulesView()
}
