import SwiftUI
import Charts
import Foundation

// MARK: - Data Models

struct ProgressDataPoint: Identifiable {
    let id = UUID()
    let day: Int
    let dayLabel: String
    let value: Double
}

struct Achievement: Identifiable {
    let id = UUID()
    let icon: String
    let iconColor: Color
    let badgeColor: Color
    let title: String
    let subtitle: String?
    let date: String
}

// MARK: - Main View

struct WorkoutProgressView: View {
    private struct MealDayPlan: Identifiable {
        let id: String
        let breakfast: String
        let lunch: String
        let dinner: String
    }

    @State private var selectedTab = 0
    @State private var selectedPeriodKey: String = ""
    @State private var showAllAchievements = false
    @State private var showProfileSheet = false
    @State private var showNotifications = false
    @State private var selectedNutritionGoal = "Fat Loss"
    @State private var selectedDietType = "Balanced (Omnivore)"
    @State private var wantsKeto = false
    @State private var wantsGlutenFree = false
    @State private var wantsLactoseFree = false
    @State private var wantsHighProtein = false
    @State private var hasAllergies = false
    @State private var allergyInputText = ""
    @State private var mealSuggestionSeed = 0
    @State private var mealSuggestionNote = "Suggestions generated from your current profile."
    @State private var isGeneratingAISuggestions = false
    private let tabs = ["Overview", "Workouts", "Nutrition", "Body Stats"]

    private let trainerProgress = TrainerProgressSnapshot.sample

    // Shared AppStorage keys — same as DashboardView
    @AppStorage("progress.currentWeight") private var currentWeightStr: String = ""
    @AppStorage("progress.startWeight") private var startWeightStr: String = ""
    @AppStorage("progress.goal.strengthWeeklySessions") private var strengthTargetStr: String = "5"

    // MARK: Computed stats

    private var weightLostDisplay: String {
        guard let current = Double(currentWeightStr),
              let start = Double(startWeightStr.isEmpty ? currentWeightStr : startWeightStr)
        else { return "--" }
        let delta = start - current
        if delta == 0 { return "0 lbs" }
        return delta > 0
            ? String(format: "-%.1f lbs", delta)
            : String(format: "+%.1f lbs", abs(delta))
    }

    private var weeklySessionPctDisplay: String {
        let target = max(Int(strengthTargetStr) ?? 5, 1)
        let pct = Int((Double(trainerProgress.completedSessionsThisWeek) / Double(target) * 100).rounded())
        return pct > 0 ? "+\(pct)%" : "0%"
    }

    private var caloriesDisplay: String {
        let cal = trainerProgress.weeklyCalories
        if cal >= 1000 {
            return String(format: "+%.1fk", Double(cal) / 1000.0)
        }
        return cal > 0 ? "+\(cal)" : "0"
    }

    private var monthlySessionsDisplay: String { "\(completedSessionsInSelectedPeriod.count)" }

    private var currentPeriodKey: String {
        let c = Calendar.current.dateComponents([.year, .month], from: Date())
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    private var selectedPeriodDate: Date {
        let key = selectedPeriodKey.isEmpty ? currentPeriodKey : selectedPeriodKey
        let parts = key.split(separator: "-")
        guard parts.count == 2,
              let year = Int(parts[0]),
              let month = Int(parts[1])
        else { return Date() }
        return Calendar.current.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    private var selectedPeriodLabel: String {
        let key = selectedPeriodKey.isEmpty ? currentPeriodKey : selectedPeriodKey
        if key == currentPeriodKey { return "This Month" }
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: selectedPeriodDate)
    }

    private var periodOptions: [(key: String, label: String)] {
        let calendar = Calendar.current
        let keys = Set(
            trainerProgress.sessions
                .filter { $0.completed }
                .map {
                    let c = calendar.dateComponents([.year, .month], from: $0.date)
                    return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
                }
        )

        let withCurrent = keys.union([currentPeriodKey])
        let sorted = withCurrent.sorted(by: >)
        return sorted.map { key in
            if key == currentPeriodKey {
                return (key, "This Month")
            }
            let p = key.split(separator: "-")
            if p.count == 2, let year = Int(p[0]), let month = Int(p[1]),
               let d = calendar.date(from: DateComponents(year: year, month: month, day: 1)) {
                let f = DateFormatter()
                f.dateFormat = "MMMM yyyy"
                return (key, f.string(from: d))
            }
            return (key, key)
        }
    }

    private var completedSessionsInSelectedPeriod: [TrainerSessionRecord] {
        let calendar = Calendar.current
        let key = selectedPeriodKey.isEmpty ? currentPeriodKey : selectedPeriodKey
        return trainerProgress.sessions.filter { session in
            guard session.completed else { return false }
            let c = calendar.dateComponents([.year, .month], from: session.date)
            let sKey = String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
            return sKey == key
        }
    }

    // Cumulative completed-sessions curve for the current month
    private var chartData: [ProgressDataPoint] {
        let calendar = Calendar.current
        let selected = selectedPeriodDate
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: selected)) else {
            return []
        }
        let isCurrentMonth = calendar.isDate(selected, equalTo: Date(), toGranularity: .month)
        let todayDay = calendar.component(.day, from: Date())
        let dayUpperBound: Int = {
            if isCurrentMonth { return todayDay }
            return calendar.range(of: .day, in: .month, for: selected)?.count ?? 30
        }()

        // Map each completed session this month to its day-of-month
        let sessionDays: [Int] = completedSessionsInSelectedPeriod
            .compactMap {
                guard let day = calendar.dateComponents([.day], from: monthStart, to: calendar.startOfDay(for: $0.date)).day else { return nil }
                return day + 1
            }
            .sorted()

        // Build cumulative count per day that had a session (plus day 1 anchor at 0)
        var result: [ProgressDataPoint] = [.init(day: 1, dayLabel: dayLabel(for: 1, in: selected), value: 0)]
        var cumulative = 0
        for day in sessionDays {
            cumulative += 1
            // Replace last point if same day, otherwise append
            if result.last?.day == day {
                result[result.count - 1] = .init(day: day, dayLabel: dayLabel(for: day, in: selected), value: Double(cumulative))
            } else {
                result.append(.init(day: day, dayLabel: dayLabel(for: day, in: selected), value: Double(cumulative)))
            }
        }
        // Extend line to the end of selected visible range if no session on that day
        if result.last?.day ?? 0 < dayUpperBound {
            result.append(.init(day: dayUpperBound, dayLabel: dayLabel(for: dayUpperBound, in: selected), value: Double(cumulative)))
        }
        return result
    }

    private var chartYMax: Double {
        max(Double(completedSessionsInSelectedPeriod.count + 1), 5)
    }

    private var previousWorkouts: [TrainerSessionRecord] {
        trainerProgress.sessions
            .filter { $0.completed }
            .sorted { $0.date > $1.date }
    }

    private var upcomingPlannedWorkouts: [TrainerSessionRecord] {
        let today = Calendar.current.startOfDay(for: Date())
        return trainerProgress.sessions
            .filter { !$0.completed && $0.date >= today }
            .sorted { $0.date < $1.date }
    }

    private let nutritionGoalOptions = [
        "Fat Loss",
        "Muscle Gain",
        "Performance",
        "Maintenance"
    ]

    private let dietTypeOptions = [
        "Balanced (Omnivore)",
        "Vegetarian",
        "Vegan",
        "Pescatarian",
        "Keto",
        "Low-Carb",
        "Mediterranean",
        "Paleo",
        "High-Protein",
        "Gluten-Free"
    ]

    private var customAllergies: [String] {
        allergyInputText
            .split(whereSeparator: { $0 == "," || $0 == "\n" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var allergiesTextBlob: String {
        var base = customAllergies.joined(separator: " ").lowercased()
        if wantsLactoseFree { base += " lactose dairy milk" }
        if wantsGlutenFree { base += " gluten wheat" }
        return base
    }

    private var nutritionAdvice: [String] {
        var advice: [String] = [
            "Build each meal around lean protein, fiber-rich carbs, and colorful vegetables.",
            "Hydrate consistently throughout the day and include electrolytes around harder sessions."
        ]

        switch selectedNutritionGoal {
        case "Fat Loss":
            advice.append("Keep a mild calorie deficit and prioritize high-volume meals like salads, soups, and grilled proteins.")
        case "Muscle Gain":
            advice.append("Aim for protein in every meal and a small calorie surplus using whole-food carbs and healthy fats.")
        case "Performance":
            advice.append("Time carbs around training and include a post-workout meal with both protein and carbohydrates.")
        default:
            advice.append("Use consistent meal timing and portions you can sustain long term.")
        }

        switch selectedDietType {
        case "Vegetarian":
            advice.append("Use eggs, Greek yogurt (if tolerated), tofu, tempeh, lentils, and beans to hit protein targets.")
        case "Vegan":
            advice.append("Combine legumes, soy foods, whole grains, nuts, and seeds; consider B12 and omega-3 support.")
        case "Pescatarian":
            advice.append("Use fish 2-3 times weekly for omega-3s and rotate with legumes and whole grains.")
        case "Keto":
            advice.append("Keep carbs very low, prioritize protein and non-starchy vegetables, and use healthy fats for satiety.")
        case "Low-Carb":
            advice.append("Focus on protein, non-starchy vegetables, and unsaturated fats while timing carbs around workouts.")
        case "Mediterranean":
            advice.append("Lean on fish, olive oil, legumes, vegetables, fruit, and whole grains with moderate dairy if tolerated.")
        case "Paleo":
            advice.append("Center meals on meat, fish, eggs, vegetables, fruit, and nuts/seeds while avoiding grains and legumes.")
        case "High-Protein":
            advice.append("Aim for protein at every meal and snack, and spread intake evenly across the day.")
        case "Gluten-Free":
            advice.append("Use naturally gluten-free staples like rice, potatoes, quinoa, oats (certified), and corn.")
        default:
            break
        }

        if wantsKeto && selectedDietType != "Keto" {
            advice.append("Keto preference is enabled: keep carbs low and increase protein + healthy fats.")
        }
        if wantsHighProtein && selectedDietType != "High-Protein" {
            advice.append("High-protein preference is enabled: include protein at each meal/snack.")
        }
        if wantsGlutenFree && selectedDietType != "Gluten-Free" {
            advice.append("Gluten-free preference is enabled: choose naturally gluten-free whole foods.")
        }
        if wantsLactoseFree {
            advice.append("Lactose-free preference is enabled: use lactose-free dairy or fortified non-dairy alternatives.")
        }

        if allergiesTextBlob.contains("lactose") || allergiesTextBlob.contains("dairy") || allergiesTextBlob.contains("milk") {
            advice.append("Choose lactose-free milk, hard cheeses, kefir, or fortified soy/almond/oat alternatives for calcium and protein.")
            advice.append("Watch labels for hidden dairy terms like whey, casein, milk solids, and lactose powder.")
        }

        if allergiesTextBlob.contains("gluten") || allergiesTextBlob.contains("wheat") {
            advice.append("Check sauces and dressings for hidden gluten, including soy sauce, malt flavoring, and some broths.")
        }

        if allergiesTextBlob.contains("nut") || allergiesTextBlob.contains("peanut") {
            advice.append("Swap nuts with seeds (chia, flax, pumpkin, sunflower) and always review cross-contamination labels.")
        }

        if allergiesTextBlob.contains("shellfish") {
            advice.append("Avoid shellfish-derived stocks and sauces; choose fish, poultry, tofu, legumes, or eggs instead.")
        }

        if allergiesTextBlob.contains("egg") {
            advice.append("Use flax/chia egg alternatives in recipes and check sauces or baked foods for hidden egg content.")
        }

        if allergiesTextBlob.contains("soy") {
            advice.append("Avoid soy protein isolate, soy lecithin, tofu, and tempeh; rotate in fish, eggs, poultry, and legumes if tolerated.")
        }

        if allergiesTextBlob.contains("sesame") {
            advice.append("Check labels for sesame oil, tahini, and spice blends where sesame is often hidden.")
        }

        if hasAllergies, !customAllergies.isEmpty {
            advice.append("Custom allergy profile active: \(customAllergies.joined(separator: ", ")).")
        }

        return advice
    }

    private var nutritionWarnings: [String] {
        var warnings: [String] = []
        if allergiesTextBlob.contains("lactose") || allergiesTextBlob.contains("dairy") || allergiesTextBlob.contains("milk") {
            warnings.append("Dairy can appear in protein bars, cream sauces, flavored chips, and some deli meats.")
        }
        if allergiesTextBlob.contains("gluten") || allergiesTextBlob.contains("wheat") {
            warnings.append("Gluten may show up in marinades, processed soups, and packaged spice blends.")
        }
        if allergiesTextBlob.contains("nut") || allergiesTextBlob.contains("peanut") {
            warnings.append("Nut traces are common in granola, desserts, and protein snacks made in shared facilities.")
        }
        if allergiesTextBlob.contains("shellfish") {
            warnings.append("Shellfish ingredients can appear in certain Asian sauces and seafood flavor concentrates.")
        }
        if allergiesTextBlob.contains("egg") {
            warnings.append("Egg can appear in mayo, aioli, baked goods, and pasta washes.")
        }
        if allergiesTextBlob.contains("soy") {
            warnings.append("Soy can appear in protein powders, snack bars, soy sauce, and processed foods.")
        }
        if allergiesTextBlob.contains("sesame") {
            warnings.append("Sesame can appear in breads, hummus, dressings, and restaurant cooking oils.")
        }
        if hasAllergies, !customAllergies.isEmpty {
            warnings.append("Watch for custom allergy triggers: \(customAllergies.joined(separator: ", ")).")
        }
        return warnings
    }

    private var weeklyMealPlan: [MealDayPlan] {
        let dayTemplates = [
            "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
        ]

        let breakfastBase: [String]
        let lunchBase: [String]
        let dinnerBase: [String]

        let effectiveDiet: String = {
            if wantsKeto { return "Keto" }
            if wantsHighProtein { return "High-Protein" }
            if wantsGlutenFree { return "Gluten-Free" }
            return selectedDietType
        }()

        switch effectiveDiet {
        case "Vegan":
            breakfastBase = ["Overnight oats with chia and berries", "Tofu scramble with spinach"]
            lunchBase = ["Lentil quinoa bowl", "Chickpea salad wrap"]
            dinnerBase = ["Tofu stir-fry with vegetables", "Bean chili with avocado"]
        case "Vegetarian":
            breakfastBase = ["Greek yogurt bowl with fruit", "Veggie omelet"]
            lunchBase = ["Paneer and veggie grain bowl", "Lentil soup and side salad"]
            dinnerBase = ["Egg fried rice with vegetables", "Black bean tacos with slaw"]
        case "Keto":
            breakfastBase = ["Egg and avocado plate", "Greek yogurt with nuts and seeds"]
            lunchBase = ["Chicken salad with olive oil dressing", "Salmon and greens bowl"]
            dinnerBase = ["Steak with roasted vegetables", "Turkey lettuce wraps"]
        case "Pescatarian":
            breakfastBase = ["Protein oats with fruit", "Spinach egg white scramble"]
            lunchBase = ["Tuna quinoa salad", "Sardine and veggie toast"]
            dinnerBase = ["Baked salmon with potatoes", "Shrimp rice bowl"]
        case "High-Protein":
            breakfastBase = ["Egg white scramble with turkey", "Protein yogurt bowl with berries"]
            lunchBase = ["Chicken and quinoa power bowl", "Tuna and bean salad"]
            dinnerBase = ["Lean beef with roasted vegetables", "Salmon with lentil side"]
        case "Gluten-Free":
            breakfastBase = ["Greek yogurt and berries", "Egg scramble with potatoes"]
            lunchBase = ["Chicken rice bowl", "Quinoa chickpea salad"]
            dinnerBase = ["Salmon with roasted potatoes", "Turkey and veggie skillet"]
        default:
            breakfastBase = ["Protein oats with fruit", "Egg scramble with veggies"]
            lunchBase = ["Chicken grain bowl", "Turkey wrap and side salad"]
            dinnerBase = ["Salmon and rice with greens", "Lean beef stir-fry"]
        }

        let breakfast = rotateArray(breakfastBase, by: mealSuggestionSeed)
        let lunch = rotateArray(lunchBase, by: mealSuggestionSeed + 1)
        let dinner = rotateArray(dinnerBase, by: mealSuggestionSeed + 2)

        var suggestions: [MealDayPlan] = []
        for (index, day) in dayTemplates.enumerated() {
            let b = applyMealModifiers(breakfast[index % breakfast.count])
            let l = applyMealModifiers(lunch[index % lunch.count])
            let d = applyMealModifiers(dinner[index % dinner.count])
            suggestions.append(MealDayPlan(id: day, breakfast: b, lunch: l, dinner: d))
        }

        return suggestions
    }

    private func applyMealModifiers(_ meal: String) -> String {
        var output = meal

        if wantsLactoseFree || allergiesTextBlob.contains("lactose") || allergiesTextBlob.contains("dairy") || allergiesTextBlob.contains("milk") {
            output = output.replacingOccurrences(of: "Greek yogurt", with: "lactose-free yogurt")
            output = output.replacingOccurrences(of: "Paneer", with: "tofu")
        }

        if wantsGlutenFree || allergiesTextBlob.contains("gluten") || allergiesTextBlob.contains("wheat") {
            output = output.replacingOccurrences(of: "wrap", with: "lettuce wrap")
            output = output.replacingOccurrences(of: "toast", with: "gluten-free toast")
        }

        if allergiesTextBlob.contains("shellfish") {
            output = output.replacingOccurrences(of: "Shrimp", with: "Chicken")
        }

        return output
    }

    private func rotateArray(_ values: [String], by shift: Int) -> [String] {
        guard !values.isEmpty else { return values }
        let offset = ((shift % values.count) + values.count) % values.count
        return Array(values[offset...] + values[..<offset])
    }

    private func refreshWeeklyMeals() {
        mealSuggestionSeed = Int.random(in: 0...1000)
        mealSuggestionNote = "Suggestions refreshed just now."
    }

    private func requestMontraAISuggestions() async {
        await MainActor.run {
            isGeneratingAISuggestions = true
            mealSuggestionNote = "Generating with MONTRA AI..."
        }

        guard let url = MontraAPIConfig.url(for: "/api/ai/coach-suggestion") else {
            await MainActor.run {
                isGeneratingAISuggestions = false
                mealSuggestionNote = "MONTRA AI endpoint unavailable. Using local smart suggestions."
                refreshWeeklyMeals()
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: Any] = [
            "goal": selectedNutritionGoal,
            "mood": selectedDietType,
            "availability": activeMealTags
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            _ = try await URLSession.shared.data(for: request)
            await MainActor.run {
                isGeneratingAISuggestions = false
                mealSuggestionNote = "MONTRA AI refreshed your suggestions."
                refreshWeeklyMeals()
            }
        } catch {
            await MainActor.run {
                isGeneratingAISuggestions = false
                mealSuggestionNote = "MONTRA AI is not connected yet. Showing local smart suggestions."
                refreshWeeklyMeals()
            }
        }
    }

    private var activeMealTags: [String] {
        var tags: [String] = [selectedDietType]
        if wantsKeto { tags.append("Keto") }
        if wantsGlutenFree { tags.append("Gluten-Free") }
        if wantsLactoseFree { tags.append("Lactose-Free") }
        if wantsHighProtein { tags.append("High-Protein") }
        if hasAllergies, !customAllergies.isEmpty {
            tags.append("Allergies: \(customAllergies.count)")
        }
        return Array(Set(tags)).sorted()
    }

    private let achievements: [Achievement] = [
        Achievement(
            icon: "flame.fill",
            iconColor: Color(hex: "#FF6A00"),
            badgeColor: Color(hex: "#5C2200"),
            title: "Consistency King",
            subtitle: nil,
            date: "M90 /, 2024"
        ),
        Achievement(
            icon: "trophy.fill",
            iconColor: Color(hex: "#4A90D9"),
            badgeColor: Color(hex: "#102040"),
            title: "Early Riser",
            subtitle: "3 early morning sessions",
            date: "May 5, 2024"
        ),
        Achievement(
            icon: "dumbbell.fill",
            iconColor: Color(hex: "#4CAF50"),
            badgeColor: Color(hex: "#0E3B0E"),
            title: "First Milestone",
            subtitle: "Completed 10 sessions",
            date: "May 10, 2024"
        ),
        Achievement(
            icon: "figure.run",
            iconColor: Color(hex: "#22C55E"),
            badgeColor: Color(hex: "#10321B"),
            title: "Cardio Sprint",
            subtitle: "5 cardio sessions in one week",
            date: "Apr 24, 2024"
        ),
        Achievement(
            icon: "heart.fill",
            iconColor: Color(hex: "#EF4444"),
            badgeColor: Color(hex: "#3A0F16"),
            title: "Heart Health Win",
            subtitle: "Resting HR improved by 6 bpm",
            date: "Apr 14, 2024"
        ),
        Achievement(
            icon: "bolt.fill",
            iconColor: Color(hex: "#FACC15"),
            badgeColor: Color(hex: "#3B3208"),
            title: "Power Output PR",
            subtitle: "New personal best in strength circuit",
            date: "Mar 31, 2024"
        )
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // MARK: Header
                ClientMessagesStyleHeader(
                    title: "Progress",
                    onNotificationTap: { showNotifications = true },
                    onProfileTap: { showProfileSheet = true }
                )
                    .padding(.bottom, 12)

                HStack {
                    Spacer()
                    Menu {
                        ForEach(periodOptions, id: \.key) { option in
                            Button {
                                selectedPeriodKey = option.key
                            } label: {
                                if option.key == selectedPeriodKey || (selectedPeriodKey.isEmpty && option.key == currentPeriodKey) {
                                    Label(option.label, systemImage: "checkmark")
                                } else {
                                    Text(option.label)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 5) {
                            Text(selectedPeriodLabel)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.montraTextPrimary)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.montraTextPrimary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.bottom, 16)

                // MARK: Sub-tab Bar
                HStack(spacing: 0) {
                    ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                        Button(action: { selectedTab = index }) {
                            VStack(spacing: 8) {
                                Text(tab)
                                    .font(.system(size: 13, weight: selectedTab == index ? .semibold : .regular))
                                    .foregroundColor(selectedTab == index ? .montraOrange : .montraTextSecondary)
                                Rectangle()
                                    .fill(selectedTab == index ? Color.montraOrange : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, 20)

                // MARK: Tab Content
                switch selectedTab {
                case 0:
                    overviewContent
                case 1:
                    workoutsTabContent
                case 2:
                    nutritionTabContent
                default:
                    comingSoonContent
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.montraBackground)
        .sheet(isPresented: $showAllAchievements) {
            AllAchievementsSheet(achievements: achievements)
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileMenuSheet(isClient: true)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .onAppear {
            if selectedPeriodKey.isEmpty {
                selectedPeriodKey = currentPeriodKey
            }
        }
    }

    // MARK: - Overview Content

    @ViewBuilder
    private var overviewContent: some View {

        // Progress Overview Card with Chart
        VStack(alignment: .leading, spacing: 14) {
            Text("PROGRESS OVERVIEW")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.montraTextPrimary)
                .kerning(0.8)

            ProgressLineChart(data: chartData, yMax: chartYMax)
                .frame(height: 170)
        }
        .padding(18)
        .montraCard(radius: 16)
        .padding(.bottom, 16)

        // 4 Stat Tiles
        HStack(spacing: 10) {
            ProgressStatTile(
                icon: "scalemass.fill",
                iconColor: .montraOrange,
                value: weightLostDisplay,
                label: "Weight\nLost"
            )
            ProgressStatTile(
                icon: "chart.bar.fill",
                iconColor: Color(hex: "#4CAF50"),
                value: weeklySessionPctDisplay,
                label: "Session\nGoal"
            )
            ProgressStatTile(
                icon: "flame.fill",
                iconColor: Color(hex: "#FFD700"),
                value: caloriesDisplay,
                label: "Weekly\nCalories"
            )
            ProgressStatTile(
                icon: "person.fill",
                iconColor: .montraTextPrimary,
                value: monthlySessionsDisplay,
                label: "Sessions"
            )
        }
        .padding(.bottom, 20)

        // Recent Achievements
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("RECENT ACHIEVEMENTS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                    .kerning(0.8)
                Spacer()
                Button("View All") { showAllAchievements = true }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.montraOrange)
            }
            .padding(.bottom, 16)

            let recentAchievements = Array(achievements.prefix(3))
            ForEach(Array(recentAchievements.enumerated()), id: \.element.id) { index, achievement in
                AchievementRow(achievement: achievement)
                if index < recentAchievements.count - 1 {
                    Divider()
                        .background(Color.montraDivider)
                        .padding(.vertical, 12)
                }
            }
        }
        .padding(18)
        .montraCard(radius: 16)
    }

    private func dayLabel(for day: Int, in monthDate: Date) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: monthDate)
        let monthName = DateFormatter().shortMonthSymbols[month - 1]
        return "\(monthName) \(day)"
    }

    private var comingSoonContent: some View {
        VStack {
            Spacer(minLength: 60)
            Text("Coming Soon")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.montraTextSecondary)
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    private var workoutsTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("UPCOMING WORKOUTS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                    .kerning(0.8)

                if upcomingPlannedWorkouts.isEmpty {
                    Text("No upcoming workouts planned yet.")
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)
                } else {
                    ForEach(Array(upcomingPlannedWorkouts.enumerated()), id: \.element.id) { index, workout in
                        WorkoutHistoryRow(session: workout, isUpcoming: true)
                        if index < upcomingPlannedWorkouts.count - 1 {
                            Divider()
                                .background(Color.montraDivider)
                        }
                    }
                }
            }
            .padding(18)
            .montraCard(radius: 16)

            VStack(alignment: .leading, spacing: 12) {
                Text("PREVIOUS WORKOUTS")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                    .kerning(0.8)

                ForEach(Array(previousWorkouts.enumerated()), id: \.element.id) { index, workout in
                    WorkoutHistoryRow(session: workout, isUpcoming: false)
                    if index < previousWorkouts.count - 1 {
                        Divider()
                            .background(Color.montraDivider)
                    }
                }
            }
            .padding(18)
            .montraCard(radius: 16)
        }
    }

    private var nutritionTabContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 14) {
                Text("NUTRITION PROFILE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                    .kerning(0.8)

                Picker("Goal", selection: $selectedNutritionGoal) {
                    ForEach(nutritionGoalOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Picker("Diet", selection: $selectedDietType) {
                    ForEach(dietTypeOptions, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(.menu)

                Text("Quick Preferences")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.montraTextSecondary)
                Toggle("Keto", isOn: $wantsKeto)
                Toggle("Gluten-Free", isOn: $wantsGlutenFree)
                Toggle("Lactose-Free", isOn: $wantsLactoseFree)
                Toggle("High-Protein", isOn: $wantsHighProtein)

                Toggle("Allergies", isOn: $hasAllergies)

                if hasAllergies {
                    TextField("Type your allergies (comma separated)", text: $allergyInputText, axis: .vertical)
                        .lineLimit(2...4)
                        .padding(12)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(18)
            .montraCard(radius: 16)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("WEEKLY MEAL SUGGESTIONS", systemImage: "fork.knife.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.montraTextPrimary)
                        .kerning(0.8)
                    Spacer()
                    Button {
                        refreshWeeklyMeals()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 11, weight: .bold))
                            Text("Refresh")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.montraOrange)
                    }
                }

                if !activeMealTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(activeMealTags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.montraOrange)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Color.montraOrange.opacity(0.14))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                ForEach(weeklyMealPlan) { dayPlan in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text(dayPlan.id)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.montraTextPrimary)
                            Spacer()
                            Text("Planned")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.montraOrange)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.montraOrange.opacity(0.14))
                                .clipShape(Capsule())
                        }

                        mealLine(icon: "sun.max.fill", label: "Breakfast", value: dayPlan.breakfast)
                        mealLine(icon: "sun.haze.fill", label: "Lunch", value: dayPlan.lunch)
                        mealLine(icon: "moon.stars.fill", label: "Dinner", value: dayPlan.dinner)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.09),
                                Color.white.opacity(0.04)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.montraCardBorder, lineWidth: 0.8)
                    )
                }

                HStack(spacing: 10) {
                    Button {
                        Task {
                            await requestMontraAISuggestions()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if isGeneratingAISuggestions {
                                ProgressView()
                                    .tint(.black)
                            }
                            Text(isGeneratingAISuggestions ? "Generating..." : "Use MONTRA AI")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(Color.montraOrange)
                        .clipShape(Capsule())
                    }
                    .disabled(isGeneratingAISuggestions)

                    Button {
                        refreshWeeklyMeals()
                    } label: {
                        Text("Shuffle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.montraTextPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                }

                Text(mealSuggestionNote)
                    .font(.system(size: 11))
                    .foregroundColor(.montraTextSecondary)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.orange)
                        .padding(.top, 1)
                    Text("AI-generated meal suggestions are general guidance and may be incorrect. Please verify ingredients, allergens, and suitability before consumption.")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.montraTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(18)
            .montraCard(radius: 16)

            VStack(alignment: .leading, spacing: 10) {
                Text("GENERIC ADVICE")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                    .kerning(0.8)

                ForEach(Array(nutritionAdvice.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.montraOrange)
                            .font(.system(size: 13))
                            .padding(.top, 2)
                        Text(tip)
                            .font(.system(size: 13))
                            .foregroundColor(.montraTextPrimary)
                    }
                }
            }
            .padding(18)
            .montraCard(radius: 16)

            if !nutritionWarnings.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("WATCH OUT")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.montraTextPrimary)
                        .kerning(0.8)

                    ForEach(Array(nutritionWarnings.enumerated()), id: \.offset) { _, warning in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                                .font(.system(size: 13))
                                .padding(.top, 2)
                            Text(warning)
                                .font(.system(size: 13))
                                .foregroundColor(.montraTextPrimary)
                        }
                    }
                }
                .padding(18)
                .montraCard(radius: 16)
            }
        }
    }

    @ViewBuilder
    private func mealLine(icon: String, label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.montraOrange)
                .frame(width: 14)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.montraTextSecondary)
                Text(value)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.montraTextPrimary)
            }
        }
    }
}

// MARK: - Progress Line Chart

struct ProgressLineChart: View {
    let data: [ProgressDataPoint]
    let yMax: Double

    private var xMax: Int { max(data.map(\.day).max() ?? 2, 2) }
    private var xMarks: [Int] {
        let step = max((xMax - 1) / 4, 1)
        return Array(stride(from: 1, through: xMax, by: step))
    }

    var body: some View {
        Chart {
            ForEach(data) { point in
                AreaMark(
                    x: .value("Day", point.day),
                    y: .value("Sessions", point.value)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color(hex: "#FF6A00").opacity(0.35),
                            Color(hex: "#FF6A00").opacity(0.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Day", point.day),
                    y: .value("Sessions", point.value)
                )
                .foregroundStyle(Color(hex: "#FF6A00"))
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Day", point.day),
                    y: .value("Sessions", point.value)
                )
                .foregroundStyle(Color(hex: "#FF6A00"))
                .symbolSize(30)
            }
        }
        .chartXAxis {
            AxisMarks(values: xMarks) { value in
                AxisValueLabel {
                    if let day = value.as(Int.self) {
                        let label = data.first(where: { $0.day == day })?.dayLabel ?? ""
                        Text(label)
                            .font(.system(size: 10))
                            .foregroundColor(Color(hex: "#8E8E93"))
                    }
                }
                AxisGridLine()
                    .foregroundStyle(Color.clear)
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisValueLabel()
                    .font(.caption)
                    .foregroundStyle(Color(hex: "#8E8E93"))
                AxisGridLine()
                    .foregroundStyle(Color.white.opacity(0.07))
            }
        }
        .chartYScale(domain: 0...yMax)
        .chartXScale(domain: 1...xMax)
    }
}

// MARK: - Stat Tile

struct ProgressStatTile: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
            Text(value)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.montraTextPrimary)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Color(hex: "#8E8E93"))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 4)
        .montraCard(radius: 14)
    }
}

struct WorkoutHistoryRow: View {
    let session: TrainerSessionRecord
    let isUpcoming: Bool

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: session.date)
    }

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(isUpcoming ? Color.montraOrange.opacity(0.2) : Color.green.opacity(0.2))
                .frame(width: 34, height: 34)
                .overlay(
                    Image(systemName: isUpcoming ? "calendar.badge.clock" : "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isUpcoming ? .montraOrange : .green)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(dateText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                Text("\(session.durationMin) min • \(session.calories) kcal")
                    .font(.system(size: 12))
                    .foregroundColor(.montraTextSecondary)
            }

            Spacer()

            Text(isUpcoming ? "Planned" : "Done")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isUpcoming ? .montraOrange : .green)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((isUpcoming ? Color.montraOrange : Color.green).opacity(0.12))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Achievement Row

struct AchievementRow: View {
    let achievement: Achievement

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(achievement.badgeColor)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: achievement.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(achievement.iconColor)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text(achievement.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                if let subtitle = achievement.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "#8E8E93"))
                }
            }

            Spacer()

            Text(achievement.date)
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#8E8E93"))
        }
    }
}

struct AllAchievementsSheet: View {
    let achievements: [Achievement]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(achievements.enumerated()), id: \.element.id) { index, achievement in
                        AchievementRow(achievement: achievement)
                        if index < achievements.count - 1 {
                            Divider()
                                .background(Color.montraDivider)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .padding(18)
                .montraCard(radius: 16)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .background(Color.montraBackground)
            .navigationTitle("All Achievements")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.montraOrange)
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    WorkoutProgressView()
}
