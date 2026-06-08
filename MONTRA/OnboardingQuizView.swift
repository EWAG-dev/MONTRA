import SwiftUI

// MARK: - Trainer Model (placeholder — swap with Firestore later)

struct OnboardingTrainer: Identifiable {
    let id: String
    let name: String
    let initials: String
    let certification: String
    let bio: String
    let specialties: [String]
    let locations: [String]
    let gender: String
    let accentHex: String
}

extension OnboardingTrainer {
    static let all: [OnboardingTrainer] = [
        .init(id: "jordan_hayes", name: "Jordan Hayes", initials: "JH",
              certification: "NASM Certified",
              bio: "Specialises in strength-focused programming for all levels. Known for high-energy sessions and detailed form coaching.",
              specialties: ["Build Muscle", "Athletic Performance", "General Fitness"],
              locations: ["Boston, MA", "New York, NY"], gender: "Male", accentHex: "#FF6820"),
        .init(id: "priya_nair", name: "Priya Nair", initials: "PN",
              certification: "ACE Certified",
              bio: "Holistic coach with a focus on sustainable fat loss, mobility, and overall wellness. 8+ years experience.",
              specialties: ["Lose Weight", "Flexibility & Wellness", "General Fitness"],
              locations: ["Boston, MA", "Rhode Island, RI"], gender: "Female", accentHex: "#A855F7"),
        .init(id: "marcus_webb", name: "Marcus Webb", initials: "MW",
              certification: "NSCA Certified",
              bio: "Former competitive boxer turned coach. Brings real combat sports experience to every client's programme.",
              specialties: ["Combat Sports", "Athletic Performance", "Build Muscle"],
              locations: ["New York, NY", "New Jersey, NJ"], gender: "Male", accentHex: "#3B82F6"),
        .init(id: "sofia_chen", name: "Sofia Chen", initials: "SC",
              certification: "ISSA Certified",
              bio: "Yoga-certified movement specialist. Creates plans that balance performance with recovery.",
              specialties: ["Flexibility & Wellness", "General Fitness", "Lose Weight"],
              locations: ["Connecticut, CT", "New Jersey, NJ"], gender: "Female", accentHex: "#10B981"),
        .init(id: "tyler_brooks", name: "Tyler Brooks", initials: "TB",
              certification: "NASM Certified",
              bio: "Data-driven approach to general fitness and weight loss. Clients consistently beat their goals.",
              specialties: ["General Fitness", "Lose Weight", "Athletic Performance"],
              locations: ["Rhode Island, RI", "Connecticut, CT"], gender: "Male", accentHex: "#F59E0B"),
    ]

    static func matched(goal: String, location: String, genderPref: String) -> [OnboardingTrainer] {
        let pool = all.filter { t in
            let goalMatch     = t.specialties.contains(goal) || goal.isEmpty
            let locationMatch = t.locations.contains(location) || location.isEmpty
            let genderMatch: Bool = {
                switch genderPref {
                case "Male coach":   return t.gender == "Male"
                case "Female coach": return t.gender == "Female"
                default:             return true
                }
            }()
            return goalMatch && locationMatch && genderMatch
        }
        return pool.isEmpty ? all : pool
    }
}

// MARK: - Onboarding Quiz

struct OnboardingQuizView: View {
    @EnvironmentObject private var auth: AuthManager
    @AppStorage("app.liveDataConnected") private var liveDataConnected = false

    @AppStorage("onboarding.completed")      private var isCompleted = false
    @AppStorage("onboarding.preAuthActive")  private var preAuthOnboardingActive = false
    @AppStorage("quiz.goal")                 private var savedGoal = ""
    @AppStorage("quiz.experience")           private var savedExperience = ""
    @AppStorage("quiz.location")             private var savedLocation = ""
    @AppStorage("quiz.equipmentAccess")      private var savedEquipmentAccess = ""
    @AppStorage("quiz.injuries")             private var savedInjuries = ""
    @AppStorage("quiz.lifestyleDays")        private var savedLifestyleDays = ""
    @AppStorage("quiz.stressLevel")          private var savedStressLevel = ""
    @AppStorage("quiz.sleepRange")           private var savedSleepRange = ""
    @AppStorage("quiz.nutritionHabits")      private var savedNutritionHabits = ""
    @AppStorage("quiz.nutritionChallenges")  private var savedNutritionChallenges = ""
    @AppStorage("quiz.why")                  private var savedWhy = ""
    @AppStorage("quiz.accountability")       private var savedAccountability = ""
    @AppStorage("quiz.communicationStyle")   private var savedCommunicationStyle = ""
    @AppStorage("quiz.commitmentReadiness")  private var savedCommitmentReadiness = ""
    @AppStorage("quiz.schedule")             private var savedSchedule = ""
    @AppStorage("quiz.frequency")            private var savedFrequency = ""
    @AppStorage("quiz.coachPreference")      private var savedCoachPref = ""
    @AppStorage("quiz.firstName")            private var savedFirstName = ""
    @AppStorage("quiz.requestedTrainer")     private var requestedTrainerId = ""
    @AppStorage("quiz.requestedTrainerName") private var requestedTrainerName = ""
    @AppStorage("quiz.matchChecklistShown")  private var matchChecklistShown = false

    @State private var step = 1
    @State private var forward = true
    @State private var selectedSchedule: Set<String> = []
    @State private var firstName = ""
    @State private var selectedTrainer: OnboardingTrainer? = nil
    @State private var selectedLocation = ""
    @State private var selectedEquipment = ""
    @State private var selectedInjuries: Set<String> = []
    @State private var selectedLifestyleDays = ""
    @State private var selectedStressLevel = ""
    @State private var selectedSleepRange = ""
    @State private var selectedNutritionHabits = ""
    @State private var selectedNutritionChallenges: Set<String> = []
    @State private var selectedWhyBarriers: Set<String> = []
    @State private var selectedAccountability = ""
    @State private var selectedCommunicationStyle = ""
    @State private var selectedCommitmentReadiness = ""
    @State private var accountEmail = ""
    @State private var accountPassword = ""
    @State private var accountConfirmPassword = ""
    @State private var accountLoading = false
    @State private var accountError: String? = nil
    @State private var walkthroughPage = 0
    @State private var showMatchChecklist = false
    @State private var checklistCompletedCount = 0
    @State private var checklistRunning = false

    private let quizSteps = 13
    private let resultsStep = 14
    private let confirmationStepIndex = 15
    private let walkthroughStepIndex = 16
    private var matchChecklistPhases: [(title: String, subtitle: String)] {
        [
            ("Saving your quiz answers", "Goal, schedule, location, and preferences"),
            (
                "Loading trainer profiles",
                liveDataConnected
                    ? "From the Elite Home Fitness trainer network"
                    : "Using the current preview dataset"
            ),
            ("Applying your filters", "Goal, location, and coach preference"),
            ("Preparing your options", "Finalizing your trainer list")
        ]
    }

    var body: some View {
        ZStack {
            Color.montraBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Header
                VStack(spacing: 12) {
                    HStack {
                        Text(step <= quizSteps ? "MONTRA QUIZ" : "MONTRA")
                            .font(.system(size: 11, weight: .black))
                            .kerning(1.8)
                            .foregroundColor(.montraOrange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.montraOrange.opacity(0.12))
                            .clipShape(Capsule())
                        Spacer()
                        HStack(spacing: 12) {
                            if step <= quizSteps {
                                Text("13 STEPS")
                                    .font(.system(size: 11, weight: .black))
                                    .kerning(1.2)
                                    .foregroundColor(.montraTextSecondary)
                            }

                            if canCloseQuiz {
                                Button(action: closeQuiz) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.montraTextSecondary)
                                        .frame(width: 28, height: 28)
                                        .background(Color.white.opacity(0.06))
                                        .clipShape(Circle())
                                }
                                .accessibilityLabel("Close quiz")
                            }
                        }
                    }

                    HStack {
                        if step > 1 && step <= walkthroughStepIndex {
                            Button { advance(by: -1) } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.montraTextSecondary)
                            }
                        } else {
                            Spacer().frame(width: 24)
                        }

                        Spacer()

                        if step <= quizSteps {
                            Text("Step \(step) of \(quizSteps)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.montraTextSecondary)
                                .kerning(0.5)
                        } else if step == resultsStep {
                            Text("Your matches")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.montraTextSecondary)
                                .kerning(0.5)
                        } else if step == walkthroughStepIndex {
                            Text("App walkthrough")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.montraTextSecondary)
                                .kerning(0.5)
                        } else {
                            Text("Final steps")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.montraTextSecondary)
                                .kerning(0.5)
                        }

                        Spacer()

                        HStack(spacing: 12) {
                            if step == 11 {
                                Button("Skip") { completeStep(value: "No preference") }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.montraTextSecondary)
                            }
                        }
                        .frame(minWidth: 40, alignment: .trailing)
                    }

                    if step <= quizSteps {
                        HStack(spacing: 6) {
                            ForEach(1...quizSteps, id: \.self) { index in
                                Capsule()
                                    .fill(index <= step ? Color.montraOrange : Color.white.opacity(0.12))
                                    .frame(height: 6)
                            }
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.montraOrange)
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
                .padding(.bottom, 28)

                // MARK: Step Content
                ZStack {
                    stepContent
                        .id(step)
                        .transition(.asymmetric(
                            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                            removal:   .move(edge: forward ? .leading  : .trailing).combined(with: .opacity)
                        ))
                }
                .animation(.easeInOut(duration: 0.28), value: step)
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 1: goalStep
        case 2: lifestyleHabitsStep
        case 3: experienceStep
        case 4: nutritionHabitsStep
        case 5: yourWhyStep
        case 6: locationStep
        case 7: healthSafetyStep
        case 8: accountabilityStep
        case 9: scheduleStep
        case 10: commitmentStep
        case 11: coachPrefStep
        case 12: nameStep
        case 13: accountGateStep
        case 14: trainerMatchStep
        case 15: confirmationStep
        case 16: appWalkthroughStep
        default: confirmationStep
        }
    }

    // MARK: Step 1 — Goal

    private var goalStep: some View {
        QuizStepShell(stepNumber: 1,
                      title: "Main goal",
                      subtitle: "Choose the result that matters most right now.") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(goalOptions, id: \.label) { opt in
                    GridOptionCard(option: opt, isSelected: savedGoal == opt.label) { completeStep(value: opt.label) }
                }
            }
        }
    }

    // MARK: Step 2 - Lifestyle & Habits

    private var lifestyleHabitsStep: some View {
        QuizStepShell(stepNumber: 2,
                      title: "Lifestyle & habits",
                      subtitle: "Help us understand your daily routine.") {
            VStack(spacing: 18) {
                QuizQuestionCard(icon: "calendar", title: "How many days per week can you realistically commit?", subtitle: "Choose one") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(daysPerWeekOptions, id: \.title) { option in
                            MiniChoiceCard(title: option.title, subtitle: option.subtitle, accent: .montraOrange, selected: selectedLifestyleDays == option.title) {
                                selectedLifestyleDays = option.title
                            }
                        }
                    }
                }

                QuizQuestionCard(icon: "waveform.path.ecg", title: "Stress level?", subtitle: "Choose one") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(stressOptions, id: \.title) { option in
                            MoodChoiceCard(title: option.title, emoji: option.emoji, accent: option.color, selected: selectedStressLevel == option.title) {
                                selectedStressLevel = option.title
                            }
                        }
                    }
                }

                QuizQuestionCard(icon: "moon.stars", title: "Average sleep per night?", subtitle: "Choose one") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(sleepOptions, id: \.title) { option in
                            MiniChoiceCard(title: option.title, subtitle: nil, accent: .purple, selected: selectedSleepRange == option.title) {
                                selectedSleepRange = option.title
                            }
                        }
                    }
                }

                continueButton(enabled: !selectedLifestyleDays.isEmpty && !selectedStressLevel.isEmpty && !selectedSleepRange.isEmpty, title: "Next") {
                    savedLifestyleDays = selectedLifestyleDays
                    savedStressLevel = selectedStressLevel
                    savedSleepRange = selectedSleepRange
                    advance(by: 1)
                }
            }
        }
    }

    // MARK: Step 3 — Experience

    private var experienceStep: some View {
        QuizStepShell(stepNumber: 3,
                      title: "Training experience",
                      subtitle: "This helps us find the right coaching style for you.") {
            VStack(spacing: 10) {
                ForEach(experienceOptions, id: \.label) { opt in
                    RowOptionCard(option: opt, isSelected: savedExperience == opt.label) { completeStep(value: opt.label) }
                }
            }
        }
    }

    // MARK: Step 4 - Nutrition & Habits

    private var nutritionHabitsStep: some View {
        QuizStepShell(stepNumber: 4,
                      title: "Nutrition & habits",
                      subtitle: "Help us understand your biggest challenges and habits.") {
            VStack(spacing: 18) {
                QuizQuestionCard(icon: "target", title: "What's your biggest struggle right now?", subtitle: "Choose up to 2") {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 10) {
                        ForEach(nutritionChallengeOptions, id: \.title) { option in
                            MultiSelectCard(title: option.title, icon: option.icon, accent: option.color, selected: selectedNutritionChallenges.contains(option.title)) {
                                toggleSelection(option.title, in: &selectedNutritionChallenges, max: 2)
                            }
                        }
                    }
                }

                QuizQuestionCard(icon: "fork.knife", title: "How would you describe your nutrition habits?", subtitle: "Choose one") {
                    HStack(spacing: 10) {
                        ForEach(nutritionHabitOptions, id: \.title) { option in
                            MoodChoiceCard(title: option.title, icon: option.icon, accent: option.color, selected: selectedNutritionHabits == option.title) {
                                selectedNutritionHabits = option.title
                            }
                        }
                    }
                }

                continueButton(enabled: !selectedNutritionHabits.isEmpty, title: "Next") {
                    savedNutritionHabits = selectedNutritionHabits
                    savedNutritionChallenges = selectedNutritionChallenges.sorted().joined(separator: ", ")
                    advance(by: 1)
                }
            }
        }
    }

    // MARK: Step 5 - Your Why

    private var yourWhyStep: some View {
        QuizStepShell(stepNumber: 5,
                      title: "Your why",
                      subtitle: "Why is this important to you right now?") {
            VStack(spacing: 18) {
                QuizInfoBanner(icon: "target", text: "Your answer helps us keep you motivated and accountable.")

                QuizQuestionCard(icon: nil, title: "What has stopped you from staying consistent in the past?", subtitle: "Select all that apply.") {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 10) {
                        ForEach(whyBarrierOptions, id: \.title) { option in
                            MultiSelectCard(title: option.title, icon: option.icon, accent: option.color, selected: selectedWhyBarriers.contains(option.title)) {
                                toggleSelection(option.title, in: &selectedWhyBarriers)
                            }
                        }
                    }
                }

                continueButton(enabled: !selectedWhyBarriers.isEmpty, title: "Next") {
                    savedWhy = selectedWhyBarriers.sorted().joined(separator: ", ")
                    advance(by: 1)
                }
            }
        }
    }

    // MARK: Step 6 - Location & Equipment

    private var locationStep: some View {
        QuizStepShell(stepNumber: 6,
                      title: "Training location",
                      subtitle: "Where would you like to train?") {
            VStack(alignment: .leading, spacing: 14) {
                QuizQuestionCard(icon: "mappin.and.ellipse", title: "Training location", subtitle: "Choose one") {
                ForEach(locationOptions, id: \.self) { loc in
                    selectionRow(title: loc, selected: selectedLocation == loc) {
                        selectedLocation = loc
                    }
                }
                }

                QuizQuestionCard(icon: "dumbbell", title: "Equipment access", subtitle: "Choose one") {
                ForEach(equipmentOptions, id: \.self) { equipment in
                    selectionRow(title: equipment, selected: selectedEquipment == equipment) {
                        selectedEquipment = equipment
                    }
                }
                }

                continueButton(enabled: !selectedLocation.isEmpty && !selectedEquipment.isEmpty, title: "Next") {
                    savedLocation = selectedLocation
                    savedEquipmentAccess = selectedEquipment
                    advance(by: 1)
                }
            }
        }
    }

    // MARK: Step 7 - Health & Safety

    private var healthSafetyStep: some View {
        QuizStepShell(stepNumber: 7,
                      title: "Health & safety",
                      subtitle: "Your safety is our priority.") {
            VStack(spacing: 18) {
                QuizQuestionCard(icon: "heart.text.square", title: "Do you currently have or have you ever had:", subtitle: nil) {
                    LazyVGrid(columns: [GridItem(.flexible())], spacing: 10) {
                        ForEach(injuryOptions, id: \.self) { injury in
                            MultiSelectCard(title: injury, icon: "cross.case", accent: injury == "None" ? .gray : .montraOrange, selected: selectedInjuries.contains(injury)) {
                                if injury == "None" {
                                    selectedInjuries = ["None"]
                                } else {
                                    selectedInjuries.remove("None")
                                    toggleSelection(injury, in: &selectedInjuries)
                                }
                            }
                        }
                    }
                }

                continueButton(enabled: true, title: "Next") {
                    savedInjuries = selectedInjuries.isEmpty ? "None" : selectedInjuries.sorted().joined(separator: ", ")
                    advance(by: 1)
                }
            }
        }
    }

    // MARK: Step 8 - Accountability

    private var accountabilityStep: some View {
        QuizStepShell(stepNumber: 8,
                      title: "Accountability & communication",
                      subtitle: "How hands-on should your coach be?") {
            VStack(spacing: 18) {
                QuizQuestionCard(icon: "person.2", title: "How much accountability do you want?", subtitle: "Choose one") {
                    VStack(spacing: 10) {
                        ForEach(accountabilityOptions, id: \.label) { option in
                            selectionRow(title: option.label + "\n" + option.subtitle, selected: selectedAccountability == option.label) {
                                selectedAccountability = option.label
                            }
                        }
                    }
                }

                QuizQuestionCard(icon: "ellipsis.bubble", title: "How do you prefer your coach communicates?", subtitle: "Choose one") {
                    VStack(spacing: 10) {
                        ForEach(communicationOptions, id: \.label) { option in
                            selectionRow(title: option.label + "\n" + option.subtitle, selected: selectedCommunicationStyle == option.label) {
                                selectedCommunicationStyle = option.label
                            }
                        }
                    }
                }

                continueButton(enabled: !selectedAccountability.isEmpty && !selectedCommunicationStyle.isEmpty, title: "Next") {
                    savedAccountability = selectedAccountability
                    savedCommunicationStyle = selectedCommunicationStyle
                    advance(by: 1)
                }
            }
        }
    }

    // MARK: Step 9 — Schedule (multi-select)

    private var scheduleStep: some View {
        QuizStepShell(stepNumber: 9,
                      title: "Schedule & routine",
                      subtitle: "When do you want to train?") {
            VStack(spacing: 14) {
                QuizQuestionCard(icon: "clock", title: "What training times work best?", subtitle: "Select all that apply") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(scheduleOptions, id: \.label) { opt in
                            GridOptionCard(option: opt, isSelected: selectedSchedule.contains(opt.label)) {
                                toggleSelection(opt.label, in: &selectedSchedule)
                            }
                        }
                    }
                }

                continueButton(enabled: !selectedSchedule.isEmpty, title: "Next") {
                    savedSchedule = selectedSchedule.sorted().joined(separator: ", ")
                    advance(by: 1)
                }
            }
        }
    }

    // MARK: Step 10 - Commitment

    private var commitmentStep: some View {
        QuizStepShell(stepNumber: 10,
                      title: "Commitment readiness & agreements",
                      subtitle: "Let's make sure we're the right fit to help you succeed.") {
            VStack(spacing: 18) {
                QuizQuestionCard(icon: "target", title: "How ready are you to commit to your goals?", subtitle: "Choose one") {
                    VStack(spacing: 10) {
                        ForEach(commitmentOptions, id: \.label) { option in
                            selectionRow(title: option.label + "\n" + option.subtitle, selected: selectedCommitmentReadiness == option.label) {
                                selectedCommitmentReadiness = option.label
                            }
                        }
                    }
                }

                QuizQuestionCard(icon: "doc.text", title: "Please review and agree to continue.", subtitle: "You must agree to all items below.") {
                    VStack(spacing: 0) {
                        ForEach(agreementItems, id: \.self) { item in
                            HStack {
                                Image(systemName: "checkmark.square.fill")
                                    .foregroundColor(.green)
                                Text(item)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.montraTextPrimary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.montraTextSecondary)
                            }
                            .padding(.vertical, 12)
                            if item != agreementItems.last {
                                Divider().background(Color.montraDivider)
                            }
                        }
                    }
                }

                QuizInfoBanner(icon: "lock", text: "Your information is secure and always private.")

                continueButton(enabled: !selectedCommitmentReadiness.isEmpty, title: "Next") {
                    savedCommitmentReadiness = selectedCommitmentReadiness
                    advance(by: 1)
                }
            }
        }
    }

    // MARK: Step 11 — Coach Preference (skippable)

    private var coachPrefStep: some View {
        QuizStepShell(stepNumber: 11,
                      title: "Coach preference",
                      subtitle: "Totally optional — skip if you don't mind.") {
            VStack(spacing: 10) {
                ForEach(coachPrefOptions, id: \.label) { opt in
                    RowOptionCard(option: opt, isSelected: savedCoachPref == opt.label) { completeStep(value: opt.label) }
                }
            }
        }
    }

    // MARK: Step 12 — Name

    private var nameStep: some View {
        QuizStepShell(stepNumber: 12,
                      title: "What should we call you?",
                      subtitle: "We'll personalise your experience.") {
            VStack(spacing: 16) {
                TextField("First name", text: $firstName)
                    .font(.system(size: 17))
                    .foregroundColor(.montraTextPrimary)
                    .padding(16)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.montraCardBorder, lineWidth: 0.8))
                    .autocorrectionDisabled()

                Button {
                    let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    savedFirstName = trimmed
                    advance(by: 1)
                } label: {
                    let canContinue = !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    Text("Find My Coach")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(canContinue ? .black : .montraTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canContinue ? Color.montraOrange : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: Step 8 — Trainer Matches

    private var trainerMatchStep: some View {
        let matches = OnboardingTrainer.matched(
            goal: savedGoal,
            location: savedLocation,
            genderPref: savedCoachPref
        )
        return Group {
            if auth.user == nil {
                accountGateStep
            } else if showMatchChecklist {
                MatchChecklistIntroView(
                    completedCount: checklistCompletedCount,
                    phases: matchChecklistPhases,
                    liveDataConnected: liveDataConnected
                )
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Here are your\nmatches, \(savedFirstName.isEmpty ? "there" : savedFirstName).")
                                .font(.system(size: 30, weight: .black))
                                .foregroundColor(.montraTextPrimary)
                            Text(
                                liveDataConnected
                                    ? "Select a coach from the Elite Home Fitness trainer network to send your request."
                                    : "Select a coach from this preview list to send your request."
                            )
                                .font(.system(size: 14))
                                .foregroundColor(.montraTextSecondary)
                        }

                        VStack(spacing: 14) {
                            ForEach(matches) { trainer in
                                TrainerMatchCard(
                                    trainer: trainer,
                                    isSelected: selectedTrainer?.id == trainer.id
                                ) {
                                    withAnimation(.easeInOut(duration: 0.18)) { selectedTrainer = trainer }
                                }
                            }
                        }

                        Button {
                            guard let t = selectedTrainer else { return }
                            requestedTrainerId   = t.id
                            requestedTrainerName = t.name
                            advance(by: 1)
                        } label: {
                            let firstName = selectedTrainer?.name.components(separatedBy: " ").first ?? "Coach"
                            Text(selectedTrainer == nil ? "Select a coach first" : "Request \(firstName)")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(selectedTrainer == nil ? .montraTextSecondary : .black)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(selectedTrainer == nil ? Color.white.opacity(0.08) : Color.montraOrange)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .animation(.easeInOut(duration: 0.2), value: selectedTrainer?.id)
                        }
                        .disabled(selectedTrainer == nil)

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                }
            }
        }
        .onAppear {
            startMatchChecklistIfNeeded()
        }
    }

    private var accountGateStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Create your account")
                    .font(.system(size: 30, weight: .black))
                    .foregroundColor(.montraTextPrimary)
                Text("Set up email and password to view your trainer matches.")
                    .font(.system(size: 14))
                    .foregroundColor(.montraTextSecondary)

                MontraInputField(placeholder: "Email address", text: $accountEmail, keyboardType: .emailAddress, isSecure: false)
                MontraInputField(placeholder: "Password", text: $accountPassword, keyboardType: .default, isSecure: true)
                MontraInputField(placeholder: "Confirm password", text: $accountConfirmPassword, keyboardType: .default, isSecure: true)

                if let accountError {
                    Text(accountError)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red)
                }

                Button {
                    Task { await createAccountForResults() }
                } label: {
                    ZStack {
                        if accountLoading {
                            ProgressView().tint(.black)
                        } else {
                            Text("Create Account & View Matches")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.montraOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(accountLoading)

                Button {
                    Task { await signInForResults() }
                } label: {
                    Text("Already have an account? Sign in")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.montraTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .disabled(accountLoading)

                Spacer(minLength: 20)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
    }

    // MARK: Confirmation Step

    private var confirmationStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 40)

                ZStack {
                    Circle()
                        .stroke(Color.montraOrange.opacity(0.2), lineWidth: 2)
                        .frame(width: 96, height: 96)
                    Circle()
                        .stroke(Color.montraOrange.opacity(0.5), lineWidth: 1.5)
                        .frame(width: 76, height: 76)
                    Image(systemName: "clock.fill")
                        .font(.system(size: 30))
                        .foregroundColor(Color.montraOrange)
                }

                VStack(spacing: 8) {
                    Text("Request sent!")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.montraTextPrimary)
                    Text("\(requestedTrainerName) will confirm\nwithin 24 hours.")
                        .font(.system(size: 15))
                        .foregroundColor(.montraTextSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SummaryRow(label: "Coach",      value: requestedTrainerName)
                    SummaryRow(label: "Goal",       value: savedGoal)
                    SummaryRow(label: "Experience", value: savedExperience)
                    SummaryRow(label: "Location",   value: savedLocation)
                    SummaryRow(label: "Schedule",   value: savedSchedule)
                    SummaryRow(label: "Days/Week",  value: savedLifestyleDays)
                }
                .padding(18)
                .montraCard(radius: 16)
                .padding(.horizontal, 24)

                Button { advance(by: 1) } label: {
                    Text("Go to my dashboard")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.montraOrange)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
        }
    }

    private var appWalkthroughStep: some View {
        let pages: [(title: String, subtitle: String)] = [
            ("Dashboard", "Track your sessions, notifications, and important updates in one place."),
            ("Sessions & Messages", "Book sessions and stay connected with your trainer."),
            ("Progress", "Review workouts, nutrition guidance, and milestone wins.")
        ]

        return VStack(alignment: .leading, spacing: 20) {
            Text("Quick app walkthrough")
                .font(.system(size: 30, weight: .black))
                .foregroundColor(.montraTextPrimary)

            Text(pages[walkthroughPage].title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.montraTextPrimary)
            Text(pages[walkthroughPage].subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.montraTextSecondary)

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == walkthroughPage ? Color.montraOrange : Color.white.opacity(0.2))
                        .frame(width: index == walkthroughPage ? 30 : 10, height: 8)
                }
            }

            Spacer()

            Button {
                if walkthroughPage < pages.count - 1 {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        walkthroughPage += 1
                    }
                } else {
                    preAuthOnboardingActive = false
                    isCompleted = true
                }
            } label: {
                Text(walkthroughPage < pages.count - 1 ? "Next" : "Finish")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.montraOrange)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }

    // MARK: - Helpers

    private func completeStep(value: String) {
        switch step {
        case 1: savedGoal = value
        case 3: savedExperience = value
        case 11: savedCoachPref = value
        default: break
        }
        advance(by: 1)
    }

    private func advance(by delta: Int) {
        forward = delta > 0
        withAnimation { step = max(1, step + delta) }
    }

    private var canCloseQuiz: Bool {
        preAuthOnboardingActive || ((auth.user != nil || auth.demoRole != nil) && !isCompleted)
    }

    private func closeQuiz() {
        if preAuthOnboardingActive {
            preAuthOnboardingActive = false
            return
        }

        if auth.user != nil || auth.demoRole != nil {
            isCompleted = true
        }
    }

    private func startMatchChecklistIfNeeded() {
        guard step == resultsStep,
              auth.user != nil,
              !matchChecklistShown,
              !checklistRunning
        else { return }

        checklistRunning = true
        showMatchChecklist = true
        checklistCompletedCount = 0

        for index in matchChecklistPhases.indices {
            let delay = 0.45 + (Double(index) * 0.5)
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: 0.22)) {
                    checklistCompletedCount = index + 1
                }
            }
        }

        let totalDelay = 0.45 + (Double(matchChecklistPhases.count) * 0.5) + 0.4
        DispatchQueue.main.asyncAfter(deadline: .now() + totalDelay) {
            withAnimation(.easeInOut(duration: 0.25)) {
                showMatchChecklist = false
            }
            matchChecklistShown = true
            checklistRunning = false
        }
    }

    private func createAccountForResults() async {
        accountError = nil
        let email = accountEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !email.isEmpty, !accountPassword.isEmpty else {
            accountError = "Please enter email and password."
            return
        }
        guard accountPassword == accountConfirmPassword else {
            accountError = "Passwords do not match."
            return
        }
        guard accountPassword.count >= 6 else {
            accountError = "Password must be at least 6 characters."
            return
        }

        accountLoading = true
        defer { accountLoading = false }

        do {
            try await auth.createAccount(email: email, password: accountPassword)
            advance(by: 1)
        } catch {
            accountError = "Account creation failed. If you already have an account, use Sign in below."
        }
    }

    private func signInForResults() async {
        accountError = nil
        let email = accountEmail.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !email.isEmpty, !accountPassword.isEmpty else {
            accountError = "Please enter email and password."
            return
        }

        accountLoading = true
        defer { accountLoading = false }

        do {
            try await auth.signIn(email: email, password: accountPassword)
            advance(by: 1)
        } catch {
            accountError = "Could not sign in. Check your credentials and try again."
        }
    }

    private func selectionRow(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selected ? .montraOrange : .montraTextSecondary)
            }
            .padding(16)
            .background(selected ? Color.montraOrange.opacity(0.12) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? Color.montraOrange : Color.montraCardBorder, lineWidth: 1)
            )
        }
    }

    private func continueButton(enabled: Bool, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(enabled ? .black : .montraTextSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(enabled ? Color.montraOrange : Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!enabled)
    }

    private func toggleSelection<T: Hashable>(_ value: T, in set: inout Set<T>, max: Int? = nil) {
        if set.contains(value) {
            set.remove(value)
            return
        }
        if let max, set.count >= max {
            return
        }
        set.insert(value)
    }

    // MARK: - Option Data

    private let goalOptions: [QuizOption] = [
        .init(emoji: "💪", label: "Build Muscle",           subtitle: "Strength & size"),
        .init(emoji: "🔥", label: "Lose Weight",            subtitle: "Fat loss & tone"),
        .init(emoji: "🧘", label: "Flexibility & Wellness", subtitle: "Yoga, pilates, mobility"),
        .init(emoji: "🏃", label: "Athletic Performance",   subtitle: "Speed, power, sport"),
        .init(emoji: "🥊", label: "Combat Sports",          subtitle: "Boxing, kickboxing"),
        .init(emoji: "✨", label: "General Fitness",         subtitle: "Stay active & healthy"),
    ]

    private let experienceOptions: [QuizOption] = [
        .init(emoji: "🌱", label: "Beginner",     subtitle: "New to working out or returning after a long break"),
        .init(emoji: "⚡", label: "Intermediate", subtitle: "Work out regularly but want to level up"),
        .init(emoji: "🏆", label: "Advanced",     subtitle: "Experienced athlete or competitor"),
    ]

    private let daysPerWeekOptions: [(title: String, subtitle: String)] = [
        ("1x", "1 day"), ("2x", "2 days"), ("3x", "3 days"), ("4x", "4 days"), ("5+", "5 or more days")
    ]

    private let stressOptions: [(title: String, emoji: String, color: Color)] = [
        ("Low", "🙂", .green), ("Med", "😐", .orange), ("High", "😣", .red)
    ]

    private let sleepOptions: [(title: String, subtitle: String?)] = [
        ("Under 5 hrs", nil), ("5 – 6 hrs", nil), ("6 – 8 hrs", nil)
    ]

    private let nutritionChallengeOptions: [(title: String, icon: String, color: Color)] = [
        ("Consistency", "dumbbell.fill", .orange),
        ("Motivation", "brain.head.profile", .green),
        ("Nutrition", "takeoutbag.and.cup.and.straw.fill", .blue),
        ("Time Management", "clock", .purple),
        ("Confidence", "star", .yellow),
        ("Recovery", "arrow.clockwise", .pink),
        ("Knowing What To Do", "map", .cyan)
    ]

    private let nutritionHabitOptions: [(title: String, icon: String, color: Color)] = [
        ("Excellent", "face.smiling", .green),
        ("Good", "face.smiling.inverse", .orange),
        ("Needs Improvement", "face.dashed", .red)
    ]

    private let whyBarrierOptions: [(title: String, icon: String, color: Color)] = [
        ("Lack of Motivation", "face.dashed", .red),
        ("Busy Schedule", "calendar", .green),
        ("Mental Stress", "brain", .yellow),
        ("Lack of Accountability", "person", .blue),
        ("Injuries or Pain", "figure.run", .purple),
        ("Not Knowing What To Do", "dumbbell.fill", .pink),
        ("Low Energy", "battery.25", .mint),
        ("Nutrition Challenges", "fork.knife", .orange)
    ]

    private let locationOptions = [
        "Boston, MA", "New York, NY", "New Jersey, NJ", "Rhode Island, RI", "Connecticut, CT"
    ]

    private let equipmentOptions = [
        "Full Gym", "Dumbbells", "Resistance Bands", "Minimal Equipment", "No Equipment"
    ]

    private let injuryOptions = [
        "Heart Condition", "High Blood Pressure", "Diabetes", "Joint Pain/Injury",
        "Back Pain", "Pregnancy/Postpartum", "Surgery/Injury History", "None"
    ]

    private let scheduleOptions: [QuizOption] = [
        .init(emoji: "🌅", label: "Early Morning", subtitle: "Before 9am"),
        .init(emoji: "☀️",  label: "Morning",       subtitle: "9am – 12pm"),
        .init(emoji: "🕐", label: "Afternoon",     subtitle: "12pm – 5pm"),
        .init(emoji: "🌆", label: "Evening",       subtitle: "After 5pm"),
    ]

    private let frequencyOptions: [QuizOption] = [
        .init(emoji: nil, label: "1 session per week",    subtitle: "Light commitment to get started"),
        .init(emoji: nil, label: "2–3 sessions per week", subtitle: "Most popular — solid, steady progress"),
        .init(emoji: nil, label: "4–5 sessions per week", subtitle: "High intensity, serious results"),
        .init(emoji: nil, label: "I'm flexible",          subtitle: "Show me all available coaches"),
    ]

    private let coachPrefOptions: [QuizOption] = [
        .init(emoji: nil, label: "Male coach",    subtitle: nil),
        .init(emoji: nil, label: "Female coach",  subtitle: nil),
        .init(emoji: nil, label: "No preference", subtitle: "Show me the best match regardless"),
    ]

    private let accountabilityOptions: [(label: String, subtitle: String)] = [
        ("Light Guidance", "I prefer minimal check-ins"),
        ("Moderate Accountability", "Regular check-ins help"),
        ("High Accountability", "I want frequent check-ins and push")
    ]

    private let communicationOptions: [(label: String, subtitle: String)] = [
        ("Motivational", "Inspire and energize me"),
        ("Direct & Challenging", "Push me to be my best"),
        ("Supportive & Encouraging", "Positive and reassuring"),
        ("Educational & Detailed", "Teach me and explain")
    ]

    private let commitmentOptions: [(label: String, subtitle: String)] = [
        ("Just Exploring", "Learning and exploring my options"),
        ("Ready To Get Started", "I'm ready to take action"),
        ("Fully Committed", "I'm all in and ready for change")
    ]

    private let agreementItems = [
        "Liability Waiver",
        "Terms of Service",
        "Privacy Policy",
        "AI Matching Disclosure"
    ]
}

// MARK: - Trainer Match Card

struct TrainerMatchCard: View {
    let trainer: OnboardingTrainer
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color(hex: trainer.accentHex).opacity(0.15))
                        .frame(width: 52, height: 52)
                    Text(trainer.initials)
                        .font(.system(size: 17, weight: .black))
                        .foregroundColor(Color(hex: trainer.accentHex))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(trainer.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.montraTextPrimary)
                        Text(trainer.certification)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.montraTextSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.07))
                            .clipShape(Capsule())
                    }
                    Text(trainer.bio)
                        .font(.system(size: 12))
                        .foregroundColor(.montraTextSecondary)
                        .lineLimit(2)

                    HStack(spacing: 6) {
                        ForEach(trainer.specialties.prefix(2), id: \.self) { s in
                            Text(s)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Color(hex: trainer.accentHex))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color(hex: trainer.accentHex).opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? Color.montraOrange : Color.white.opacity(0.2))
            }
            .padding(16)
            .background(isSelected ? Color.montraOrange.opacity(0.08) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.montraOrange : Color.montraCardBorder,
                            lineWidth: isSelected ? 1.5 : 0.8)
            )
        }
    }
}

// MARK: - Reusable Components

struct QuizStepShell<Content: View>: View {
    let stepNumber: Int
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(alignment: .top, spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.montraOrange)
                            .frame(width: 60, height: 60)
                        Text("\(stepNumber)")
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(.black)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(title.uppercased())
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.montraTextPrimary)
                        Text(subtitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.montraTextSecondary)
                    }
                }
                content
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
    }
}

struct QuizQuestionCard<Content: View>: View {
    let icon: String?
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundColor(.montraOrange)
                        .frame(width: 30, height: 30)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.montraTextSecondary)
                    }
                }
            }

            content
        }
        .padding(18)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
        )
    }
}

struct QuizInfoBanner: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.montraOrange)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.montraTextPrimary)
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct MiniChoiceCard: View {
    let title: String
    let subtitle: String?
    let accent: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Spacer()
                    Circle()
                        .stroke(selected ? accent : Color.white.opacity(0.22), lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Circle()
                                .fill(selected ? accent : Color.clear)
                                .frame(width: 10, height: 10)
                        )
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(selected ? accent : .montraTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.montraTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .background(selected ? accent.opacity(0.14) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? accent : Color.white.opacity(0.14), lineWidth: selected ? 1.5 : 1)
            )
        }
    }
}

struct MoodChoiceCard: View {
    let title: String
    let emoji: String?
    let icon: String?
    let accent: Color
    let selected: Bool
    let action: () -> Void

    init(title: String, emoji: String, accent: Color, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.emoji = emoji
        self.icon = nil
        self.accent = accent
        self.selected = selected
        self.action = action
    }

    init(title: String, icon: String, accent: Color, selected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.emoji = nil
        self.icon = icon
        self.accent = accent
        self.selected = selected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    Circle()
                        .stroke(selected ? accent : Color.white.opacity(0.22), lineWidth: 2)
                        .frame(width: 22, height: 22)
                        .overlay(
                            Image(systemName: selected ? "checkmark" : "")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.black)
                        )
                        .background(
                            Circle().fill(selected ? accent : Color.clear)
                        )
                }
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 31))
                } else if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(accent)
                }
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.montraTextPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 118)
            .background(selected ? accent.opacity(0.14) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? accent : Color.white.opacity(0.14), lineWidth: selected ? 1.5 : 1)
            )
        }
    }
}

struct MultiSelectCard: View {
    let title: String
    let icon: String
    let accent: Color
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(accent)
                    .frame(width: 22)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 32)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
            .background(selected ? accent.opacity(0.14) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(selected ? accent : Color.white.opacity(0.14), lineWidth: selected ? 1.5 : 1)
            )
            .overlay(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(selected ? accent : Color.white.opacity(0.22), lineWidth: 2)
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: selected ? "checkmark" : "")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selected ? accent : Color.clear)
                    )
                    .padding(12)
            }
        }
    }
}

struct GridOptionCard: View {
    let option: QuizOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                if let emoji = option.emoji { Text(emoji).font(.system(size: 26)) }
                Text(option.label)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.montraTextPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle = option.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.montraTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .frame(minHeight: 112, alignment: .topLeading)
            .background(isSelected ? Color.montraOrange.opacity(0.12) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.montraOrange : Color.montraCardBorder,
                        lineWidth: isSelected ? 1.5 : 0.8))
        }
    }
}

struct RowOptionCard: View {
    let option: QuizOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                if let emoji = option.emoji { Text(emoji).font(.system(size: 22)).frame(width: 32) }
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle = option.subtitle {
                        Text(subtitle)
                            .font(.system(size: 12))
                            .foregroundColor(.montraTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }
            .padding(16)
            .frame(minHeight: 76, alignment: .leading)
            .background(isSelected ? Color.montraOrange.opacity(0.12) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color.montraOrange : Color.montraCardBorder,
                        lineWidth: isSelected ? 1.5 : 0.8))
        }
    }
}

struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.montraTextSecondary)
                .frame(width: 80, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.montraTextPrimary)
            Spacer()
        }
    }
}

private struct MatchChecklistIntroView: View {
    let completedCount: Int
    let phases: [(title: String, subtitle: String)]
    let liveDataConnected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Preparing your\ntrainer options...")
                    .font(.system(size: 30, weight: .black))
                    .foregroundColor(.montraTextPrimary)
                Text(
                    liveDataConnected
                        ? "We're loading trainer profiles using the quiz filters you selected."
                        : "We're loading preview trainer profiles using the quiz filters you selected."
                )
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.montraTextSecondary)
            }

            VStack(spacing: 10) {
                ForEach(Array(phases.enumerated()), id: \.offset) { index, phase in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(index < completedCount ? Color.montraOrange : Color.clear)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Circle()
                                        .stroke(index < completedCount ? Color.montraOrange : Color.montraOrange.opacity(0.45), lineWidth: 1.6)
                                )

                            if index < completedCount {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.black)
                            } else if index == completedCount {
                                Circle()
                                    .trim(from: 0.1, to: 0.85)
                                    .stroke(Color.montraOrange, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                                    .frame(width: 16, height: 16)
                                    .rotationEffect(.degrees(-90))
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(phase.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.montraTextPrimary)
                            Text(phase.subtitle)
                                .font(.system(size: 14))
                                .foregroundColor(.montraTextSecondary)
                        }

                        Spacer()
                    }
                }
            }

            Spacer(minLength: 20)
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

struct QuizOption {
    let emoji: String?
    let label: String
    let subtitle: String?
}

#Preview {
    OnboardingQuizView()
}
