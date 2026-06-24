import SwiftUI

struct TrainerProgramsView: View {
    @EnvironmentObject private var auth: AuthManager

    @State private var showTrainerMenu = false
    @State private var programs: [Program] = []
    @State private var clients: [(uid: String, name: String)] = []
    @State private var hasLoaded = false
    @State private var loadError: String?

    @State private var editingProgram: Program?   // non-nil = edit; builder also used for create
    @State private var showBuilder = false
    @State private var assigningProgram: Program?

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    TrainerCompactTopBar(
                        title: "Programs",
                        onMenuTap: { showTrainerMenu = true }
                    )

                    Button {
                        editingProgram = nil
                        showBuilder = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("New Program")
                                .font(.system(size: 15, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(.black)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 16)
                        .background(Color.montraOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    if let loadError {
                        Text(loadError)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                    }

                    if hasLoaded && programs.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No programs yet")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.montraTextPrimary)
                            Text("Create a training program, then assign it to any client you've matched with.")
                                .font(.system(size: 13))
                                .foregroundColor(.montraTextSecondary)
                        }
                        .padding(18)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .montraCard(radius: 16)
                    } else if !programs.isEmpty {
                        HStack(spacing: 12) {
                            TrainerStatTile(value: "\(programs.count)", label: "Total\nPrograms", icon: "doc.text.fill", color: .montraOrange)
                            TrainerStatTile(value: "\(clients.count)", label: "Matched\nClients", icon: "person.2.fill", color: Color(hex: "#4CAF50"))
                            TrainerStatTile(value: "\(programs.reduce(0) { $0 + $1.workouts.count })", label: "Total\nWorkouts", icon: "figure.strengthtraining.traditional", color: Color(hex: "#4A90D9"))
                        }

                        SectionHeader(title: "YOUR PROGRAMS")

                        VStack(spacing: 14) {
                            ForEach(programs) { program in
                                TrainerProgramCard(
                                    program: program,
                                    onEdit: { editingProgram = program; showBuilder = true },
                                    onAssign: { assigningProgram = program },
                                    onDelete: { Task { await deleteProgram(program) } }
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
        .sheet(isPresented: $showTrainerMenu) {
            ProfileMenuSheet(isClient: false)
        }
        .sheet(isPresented: $showBuilder) {
            ProgramBuilderSheet(existing: editingProgram) {
                await load()
            }
            .environmentObject(auth)
        }
        .sheet(item: $assigningProgram) { program in
            AssignProgramSheet(program: program, clients: clients)
                .environmentObject(auth)
        }
        .task {
            await load()
        }
    }

    private func load() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }
        do {
            programs = try await ProgramAPI.loadTrainerPrograms(token: tokenResult.token)
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
        await loadClients(token: tokenResult.token)
        hasLoaded = true
    }

    private func loadClients(token: String) async {
        guard let url = MontraAPIConfig.url(for: "/api/trainers/my-matches") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        struct Response: Decodable { let matches: [TrainerMatchRequest] }
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(Response.self, from: data) else { return }

        // De-dupe by clientUid, accepted matches only.
        var seen = Set<String>()
        clients = decoded.matches
            .filter { $0.status == "accepted" }
            .compactMap { match in
                guard !seen.contains(match.clientUid) else { return nil }
                seen.insert(match.clientUid)
                let name = match.clientProfile.firstName.isEmpty ? match.clientEmail : match.clientProfile.firstName
                return (uid: match.clientUid, name: name)
            }
    }

    private func deleteProgram(_ program: Program) async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }
        do {
            try await ProgramAPI.deleteProgram(id: program.id, token: tokenResult.token)
            await load()
        } catch {
            loadError = error.localizedDescription
        }
    }
}

// MARK: - Program Card

struct TrainerProgramCard: View {
    let program: Program
    var onEdit: () -> Void
    var onAssign: () -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Circle()
                    .fill(Color.montraOrange)
                    .frame(width: 10, height: 10)

                Text(program.title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.montraTextPrimary)

                Spacer()

                Menu {
                    Button("Edit Program", action: onEdit)
                    Button("Assign to Client", action: onAssign)
                    Button(role: .destructive, action: onDelete) { Text("Delete") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16))
                        .foregroundColor(.montraTextSecondary)
                        .padding(8)
                }
            }

            if !program.description.isEmpty {
                Text(program.description)
                    .font(.system(size: 13))
                    .foregroundColor(.montraTextSecondary)
                    .lineLimit(2)
            }

            HStack(spacing: 16) {
                Label("\(program.weeks) week\(program.weeks == 1 ? "" : "s")", systemImage: "calendar")
                Label("\(program.workouts.count) workout\(program.workouts.count == 1 ? "" : "s")", systemImage: "figure.run")
                Spacer()
            }
            .font(.system(size: 12))
            .foregroundColor(.montraTextSecondary)
        }
        .padding(16)
        .montraCard(radius: 16)
    }
}

#Preview {
    TrainerProgramsView()
        .environmentObject(AuthManager())
}
