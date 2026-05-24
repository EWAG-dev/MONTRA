import SwiftUI

struct SessionDetailView: View {
    let session: SessionItem
    let onOpenCoachChat: () -> Void

    @State private var showTrainerProfile = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // ── Header card ───────────────────────────────────────
                HStack(spacing: 16) {
                    VStack(spacing: 2) {
                        Text(session.month)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.montraOrange)
                        Text("\(session.date)")
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(.montraTextPrimary)
                        Text(session.day)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.montraTextSecondary)
                    }
                    .frame(width: 58)
                    .padding(.vertical, 12)
                    .background(Color.montraBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 5) {
                        Text(session.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.montraTextPrimary)
                        Text("with \(session.trainer)")
                            .font(.system(size: 14))
                            .foregroundColor(.montraTextSecondary)
                        Text("\(session.time) – \(session.endTime)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.montraTextPrimary)
                        Text("In-home session")
                            .font(.system(size: 13))
                            .foregroundColor(.montraTextSecondary)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .montraCard(radius: 16)

                // ── Quick actions ─────────────────────────────────────
                HStack(spacing: 0) {
                    QuickActionButton(icon: "arrow.clockwise", label: "Reschedule") {}
                    QuickActionButton(icon: "bubble.left.fill", label: "Message", action: onOpenCoachChat)
                    QuickActionButton(icon: "note.text", label: "Session Notes") {}
                    QuickActionButton(icon: "calendar.badge.plus", label: "Calendar") {}
                }
                .montraCard(radius: 16)

                // ── What to Expect ────────────────────────────────────
                VStack(alignment: .leading, spacing: 14) {
                    Text("WHAT TO EXPECT")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.montraTextSecondary)
                        .kerning(1.2)

                    VStack(spacing: 0) {
                        DetailRow(icon: "figure.strengthtraining.traditional", label: "Focus",       value: session.focus)
                        DetailRow(icon: "clock.fill",                          label: "Duration",    value: "\(session.durationMin) min")
                        DetailRow(icon: "chart.bar.fill",                      label: "Level",       value: session.level)
                        DetailRow(icon: "dumbbell.fill",                       label: "Equipment",   value: session.equipment)
                        DetailRow(icon: "flame.fill",                          label: "Est. Calories", value: session.calories, isLast: true)
                    }
                }
                .padding(16)
                .montraCard(radius: 16)

                // ── Coach Provided Resources ──────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Text("COACH PROVIDED BEFORE SESSION")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.montraTextSecondary)
                        .kerning(1.2)

                    HStack(spacing: 10) {
                        PrepCard(
                            icon: "checklist",
                            title: "What to\nPrepare",
                            subtitle: "Coach equipment checklist",
                            status: "Awaiting Coach"
                        )
                        PrepCard(
                            icon: "clipboard.fill",
                            title: "Pre-Session\nQuestionnaire",
                            subtitle: "Coach intake form",
                            status: "Awaiting Coach"
                        )
                        PrepCard(
                            icon: "fork.knife",
                            title: "Nutrition\nGuide",
                            subtitle: "Coach meal guidance",
                            status: "Awaiting Coach"
                        )
                    }
                }

                // ── Your Trainer ──────────────────────────────────────
                VStack(alignment: .leading, spacing: 12) {
                    Text("YOUR TRAINER")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.montraTextSecondary)
                        .kerning(1.2)

                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color.montraOrange.opacity(0.2))
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(String(session.trainer.prefix(1)))
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.montraOrange)
                                )
                                .overlay(Circle().stroke(Color.montraOrange, lineWidth: 1.5))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.trainer)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.montraTextPrimary)
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.montraOrange)
                                    Text("4.9 (128)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.montraTextSecondary)
                                }
                                Text("Strength · HIIT · Mobility")
                                    .font(.system(size: 13))
                                    .foregroundColor(.montraTextSecondary)
                            }
                        }

                        HStack(spacing: 10) {
                            Button { showTrainerProfile = true } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 13))
                                    Text("View Profile")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.montraTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.montraBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Button(action: onOpenCoachChat) {
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble.left.fill")
                                        .font(.system(size: 13))
                                    Text("Message")
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .foregroundColor(.montraTextPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.montraBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(16)
                    .montraCard(radius: 16)
                }

                Spacer(minLength: 90)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
        }
        .background(Color.montraBackground)
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.montraBackground, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(isPresented: $showTrainerProfile) {
            TrainerProfileSheet(trainerName: session.trainer, onMessage: onOpenCoachChat)
        }
    }
}

// MARK: - Supporting Views

struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.montraOrange)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.montraTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
        }
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String
    var isLast: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.montraOrange)
                    .frame(width: 22)
                Text(label)
                    .font(.system(size: 14))
                    .foregroundColor(.montraTextPrimary)
                Spacer()
                Text(value)
                    .font(.system(size: 14))
                    .foregroundColor(.montraTextSecondary)
            }
            .padding(.vertical, 12)

            if !isLast {
                Divider().background(Color.montraDivider)
            }
        }
    }
}

struct PrepCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let status: String

    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.montraOrange)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.montraTextPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(subtitle)
                .font(.system(size: 11))
                .foregroundColor(.montraTextSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(status)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.montraOrange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.montraOrange.opacity(0.16))
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .montraCard(radius: 14)
    }
}

// MARK: - Trainer Profile Sheet

struct TrainerProfileSheet: View {
    let trainerName: String
    let onMessage: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var initials: String {
        trainerName.components(separatedBy: " ")
            .compactMap { $0.first }.prefix(2).map(String.init).joined()
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // ── Hero ───────────────────────────────────────────
                    VStack(spacing: 16) {
                        // Avatar
                        ZStack {
                            Circle()
                                .fill(Color.montraOrange.opacity(0.15))
                                .frame(width: 96, height: 96)
                            Text(initials)
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(.montraOrange)
                        }
                        .overlay(Circle().stroke(Color.montraOrange, lineWidth: 2))

                        VStack(spacing: 6) {
                            Text(trainerName)
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.montraTextPrimary)
                            Text("NASM Certified Personal Trainer")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.montraTextSecondary)

                            // Rating
                            HStack(spacing: 4) {
                                ForEach(0..<5) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.montraOrange)
                                }
                                Text("4.9")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.montraTextPrimary)
                                Text("(128 reviews)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.montraTextSecondary)
                            }

                            // Specialties chips
                            HStack(spacing: 8) {
                                ForEach(["Strength", "HIIT", "Mobility"], id: \.self) { tag in
                                    Text(tag)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.montraOrange)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color.montraOrange.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
                        }

                        // CTA buttons
                        HStack(spacing: 12) {
                            Button(action: onMessage) {
                                Label("Message", systemImage: "bubble.left.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.montraTextPrimary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.montraCardBorder, lineWidth: 0.8))
                            }
                            Button {
                                dismiss()
                            } label: {
                                Label("Book Session", systemImage: "calendar.badge.plus")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.montraOrange)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(24)
                    .padding(.top, 8)

                    // ── Stats row ──────────────────────────────────────
                    HStack(spacing: 0) {
                        TrainerStatPill(value: "200+", label: "Clients")
                        Divider().frame(height: 32).background(Color.montraCardBorder)
                        TrainerStatPill(value: "8+", label: "Years Exp.")
                        Divider().frame(height: 32).background(Color.montraCardBorder)
                        TrainerStatPill(value: "1,400+", label: "Sessions")
                        Divider().frame(height: 32).background(Color.montraCardBorder)
                        TrainerStatPill(value: "100%", label: "Response")
                    }
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.04))
                    .overlay(
                        Rectangle()
                            .stroke(Color.montraCardBorder, lineWidth: 0.6)
                    )

                    VStack(alignment: .leading, spacing: 24) {

                        // ── About ──────────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "ABOUT")
                            Text("Specialises in strength-focused programming for all fitness levels. Known for high-energy sessions and detailed form coaching. I work with clients in-home, outdoors, and virtually — whatever suits you best.")
                                .font(.system(size: 14))
                                .foregroundColor(.montraTextSecondary)
                                .lineSpacing(4)
                        }

                        // ── Available Programs ─────────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "AVAILABLE PROGRAMS")
                            VStack(spacing: 10) {
                                ForEach(trainerPrograms) { program in
                                    TrainerProgramRow(program: program)
                                }
                            }
                        }

                        // ── What I Offer ───────────────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "WHAT I OFFER")
                            LazyVGrid(
                                columns: [GridItem(.flexible()), GridItem(.flexible())],
                                spacing: 10
                            ) {
                                ForEach(trainerOfferings) { item in
                                    TrainerOfferingCard(item: item)
                                }
                            }
                        }

                        // ── Certifications ─────────────────────────────
                        VStack(alignment: .leading, spacing: 12) {
                            SectionHeader(title: "CERTIFICATIONS")
                            VStack(spacing: 8) {
                                ForEach(certifications, id: \.self) { cert in
                                    HStack(spacing: 10) {
                                        Image(systemName: "rosette")
                                            .font(.system(size: 14))
                                            .foregroundColor(.montraOrange)
                                        Text(cert)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.montraTextPrimary)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(14)
                            .background(Color.white.opacity(0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.montraCardBorder, lineWidth: 0.7))
                        }

                        Spacer(minLength: 60)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 22)
                }
            }
            .background(Color.montraBackground)
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

    // MARK: Data

    struct TrainerProgram: Identifiable {
        let id = UUID()
        let title: String
        let duration: String
        let frequency: String
        let focus: String
        let price: String
    }

    private let trainerPrograms: [TrainerProgram] = [
        .init(title: "Strength Builder",    duration: "8 weeks",  frequency: "3×/week", focus: "Progressive overload & muscle",      price: "$320"),
        .init(title: "HIIT Conditioning",   duration: "6 weeks",  frequency: "2×/week", focus: "Cardio endurance & fat burn",         price: "$240"),
        .init(title: "Mobility Reset",      duration: "4 weeks",  frequency: "2×/week", focus: "Recovery, posture & flexibility",     price: "$160"),
        .init(title: "Weight Loss Sprint",  duration: "6 weeks",  frequency: "3×/week", focus: "Full body fat loss & conditioning",   price: "$280"),
        .init(title: "Athletic Performance",duration: "10 weeks", frequency: "4×/week", focus: "Speed, power & sport conditioning",   price: "$480"),
    ]

    struct TrainerOffering: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
    }

    private let trainerOfferings: [TrainerOffering] = [
        .init(icon: "house.fill",              title: "In-Home Training"),
        .init(icon: "video.fill",              title: "Virtual Sessions"),
        .init(icon: "fork.knife",              title: "Nutrition Planning"),
        .init(icon: "chart.line.uptrend.xyaxis", title: "Progress Tracking"),
        .init(icon: "figure.run",              title: "Outdoor Training"),
        .init(icon: "doc.text.fill",           title: "Custom Programs"),
    ]

    private let certifications = [
        "NASM Certified Personal Trainer (CPT)",
        "NASM Corrective Exercise Specialist (CES)",
        "CPR/AED Certified",
        "TRX Functional Training",
    ]
}

// MARK: - Trainer Profile Sub-Views

private struct TrainerStatPill: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 17, weight: .black))
                .foregroundColor(.montraTextPrimary)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.montraTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TrainerProgramRow: View {
    let program: TrainerProfileSheet.TrainerProgram

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(program.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.montraTextPrimary)
                Text(program.focus)
                    .font(.system(size: 12))
                    .foregroundColor(.montraTextSecondary)
                HStack(spacing: 10) {
                    Label(program.duration, systemImage: "calendar")
                    Label(program.frequency, systemImage: "repeat")
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.montraTextSecondary)
            }
            Spacer()
            Text(program.price)
                .font(.system(size: 15, weight: .black))
                .foregroundColor(.montraOrange)
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13)
            .stroke(Color.montraCardBorder, lineWidth: 0.7))
    }
}

struct TrainerOfferingCard: View {
    let item: TrainerProfileSheet.TrainerOffering

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 15))
                .foregroundColor(.montraOrange)
                .frame(width: 22)
            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.montraTextPrimary)
                .lineLimit(1)
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11)
            .stroke(Color.montraCardBorder, lineWidth: 0.7))
    }
}
