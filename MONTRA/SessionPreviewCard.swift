import SwiftUI

// MARK: - Model

struct SessionPreview: Decodable, Equatable {
    let sessionId: String
    let title: String
    let durationMin: Int
    let equipment: [String]
    let focusAreas: [String]
    let notes: String?
    let trainerName: String
    let trainerId: String
    let preparedAt: String
    let clientResponse: String?
    let startTime: String?

    var preparedAgoText: String {
        guard let date = ISO8601DateFormatter().date(from: preparedAt) else { return "Recently" }
        let mins = Int(-date.timeIntervalSinceNow / 60)
        if mins < 60 { return "\(mins) min ago" }
        let hrs = mins / 60
        if hrs < 24 { return "\(hrs) hour\(hrs == 1 ? "" : "s") ago" }
        return "\(hrs / 24) day\(hrs / 24 == 1 ? "" : "s") ago" }

    var isResponded: Bool { clientResponse != nil }
}

// MARK: - API

enum SessionPreviewAPI {
    static func fetch(token: String) async throws -> SessionPreview? {
        let base = LiveDataConnectivity.backendBaseURL
        var req = URLRequest(url: URL(string: "\(base)/api/client/session-preview")!)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, _) = try await URLSession.shared.data(for: req)
        let resp = try JSONDecoder().decode([String: SessionPreview?].self, from: data)
        return resp["preview"] ?? nil
    }

    static func respond(sessionId: String, response: String, token: String) async throws {
        let base = LiveDataConnectivity.backendBaseURL
        var req = URLRequest(url: URL(string: "\(base)/api/client/sessions/\(sessionId)/preview/respond")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["response": response])
        _ = try await URLSession.shared.data(for: req)
    }
}

// MARK: - Card

struct SessionPreviewCard: View {
    let preview: SessionPreview
    let onMessageCoach: () -> Void
    let onViewFullPlan: () -> Void
    var onRespond: ((String) -> Void)? = nil

    @State private var responded: String? = nil
    @State private var isResponding = false

    private let orange = Color.montraOrange
    private let focusIcons = ["figure.strengthtraining.traditional", "figure.flexibility",
                               "figure.run", "figure.core.training", "sportscourt",
                               "heart.fill", "bolt.fill"]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Header ─────────────────────────────────────────────
            HStack(spacing: 8) {
                Text("SESSION PREVIEW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.montraTextPrimary)
                    .kerning(0.8)
                Text("NEW")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(orange)
                    .clipShape(Capsule())
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider().background(Color.montraDivider)

            VStack(alignment: .leading, spacing: 14) {
                // ── Coach prepared label ────────────────────────────
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 14))
                        .foregroundColor(orange)
                    Text("Coach prepared your session")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.montraTextSecondary)
                }

                // ── Workout info ────────────────────────────────────
                VStack(alignment: .leading, spacing: 8) {
                    Text(preview.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.montraTextPrimary)

                    metaRow(icon: "clock", text: "Duration: \(preview.durationMin) min")

                    if !preview.equipment.isEmpty {
                        metaRow(icon: "dumbbell.fill",
                                text: "Equipment: \(preview.equipment.joined(separator: ", "))")
                    }

                    if !preview.focusAreas.isEmpty {
                        metaRow(icon: "scope",
                                text: "Focus: \(preview.focusAreas.joined(separator: ", "))")
                    }
                }

                // ── Prepared by ─────────────────────────────────────
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(orange.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Text(String(preview.trainerName.prefix(2)).uppercased())
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(orange)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            Text("Prepared by \(preview.trainerName)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.montraTextPrimary)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(orange)
                        }
                        Text(preview.preparedAgoText)
                            .font(.system(size: 12))
                            .foregroundColor(.montraTextSecondary)
                    }
                }

                // ── Focus area pills ────────────────────────────────
                if !preview.focusAreas.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("FOCUS AREAS")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.montraTextSecondary)
                            .kerning(0.8)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(preview.focusAreas.enumerated()), id: \.offset) { idx, area in
                                    HStack(spacing: 5) {
                                        Image(systemName: focusIcons[idx % focusIcons.count])
                                            .font(.system(size: 11))
                                            .foregroundColor(orange)
                                        Text(area)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.montraTextPrimary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 7)
                                    .background(Color.montraSurface)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(orange.opacity(0.25), lineWidth: 1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                }

                // ── Action buttons ──────────────────────────────────
                if let r = responded ?? preview.clientResponse {
                    HStack(spacing: 6) {
                        Image(systemName: r == "approved" ? "checkmark.circle.fill" : "pencil.circle.fill")
                            .foregroundColor(r == "approved" ? .green : orange)
                        Text(r == "approved" ? "You approved this session" : "Customization requested")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.montraTextSecondary)
                    }
                } else {
                    HStack(spacing: 8) {
                        actionButton(label: "Looks Good", icon: "checkmark.circle.fill", color: .green) {
                            respond("approved")
                        }
                        actionButton(label: "Customize", icon: "pencil", color: orange) {
                            respond("customize")
                        }
                        actionButton(label: "Message Coach", icon: "bubble.left.fill", color: Color(hex: "#3E9BD0")) {
                            onMessageCoach()
                        }
                    }
                }

                // ── Info note ───────────────────────────────────────
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.montraTextSecondary)
                    Text("Please review before your coach arrives.")
                        .font(.system(size: 12))
                        .foregroundColor(.montraTextSecondary)
                }

                Divider().background(Color.montraDivider)

                // ── View Full Plan ──────────────────────────────────
                Button(action: onViewFullPlan) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 14))
                        Text("View Full Plan")
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(orange)
                }
                .buttonStyle(.plain)
            }
            .padding(18)
        }
        .background(Color.montraSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(orange.opacity(0.35), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func metaRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.montraTextSecondary)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.montraTextSecondary)
        }
    }

    private func actionButton(label: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(color.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color.opacity(0.4), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(isResponding)
    }

    private func respond(_ r: String) {
        responded = r
        onRespond?(r)
    }
}
