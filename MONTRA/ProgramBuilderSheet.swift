import SwiftUI

/// Create or edit a program template. Reused for both flows: pass `existing` to edit.
struct ProgramBuilderSheet: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    let existing: Program?
    let onSaved: () async -> Void

    @State private var title = ""
    @State private var description = ""
    @State private var weeks = 4
    @State private var workouts: [ProgramWorkout] = []
    @State private var saveError: String?
    @State private var isSaving = false

    private var isEditing: Bool { existing != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    field(label: "PROGRAM TITLE") {
                        TextField("e.g. Beginner Strength", text: $title)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.montraBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    field(label: "DESCRIPTION") {
                        TextField("Short summary for your client", text: $description, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(Color.montraBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    field(label: "DURATION") {
                        Stepper("\(weeks) week\(weeks == 1 ? "" : "s")", value: $weeks, in: 1...52)
                            .padding(12)
                            .background(Color.montraBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    HStack {
                        Text("WORKOUTS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.montraTextPrimary)
                            .kerning(0.8)
                        Spacer()
                        Button {
                            workouts.append(ProgramWorkout(day: "Day \(workouts.count + 1)", title: "", exercises: []))
                        } label: {
                            Label("Add", systemImage: "plus.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.montraOrange)
                        }
                    }

                    if workouts.isEmpty {
                        Text("Add at least one workout day to build out the program.")
                            .font(.system(size: 13))
                            .foregroundColor(.montraTextSecondary)
                    }

                    ForEach($workouts) { $workout in
                        workoutEditor($workout)
                    }

                    if let saveError {
                        Text(saveError)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                    }

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(Color.montraBackground.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Program" : "New Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.montraTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSaving ? "Saving…" : "Save") { Task { await save() } }
                        .foregroundColor(.montraOrange)
                        .disabled(isSaving || title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: hydrate)
        }
    }

    @ViewBuilder
    private func workoutEditor(_ workout: Binding<ProgramWorkout>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("Day", text: workout.day)
                    .frame(width: 70)
                    .padding(10)
                    .background(Color.montraSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                TextField("Workout title (e.g. Upper Body)", text: workout.title)
                    .padding(10)
                    .background(Color.montraSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Button(role: .destructive) {
                    workouts.removeAll { $0.id == workout.wrappedValue.id }
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            ForEach(workout.exercises) { $exercise in
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        TextField("Exercise", text: $exercise.name)
                            .padding(8)
                            .background(Color.montraBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        Button(role: .destructive) {
                            workout.wrappedValue.exercises.removeAll { $0.id == exercise.id }
                        } label: {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.montraTextSecondary)
                        }
                    }
                    HStack(spacing: 8) {
                        TextField("Sets", text: $exercise.sets)
                            .padding(8).background(Color.montraBackground).clipShape(RoundedRectangle(cornerRadius: 8))
                        TextField("Reps", text: $exercise.reps)
                            .padding(8).background(Color.montraBackground).clipShape(RoundedRectangle(cornerRadius: 8))
                        TextField("Notes", text: $exercise.notes)
                            .padding(8).background(Color.montraBackground).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Button {
                workout.wrappedValue.exercises.append(ProgramExercise())
            } label: {
                Label("Add Exercise", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.montraOrange)
            }
        }
        .padding(12)
        .montraCard(radius: 12)
    }

    @ViewBuilder
    private func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.montraTextPrimary)
                .kerning(0.8)
            content()
        }
    }

    private func hydrate() {
        guard let existing, title.isEmpty, workouts.isEmpty else { return }
        title = existing.title
        description = existing.description
        weeks = existing.weeks
        workouts = existing.workouts
    }

    private func save() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
            if let existing {
                try await ProgramAPI.updateProgram(id: existing.id, title: trimmedTitle, description: description, weeks: weeks, workouts: workouts, token: tokenResult.token)
            } else {
                try await ProgramAPI.createProgram(title: trimmedTitle, description: description, weeks: weeks, workouts: workouts, token: tokenResult.token)
            }
            await onSaved()
            dismiss()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

/// Pick a matched client to assign the program to.
struct AssignProgramSheet: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    let program: Program
    let clients: [(uid: String, name: String)]

    @State private var assigningUid: String?
    @State private var assignedUids = Set<String>()
    @State private var error: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Assign “\(program.title)” to a client. They'll see it in their Programs.")
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)

                    if clients.isEmpty {
                        Text("No matched clients yet. Once a client matches with you, they'll appear here.")
                            .font(.system(size: 13))
                            .foregroundColor(.montraTextSecondary)
                            .padding(.top, 8)
                    }

                    ForEach(clients, id: \.uid) { client in
                        Button {
                            Task { await assign(to: client.uid) }
                        } label: {
                            HStack {
                                Text(client.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.montraTextPrimary)
                                Spacer()
                                if assigningUid == client.uid {
                                    ProgressView().tint(.montraOrange)
                                } else if assignedUids.contains(client.uid) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.montraTextSecondary)
                                }
                            }
                            .padding(14)
                            .montraCard(radius: 12)
                        }
                        .disabled(assigningUid != nil || assignedUids.contains(client.uid))
                    }

                    if let error {
                        Text(error)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.red)
                    }

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(Color.montraBackground.ignoresSafeArea())
            .navigationTitle("Assign Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.montraOrange)
                }
            }
        }
    }

    private func assign(to uid: String) async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }
        assigningUid = uid
        defer { assigningUid = nil }
        do {
            try await ProgramAPI.assignProgram(id: program.id, clientUid: uid, token: tokenResult.token)
            assignedUids.insert(uid)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}
