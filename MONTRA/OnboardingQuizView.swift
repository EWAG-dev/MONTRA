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
    let availableSlots: [String]   // placeholder — replaced by Firestore availability
}

extension OnboardingTrainer {
    static let all: [OnboardingTrainer] = [
        .init(id: "jordan_hayes", name: "Jordan Hayes", initials: "JH",
              certification: "NASM Certified",
              bio: "Specialises in strength-focused programming for all levels. Known for high-energy sessions and detailed form coaching.",
              specialties: ["Build Muscle", "Athletic Performance", "General Fitness"],
              locations: ["Boston, MA", "New York, NY"], gender: "Male", accentHex: "#FF6820",
              availableSlots: ["Mon Jun 2 · 7:00 AM", "Wed Jun 4 · 6:00 PM", "Sat Jun 7 · 9:00 AM"]),
        .init(id: "priya_nair", name: "Priya Nair", initials: "PN",
              certification: "ACE Certified",
              bio: "Holistic coach with a focus on sustainable fat loss, mobility, and overall wellness. 8+ years experience.",
              specialties: ["Lose Weight", "Flexibility & Wellness", "General Fitness"],
              locations: ["Boston, MA", "Rhode Island, RI"], gender: "Female", accentHex: "#A855F7",
              availableSlots: ["Tue Jun 3 · 10:00 AM", "Thu Jun 5 · 2:00 PM", "Sat Jun 7 · 11:00 AM"]),
        .init(id: "marcus_webb", name: "Marcus Webb", initials: "MW",
              certification: "NSCA Certified",
              bio: "Former competitive boxer turned coach. Brings real combat sports experience to every client's programme.",
              specialties: ["Combat Sports", "Athletic Performance", "Build Muscle"],
              locations: ["New York, NY", "New Jersey, NJ"], gender: "Male", accentHex: "#3B82F6",
              availableSlots: ["Mon Jun 2 · 6:00 PM", "Wed Jun 4 · 7:00 AM", "Fri Jun 6 · 5:00 PM"]),
        .init(id: "sofia_chen", name: "Sofia Chen", initials: "SC",
              certification: "ISSA Certified",
              bio: "Yoga-certified movement specialist. Creates plans that balance performance with recovery.",
              specialties: ["Flexibility & Wellness", "General Fitness", "Lose Weight"],
              locations: ["Connecticut, CT", "New Jersey, NJ"], gender: "Female", accentHex: "#10B981",
              availableSlots: ["Tue Jun 3 · 9:00 AM", "Thu Jun 5 · 5:00 PM", "Sun Jun 8 · 10:00 AM"]),
        .init(id: "tyler_brooks", name: "Tyler Brooks", initials: "TB",
              certification: "NASM Certified",
              bio: "Data-driven approach to general fitness and weight loss. Clients consistently beat their goals.",
              specialties: ["General Fitness", "Lose Weight", "Athletic Performance"],
              locations: ["Rhode Island, RI", "Connecticut, CT"], gender: "Male", accentHex: "#F59E0B",
              availableSlots: ["Mon Jun 2 · 8:00 AM", "Wed Jun 4 · 12:00 PM", "Fri Jun 6 · 7:00 AM"]),
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

    @AppStorage("onboarding.completed")      private var isCompleted = false
    @AppStorage("quiz.goal")                 private var savedGoal = ""
    @AppStorage("quiz.experience")           private var savedExperience = ""
    @AppStorage("quiz.location")             private var savedLocation = ""
    @AppStorage("quiz.schedule")             private var savedSchedule = ""
    @AppStorage("quiz.frequency")            private var savedFrequency = ""
    @AppStorage("quiz.coachPreference")      private var savedCoachPref = ""
    @AppStorage("quiz.firstName")            private var savedFirstName = ""
    @AppStorage("quiz.bookedTrainerName") private var bookedTrainerName = ""
    @AppStorage("quiz.bookedSlot")        private var bookedSlot = ""

    @State private var step = 1
    @State private var forward = true
    @State private var selectedSchedule: Set<String> = []
    @State private var firstName = ""
    @State private var selectedTrainer: OnboardingTrainer? = nil
    @State private var selectedSlot: String? = nil

    private let quizSteps = 7

    var body: some View {
        ZStack {
            Color.montraBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: Header
                VStack(spacing: 12) {
                    HStack {
                        if step > 1 && step <= 8 {
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
                        } else if step == 8 {
                            Text("Your matches")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.montraTextSecondary)
                                .kerning(0.5)
                        }

                        Spacer()

                        if step == 6 {
                            Button("Skip") { completeStep(value: "No preference") }
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.montraTextSecondary)
                        } else {
                            Spacer().frame(width: 40)
                        }
                    }

                    if step <= quizSteps {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 3)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "#FF6820"))
                                    .frame(width: geo.size.width * (Double(step) / Double(quizSteps)), height: 3)
                                    .animation(.easeInOut(duration: 0.35), value: step)
                            }
                        }
                        .frame(height: 3)
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(hex: "#FF6820"))
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
        case 2: experienceStep
        case 3: locationStep
        case 4: scheduleStep
        case 5: frequencyStep
        case 6: coachPrefStep
        case 7: nameStep
        case 8: trainerMatchStep
        default: confirmationStep
        }
    }

    // MARK: Step 1 — Goal

    private var goalStep: some View {
        QuizStepShell(title: "What's your main goal?",
                      subtitle: "Choose the one that matters most right now.") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(goalOptions, id: \.label) { opt in
                    GridOptionCard(option: opt, isSelected: false) { completeStep(value: opt.label) }
                }
            }
        }
    }

    // MARK: Step 2 — Experience

    private var experienceStep: some View {
        QuizStepShell(title: "What's your fitness experience?",
                      subtitle: "This helps us find the right coaching style for you.") {
            VStack(spacing: 10) {
                ForEach(experienceOptions, id: \.label) { opt in
                    RowOptionCard(option: opt, isSelected: false) { completeStep(value: opt.label) }
                }
            }
        }
    }

    // MARK: Step 3 — Location

    private var locationStep: some View {
        QuizStepShell(title: "Where are you located?",
                      subtitle: "We'll show you coaches available in your area.") {
            VStack(spacing: 10) {
                ForEach(locationOptions, id: \.self) { loc in
                    Button { completeStep(value: loc) } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color(hex: "#FF6820"))
                            Text(loc)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.montraTextPrimary)
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.montraCardBorder, lineWidth: 0.8))
                    }
                }
            }
        }
    }

    // MARK: Step 4 — Schedule (multi-select)

    private var scheduleStep: some View {
        QuizStepShell(title: "When do you prefer to train?",
                      subtitle: "Select all that apply.") {
            VStack(spacing: 14) {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(scheduleOptions, id: \.label) { opt in
                        GridOptionCard(option: opt, isSelected: selectedSchedule.contains(opt.label)) {
                            if selectedSchedule.contains(opt.label) { selectedSchedule.remove(opt.label) }
                            else { selectedSchedule.insert(opt.label) }
                        }
                    }
                }

                Button {
                    savedSchedule = selectedSchedule.sorted().joined(separator: ", ")
                    advance(by: 1)
                } label: {
                    Text(selectedSchedule.isEmpty ? "Select at least one" : "Continue")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(selectedSchedule.isEmpty ? .montraTextSecondary : .black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(selectedSchedule.isEmpty ? Color.white.opacity(0.08) : Color(hex: "#FF6820"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(selectedSchedule.isEmpty)
            }
        }
    }

    // MARK: Step 5 — Frequency

    private var frequencyStep: some View {
        QuizStepShell(title: "How often do you want to train?",
                      subtitle: "We'll match you with coaches who fit your schedule.") {
            VStack(spacing: 10) {
                ForEach(frequencyOptions, id: \.label) { opt in
                    RowOptionCard(option: opt, isSelected: false) { completeStep(value: opt.label) }
                }
            }
        }
    }

    // MARK: Step 6 — Coach Preference (skippable)

    private var coachPrefStep: some View {
        QuizStepShell(title: "Do you have a coach preference?",
                      subtitle: "Totally optional — skip if you don't mind.") {
            VStack(spacing: 10) {
                ForEach(coachPrefOptions, id: \.label) { opt in
                    RowOptionCard(option: opt, isSelected: false) { completeStep(value: opt.label) }
                }
            }
        }
    }

    // MARK: Step 7 — Name

    private var nameStep: some View {
        QuizStepShell(title: "What should we call you?",
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
                        .background(canContinue ? Color(hex: "#FF6820") : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    // MARK: Step 8 — Trainer Matches + Slot Booking

    private var trainerMatchStep: some View {
        let matches = OnboardingTrainer.matched(
            goal: savedGoal,
            location: savedLocation,
            genderPref: savedCoachPref
        )
        let canBook = selectedTrainer != nil && selectedSlot != nil
        return ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Here are your\nmatches, \(savedFirstName.isEmpty ? "there" : savedFirstName).")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.montraTextPrimary)
                    Text("Pick a coach and choose your first session slot.")
                        .font(.system(size: 14))
                        .foregroundColor(.montraTextSecondary)
                }

                VStack(spacing: 14) {
                    ForEach(matches) { trainer in
                        TrainerMatchCard(
                            trainer: trainer,
                            isSelected: selectedTrainer?.id == trainer.id,
                            selectedSlot: selectedTrainer?.id == trainer.id ? selectedSlot : nil
                        ) {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                selectedTrainer = trainer
                                selectedSlot = nil   // reset slot when switching coaches
                            }
                        } onSelectSlot: { slot in
                            withAnimation(.easeInOut(duration: 0.15)) { selectedSlot = slot }
                        }
                    }
                }

                Button {
                    guard let t = selectedTrainer, let slot = selectedSlot else { return }
                    bookedTrainerName = t.name
                    bookedSlot        = slot
                    advance(by: 1)
                } label: {
                    let label: String = {
                        if let slot = selectedSlot, let t = selectedTrainer {
                            let first = t.name.components(separatedBy: " ").first ?? "Coach"
                            return "Book \(slot) with \(first)"
                        }
                        return selectedTrainer == nil ? "Select a coach" : "Choose a time slot"
                    }()
                    Text(label)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(canBook ? .black : .montraTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(canBook ? Color(hex: "#FF6820") : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .animation(.easeInOut(duration: 0.2), value: canBook)
                }
                .disabled(!canBook)

                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
        }
    }

    // MARK: Confirmation Step

    private var confirmationStep: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 28) {
                Spacer(minLength: 40)

                ZStack {
                    Circle()
                        .stroke(Color(hex: "#FF6820").opacity(0.2), lineWidth: 2)
                        .frame(width: 96, height: 96)
                    Circle()
                        .fill(Color(hex: "#FF6820").opacity(0.12))
                        .frame(width: 76, height: 76)
                    Image(systemName: "checkmark")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(Color(hex: "#FF6820"))
                }

                VStack(spacing: 8) {
                    Text("Session booked!")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.montraTextPrimary)
                    Text("Your intro session with \(bookedTrainerName)\nis confirmed.")
                        .font(.system(size: 15))
                        .foregroundColor(.montraTextSecondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 12) {
                    SummaryRow(label: "Coach",   value: bookedTrainerName)
                    SummaryRow(label: "When",    value: bookedSlot)
                    SummaryRow(label: "Goal",    value: savedGoal)
                    SummaryRow(label: "Location", value: savedLocation)
                }
                .padding(18)
                .montraCard(radius: 16)
                .padding(.horizontal, 24)

                Button { isCompleted = true } label: {
                    Text("Go to my dashboard")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color(hex: "#FF6820"))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Helpers

    private func completeStep(value: String) {
        switch step {
        case 1: savedGoal = value
        case 2: savedExperience = value
        case 3: savedLocation = value
        case 5: savedFrequency = value
        case 6: savedCoachPref = value
        default: break
        }
        advance(by: 1)
    }

    private func advance(by delta: Int) {
        forward = delta > 0
        withAnimation { step = max(1, step + delta) }
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

    private let locationOptions = [
        "Boston, MA", "New York, NY", "New Jersey, NJ", "Rhode Island, RI", "Connecticut, CT"
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
}

// MARK: - Trainer Match Card

struct TrainerMatchCard: View {
    let trainer: OnboardingTrainer
    let isSelected: Bool
    let selectedSlot: String?
    let action: () -> Void
    let onSelectSlot: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Coach header row (tap to select coach)
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
                        .foregroundColor(isSelected ? Color(hex: "#FF6820") : Color.white.opacity(0.2))
                }
                .padding(16)
            }

            // Available slots (shown only when this coach is selected)
            if isSelected {
                VStack(alignment: .leading, spacing: 0) {
                    Divider().background(Color.white.opacity(0.08))
                    HStack {
                        Text("Available intro sessions")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.montraTextSecondary)
                            .kerning(0.3)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                    ForEach(trainer.availableSlots, id: \.self) { slot in
                        let slotSelected = selectedSlot == slot
                        Button { onSelectSlot(slot) } label: {
                            HStack {
                                Image(systemName: "clock")
                                    .font(.system(size: 12))
                                    .foregroundColor(slotSelected ? Color(hex: "#FF6820") : .montraTextSecondary)
                                Text(slot)
                                    .font(.system(size: 13, weight: slotSelected ? .semibold : .regular))
                                    .foregroundColor(slotSelected ? .montraTextPrimary : .montraTextSecondary)
                                Spacer()
                                if slotSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(hex: "#FF6820"))
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(slotSelected ? Color(hex: "#FF6820").opacity(0.08) : Color.clear)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
        }
        .background(isSelected ? Color(hex: "#FF6820").opacity(0.06) : Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? Color(hex: "#FF6820") : Color.montraCardBorder,
                        lineWidth: isSelected ? 1.5 : 0.8)
        )
    }
}

// MARK: - Reusable Components

struct QuizStepShell<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.montraTextPrimary)
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.montraTextSecondary)
                }
                content
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)
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
                if let subtitle = option.subtitle {
                    Text(subtitle).font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(isSelected ? Color(hex: "#FF6820").opacity(0.12) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color(hex: "#FF6820") : Color.montraCardBorder,
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
                    if let subtitle = option.subtitle {
                        Text(subtitle).font(.system(size: 12)).foregroundColor(.montraTextSecondary)
                    }
                }
                Spacer()
            }
            .padding(16)
            .background(isSelected ? Color(hex: "#FF6820").opacity(0.12) : Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(isSelected ? Color(hex: "#FF6820") : Color.montraCardBorder,
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

struct QuizOption {
    let emoji: String?
    let label: String
    let subtitle: String?
}

#Preview {
    OnboardingQuizView()
}
