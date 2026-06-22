import SwiftUI

struct TrainerProgramsView: View {
    @State private var showTrainerMenu = false

    // No program-builder backend exists yet, so there is nothing real to show here.
    private let programs: [TrainerProgram] = []

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    TrainerCompactTopBar(
                        title: "Programs",
                        onMenuTap: { showTrainerMenu = true }
                    )

                    if programs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No programs yet")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.montraTextPrimary)
                            Text("Program building is coming soon — you'll be able to create and assign training programs to your clients here.")
                                .font(.system(size: 13))
                                .foregroundColor(.montraTextSecondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .montraCard(radius: 16)
                    } else {
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
