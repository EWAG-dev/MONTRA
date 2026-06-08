import SwiftUI

struct TrainerProgramsView: View {
    @AppStorage("app.liveDataConnected") private var liveDataConnected = false
    @State private var showTrainerMenu = false

    // Sample programs — replaced when Firestore data model is wired up
    private let programs: [TrainerProgram] = [
        TrainerProgram(id: 1, name: "Strength Builder",    description: "Progressive overload program focused on compound lifts.", weeks: 8,  sessionsPerWeek: 3, clientCount: 3, color: Color(hex: "#FF6A00")),
        TrainerProgram(id: 2, name: "HIIT Conditioning",   description: "High-intensity intervals to build cardio and stamina.",    weeks: 6,  sessionsPerWeek: 2, clientCount: 2, color: Color(hex: "#4CAF50")),
        TrainerProgram(id: 3, name: "Mobility Reset",      description: "Restore range of motion, posture, and joint health.",     weeks: 4,  sessionsPerWeek: 2, clientCount: 1, color: Color(hex: "#4A90D9")),
        TrainerProgram(id: 4, name: "Athletic Performance",description: "Sport-specific training to peak physical output.",         weeks: 12, sessionsPerWeek: 4, clientCount: 1, color: Color(hex: "#9B59B6")),
    ]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    TrainerCompactTopBar(
                        title: "Programs",
                        onMenuTap: { showTrainerMenu = true },
                        trailingIcon: "plus"
                    ) {
                        // New program action
                    }

                    if !liveDataConnected {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.montraOrange)
                            Text("Preview data only. Live trainer program data is not connected yet.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.montraTextSecondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // MARK: Stats Row
                    HStack(spacing: 12) {
                        TrainerStatTile(value: "\(programs.count)", label: "Active\nPrograms", icon: "doc.text.fill",    color: .montraOrange)
                        TrainerStatTile(value: "\(programs.reduce(0) { $0 + $1.clientCount })", label: "Clients\nEnrolled", icon: "person.2.fill", color: Color(hex: "#4CAF50"))
                        TrainerStatTile(value: "\(programs.reduce(0) { $0 + $1.sessionsPerWeek * $1.clientCount })", label: "Sessions/\nWeek", icon: "calendar", color: Color(hex: "#4A90D9"))
                    }

                    // MARK: Program Cards
                    SectionHeader(title: "YOUR PROGRAMS")

                    VStack(spacing: 14) {
                        ForEach(programs) { program in
                            TrainerProgramCard(program: program)
                        }
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

// MARK: - Program Card

struct TrainerProgramCard: View {
    let program: TrainerProgram

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                // Color accent dot
                Circle()
                    .fill(program.color)
                    .frame(width: 10, height: 10)

                Text(program.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.montraTextPrimary)

                Spacer()

                Menu {
                    Button("Edit Program") { }
                    Button("Assign Client") { }
                    Button(role: .destructive) { } label: { Text("Delete") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.montraTextSecondary)
                        .padding(8)
                }
            }

            Text(program.description)
                .font(.system(size: 13))
                .foregroundColor(.montraTextSecondary)
                .lineLimit(2)

            HStack(spacing: 16) {
                Label("\(program.weeks) weeks",         systemImage: "calendar")
                Label("\(program.sessionsPerWeek)×/week", systemImage: "repeat")
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "person.2.fill")
                    Text("\(program.clientCount) client\(program.clientCount == 1 ? "" : "s")")
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(program.color)
            }
            .font(.system(size: 12))
            .foregroundColor(.montraTextSecondary)
        }
        .padding(16)
        .montraCard(radius: 16)
    }
}

// MARK: - Data Model

struct TrainerProgram: Identifiable {
    let id: Int
    let name: String
    let description: String
    let weeks: Int
    let sessionsPerWeek: Int
    let clientCount: Int
    let color: Color
}

#Preview {
    TrainerProgramsView()
        .environmentObject(AuthManager())
}
