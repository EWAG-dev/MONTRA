import SwiftUI

struct ProgressProfileView: View {
    let progress: TrainerProgressSnapshot
    @Environment(\.dismiss) private var dismiss

    @AppStorage("progress.currentWeight") private var currentWeight: String = ""
    @AppStorage("progress.startWeight") private var startWeight: String = ""
    @AppStorage("progress.goal.weightLoss") private var weightLossGoal: String = ""
    @AppStorage("progress.goal.strengthWeeklySessions") private var strengthWeeklyTarget: String = "5"
    @AppStorage("progress.goal.enduranceMinutes") private var enduranceMinutesTarget: String = "180"
    @AppStorage("progress.goal.mobilitySessions") private var mobilitySessionsTarget: String = "3"
    @AppStorage("progress.goal.performanceMonthlySessions") private var performanceMonthlyTarget: String = "12"
    @AppStorage("progress.goal.consistencyPercent") private var consistencyPercentTarget: String = "90"
    @AppStorage("progress.selectedGoals") private var selectedGoalsStorage: String = "Build Strength,Improve Endurance"

    @State private var selectedGoals: Set<String> = []

    private let availableGoals: [String] = [
        "Build Strength",
        "Improve Endurance",
        "Weight Loss",
        "Mobility",
        "Athletic Performance",
        "Consistency"
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(title: "TRAINER SYNCED PROGRESS")

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    compactMetricTile(label: "This Week", value: "\(progress.completedSessionsThisWeek) sessions")
                    compactMetricTile(label: "Membership Hours", value: progress.membershipHoursDisplay)
                    compactMetricTile(label: "Weekly Calories", value: progress.weeklyCaloriesDisplay)
                    compactMetricTile(label: "Started", value: progress.membershipStart.formatted(date: .abbreviated, time: .omitted))
                }
                .padding(12)
                .montraCard(radius: 16)

                SectionHeader(title: "UPDATE WEIGHT")

                VStack(alignment: .leading, spacing: 10) {
                    Text("Current Weight (lbs)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.montraTextSecondary)

                    TextField("Enter weight", text: $currentWeight)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color.montraBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(12)
                .montraCard(radius: 16)

                SectionHeader(title: "IDENTIFY YOUR GOALS")

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                    ForEach(availableGoals, id: \.self) { goal in
                        Button {
                            toggleGoal(goal)
                        } label: {
                            HStack {
                                Text(goal)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(selectedGoals.contains(goal) ? .black : .montraTextPrimary)
                                    .lineLimit(1)

                                Spacer(minLength: 6)

                                Image(systemName: selectedGoals.contains(goal) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(selectedGoals.contains(goal) ? .black : .montraTextSecondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                selectedGoals.contains(goal)
                                    ? Color.montraOrange
                                    : Color.montraSurface
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !orderedSelectedGoals.isEmpty {
                    SectionHeader(title: "GOAL TARGETS")

                    VStack(spacing: 12) {
                        ForEach(orderedSelectedGoals, id: \.self) { goal in
                            goalTargetCard(for: goal)
                        }
                    }
                }

                Button {
                    persistGoals()
                    dismiss()
                } label: {
                    Text("Save Goals")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.montraOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.top, 8)

                Spacer(minLength: 90)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .background(Color.montraBackground)
        .navigationTitle("Progress Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.montraBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            loadGoals()
        }
    }

    private func compactMetricTile(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.montraTextSecondary)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.montraTextPrimary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.montraBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var orderedSelectedGoals: [String] {
        availableGoals.filter { selectedGoals.contains($0) }
    }

    @ViewBuilder
    private func goalTargetCard(for goal: String) -> some View {
        switch UserGoalType(rawValue: goal) {
        case .weightLoss:
            VStack(alignment: .leading, spacing: 10) {
                Text("Weight Loss Targets")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)

                targetField(title: "Starting Weight (lbs)", text: $startWeight, keyboard: .decimalPad)
                targetField(title: "Goal Weight (lbs)", text: $weightLossGoal, keyboard: .decimalPad)
            }
            .padding(14)
            .montraCard(radius: 14)

        case .buildStrength:
            VStack(alignment: .leading, spacing: 10) {
                Text("Build Strength Target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)

                targetField(title: "Weekly Session Goal", text: $strengthWeeklyTarget, keyboard: .numberPad)
            }
            .padding(14)
            .montraCard(radius: 14)

        case .improveEndurance:
            VStack(alignment: .leading, spacing: 10) {
                Text("Endurance Target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)

                targetField(title: "Weekly Cardio Minutes", text: $enduranceMinutesTarget, keyboard: .numberPad)
            }
            .padding(14)
            .montraCard(radius: 14)

        case .mobility:
            VStack(alignment: .leading, spacing: 10) {
                Text("Mobility Target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)

                targetField(title: "Weekly Mobility Sessions", text: $mobilitySessionsTarget, keyboard: .numberPad)
            }
            .padding(14)
            .montraCard(radius: 14)

        case .athleticPerformance:
            VStack(alignment: .leading, spacing: 10) {
                Text("Athletic Performance Target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)

                targetField(title: "Monthly Session Goal", text: $performanceMonthlyTarget, keyboard: .numberPad)
            }
            .padding(14)
            .montraCard(radius: 14)

        case .consistency:
            VStack(alignment: .leading, spacing: 10) {
                Text("Consistency Target")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)

                targetField(title: "Attendance Goal (%)", text: $consistencyPercentTarget, keyboard: .numberPad)
            }
            .padding(14)
            .montraCard(radius: 14)

        case .none:
            EmptyView()
        }
    }

    private func targetField(title: String, text: Binding<String>, keyboard: UIKeyboardType) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.montraTextSecondary)

            TextField("Enter value", text: text)
                .keyboardType(keyboard)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.montraTextPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.montraBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func toggleGoal(_ goal: String) {
        if selectedGoals.contains(goal) {
            selectedGoals.remove(goal)
        } else {
            selectedGoals.insert(goal)
        }
    }

    private func loadGoals() {
        let tokens = selectedGoalsStorage
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        selectedGoals = Set(tokens)
    }

    private func persistGoals() {
        let includesWeightLoss = selectedGoals.contains(UserGoalType.weightLoss.rawValue)
        if includesWeightLoss,
           startWeight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           !currentWeight.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            startWeight = currentWeight
        }

        selectedGoalsStorage = availableGoals
            .filter { selectedGoals.contains($0) }
            .joined(separator: ",")
    }
}

#Preview {
    NavigationStack {
        ProgressProfileView(progress: .sample)
    }
}
