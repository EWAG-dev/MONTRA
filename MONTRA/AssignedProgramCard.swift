import SwiftUI

/// Client-facing card showing a program their trainer assigned. Tap to expand the
/// full workout breakdown.
struct AssignedProgramCard: View {
    let program: AssignedProgram
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(program.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.montraTextPrimary)
                            .multilineTextAlignment(.leading)
                        Text("From \(program.trainerName.isEmpty ? "your coach" : program.trainerName)")
                            .font(.system(size: 12))
                            .foregroundColor(.montraTextSecondary)
                        HStack(spacing: 12) {
                            Label("\(program.weeks) week\(program.weeks == 1 ? "" : "s")", systemImage: "calendar")
                            Label("\(program.workouts.count) workout\(program.workouts.count == 1 ? "" : "s")", systemImage: "figure.run")
                        }
                        .font(.system(size: 11))
                        .foregroundColor(.montraTextSecondary)
                    }
                    Spacer()
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.montraOrange)
                        .padding(.top, 2)
                }
            }
            .buttonStyle(.plain)

            if expanded {
                if !program.description.isEmpty {
                    Text(program.description)
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)
                }

                ForEach(program.workouts) { workout in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            if !workout.day.isEmpty {
                                Text(workout.day)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.montraOrange)
                            }
                            Text(workout.title.isEmpty ? "Workout" : workout.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.montraTextPrimary)
                        }

                        ForEach(workout.exercises) { ex in
                            HStack(alignment: .top, spacing: 6) {
                                Text("•").foregroundColor(.montraTextSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.montraTextPrimary)
                                    Text(exerciseDetail(ex))
                                        .font(.system(size: 11))
                                        .foregroundColor(.montraTextSecondary)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.montraBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.montraSurface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func exerciseDetail(_ ex: ProgramExercise) -> String {
        var parts: [String] = []
        if !ex.sets.isEmpty || !ex.reps.isEmpty {
            let sets = ex.sets.isEmpty ? "?" : ex.sets
            let reps = ex.reps.isEmpty ? "?" : ex.reps
            parts.append("\(sets) × \(reps)")
        }
        if !ex.notes.isEmpty { parts.append(ex.notes) }
        return parts.joined(separator: " · ")
    }
}
