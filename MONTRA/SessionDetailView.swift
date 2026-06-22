import SwiftUI

struct PublicTrainerWorkingHours: Decodable {
    let start: String?
    let end: String?
}

struct PublicTrainerProfile: Decodable {
    let id: String
    let name: String
    let certification: String
    let bio: String
    let specialties: [String]
    let rating: Double
    let reviewCount: Int
    let experienceYears: Int
    let cprCertification: String
    let photoDataUrl: String
    let availabilityDays: [String]
    let workingHours: PublicTrainerWorkingHours?
}

@MainActor
func fetchPublicTrainerProfile(trainerId: String) async -> PublicTrainerProfile? {
    guard !trainerId.isEmpty,
          let url = MontraAPIConfig.url(for: "/api/trainers/\(trainerId)") else { return nil }

    struct Response: Decodable { let trainer: PublicTrainerProfile }

    do {
        let (data, response) = try await URLSession.shared.data(for: URLRequest(url: url))
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
        return try JSONDecoder().decode(Response.self, from: data).trainer
    } catch {
        return nil
    }
}

struct SessionDetailView: View {
    let session: SessionItem
    let onOpenCoachChat: () -> Void

    @State private var showTrainerProfile = false
    @State private var trainerProfile: PublicTrainerProfile?

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
                                if let profile = trainerProfile {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.montraOrange)
                                        Text("\(String(format: "%.1f", profile.rating)) (\(profile.reviewCount))")
                                            .font(.system(size: 13))
                                            .foregroundColor(.montraTextSecondary)
                                    }
                                    if !profile.specialties.isEmpty {
                                        Text(profile.specialties.joined(separator: " · "))
                                            .font(.system(size: 13))
                                            .foregroundColor(.montraTextSecondary)
                                    }
                                } else {
                                    Text("Trainer details unavailable")
                                        .font(.system(size: 13))
                                        .foregroundColor(.montraTextSecondary)
                                }
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
        .task {
            guard let trainerId = session.trainerId else { return }
            trainerProfile = await fetchPublicTrainerProfile(trainerId: trainerId)
        }
        .sheet(isPresented: $showTrainerProfile) {
            TrainerProfileSheet(trainerName: session.trainer, profile: trainerProfile, onMessage: onOpenCoachChat)
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
    var profile: PublicTrainerProfile?
    let onMessage: () -> Void
    @Environment(\.dismiss) private var dismiss

    private var initials: String {
        trainerName.components(separatedBy: " ")
            .compactMap { $0.first }.prefix(2).map(String.init).joined()
    }

    private var certifications: [String] {
        var items: [String] = []
        if let cert = profile?.certification, !cert.isEmpty { items.append(cert) }
        if let cpr = profile?.cprCertification, !cpr.isEmpty { items.append(cpr) }
        return items
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

                            if let profile {
                                if !profile.certification.isEmpty {
                                    Text(profile.certification)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.montraTextSecondary)
                                }

                                // Rating
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 13))
                                        .foregroundColor(.montraOrange)
                                    Text(String(format: "%.1f", profile.rating))
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.montraTextPrimary)
                                    Text("(\(profile.reviewCount) reviews)")
                                        .font(.system(size: 13))
                                        .foregroundColor(.montraTextSecondary)
                                }

                                // Specialties chips
                                if !profile.specialties.isEmpty {
                                    HStack(spacing: 8) {
                                        ForEach(profile.specialties, id: \.self) { tag in
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
                            } else {
                                Text("Trainer details unavailable")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.montraTextSecondary)
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
                    if let profile, profile.experienceYears > 0 {
                        HStack(spacing: 0) {
                            TrainerStatPill(value: "\(profile.experienceYears)+", label: "Years Exp.")
                        }
                        .padding(.vertical, 16)
                        .background(Color.white.opacity(0.04))
                        .overlay(
                            Rectangle()
                                .stroke(Color.montraCardBorder, lineWidth: 0.6)
                        )
                    }

                    VStack(alignment: .leading, spacing: 24) {

                        // ── About ──────────────────────────────────────
                        VStack(alignment: .leading, spacing: 10) {
                            SectionHeader(title: "ABOUT")
                            Text((profile?.bio.isEmpty == false ? profile?.bio : nil) ?? "This trainer hasn't added a bio yet.")
                                .font(.system(size: 14))
                                .foregroundColor(.montraTextSecondary)
                                .lineSpacing(4)
                        }

                        // ── Certifications ─────────────────────────────
                        if !certifications.isEmpty {
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

