import SwiftUI

// MARK: - Metric explanation model

private struct ImpactMetric: Identifiable {
    let id = UUID()
    let icon: String
    let color: Color
    let title: String
    let subtitle: String
    let headline: String
    let body: String
    let why: String
}

// MARK: - Explanation sheet

private struct ImpactMetricSheet: View {
    let metric: ImpactMetric
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.montraTextSecondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(metric.color.opacity(0.15))
                            .frame(width: 72, height: 72)
                        Image(systemName: metric.icon)
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(metric.color)
                    }

                    // Title block
                    VStack(spacing: 6) {
                        Text(metric.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.montraTextPrimary)
                        Text(metric.subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(.montraTextSecondary)
                    }
                    .multilineTextAlignment(.center)

                    Divider()

                    // What it is
                    explanationBlock(
                        label: "WHAT IT IS",
                        icon: "info.circle.fill",
                        color: metric.color,
                        text: metric.headline
                    )

                    // How it works
                    explanationBlock(
                        label: "HOW IT WORKS",
                        icon: "arrow.triangle.2.circlepath",
                        color: metric.color,
                        text: metric.body
                    )

                    // Why it matters
                    explanationBlock(
                        label: "WHY IT MATTERS",
                        icon: "heart.fill",
                        color: metric.color,
                        text: metric.why
                    )

                    Spacer(minLength: 32)
                }
                .padding(.horizontal, 24)
            }
        }
        .background(Color.montraBackground.ignoresSafeArea())
    }

    private func explanationBlock(label: String, icon: String, color: Color, text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(color)
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(color)
                    .kerning(0.8)
            }
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.montraTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(color.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(color.opacity(0.15), lineWidth: 1)
                )
        )
    }
}

// MARK: - Community Impact summary view

struct ImpactSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var community: CommunityImpact?
    @State private var isLoading = true
    @State private var activeMetric: ImpactMetric?

    private let gold = Color(hex: "#C9A063")

    private var metrics: [ImpactMetric] {
        let c = community
        return [
            ImpactMetric(
                icon: "hands.and.sparkles.fill",
                color: Color(hex: "#E8772E"),
                title: "Impact Credits",
                subtitle: "\(number(c?.creditsActivated ?? 0)) Activated",
                headline: "An Impact Credit is a $10 giving token that every MONTRA client earns when they book their first intro session.",
                body: "When you complete your intro session, MONTRA automatically unlocks a $10 Impact Credit in your name. You choose where it goes — a cause you care about, back toward your coaching, a gift to someone else, or split between two purposes.",
                why: "We believe fitness is personal, but its ripple effect belongs to the whole community. Impact Credits make every first session mean something beyond the workout."
            ),
            ImpactMetric(
                icon: "person.3.fill",
                color: Color(hex: "#4CAF50"),
                title: "Directed to Causes",
                subtitle: "\(currency(c?.amountDirected ?? 0)) total",
                headline: "The real dollar amount that MONTRA clients have directed toward causes they care about.",
                body: "Each time a client directs their Impact Credit to donate, MONTRA commits that $10 to the chosen cause. This number is the running total of all credits directed to charitable causes across the entire MONTRA community.",
                why: "This isn't a marketing number — it's a live ledger. Every session that turns into a directed credit moves this number up. You can see exactly how much collective good has come from this community getting healthier."
            ),
            ImpactMetric(
                icon: "heart.fill",
                color: Color(hex: "#7E5BD0"),
                title: "Causes Supported",
                subtitle: "\(number(c?.causesSupported ?? 0)) active",
                headline: "The number of distinct causes that MONTRA clients have actively directed credits toward.",
                body: "MONTRA supports five cause areas: youth sports access, community fitness programs, mental wellness initiatives, survivor support funds, and community health. This count reflects how many of those causes have received directed credits from real clients.",
                why: "Diversity of impact matters. When the community supports multiple causes, MONTRA's mission reaches further — into schools, mental health programs, community centers, and beyond."
            ),
            ImpactMetric(
                icon: "person.3.sequence.fill",
                color: Color(hex: "#3E9BD0"),
                title: "Lives Impacted",
                subtitle: "\(number(c?.livesImpacted ?? 0)) people",
                headline: "An estimate of the real people reached by the causes MONTRA clients have supported.",
                body: "Each cause MONTRA works with reports an approximate reach per dollar directed — for example, a youth sports donation might fund one child's season of equipment and registration. MONTRA aggregates these estimates to produce this number.",
                why: "Putting a human number on giving makes it tangible. Every time you see this go up, it represents a real person whose day got a little better because someone in this community worked out and chose to share the impact."
            ),
            ImpactMetric(
                icon: "chart.line.uptrend.xyaxis",
                color: gold,
                title: "Stronger Communities",
                subtitle: "Built Together",
                headline: "The promise that sits behind every metric on this screen.",
                body: "Stronger Communities isn't a number — it's the outcome. When clients get healthier, coaches build sustainable practices, and Impact Credits flow to causes, the result is neighborhoods, families, and groups that are measurably more resilient.",
                why: "MONTRA exists because fitness shouldn't be a privilege. The coaches on this platform are building careers, the clients are building healthier lives, and together — through Impact Credits — they're building something that outlasts a single session."
            )
        ]
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    VStack(spacing: 4) {
                        Text("MONTRA COMMUNITY IMPACT")
                            .font(.system(size: 15, weight: .bold)).kerning(0.5)
                            .foregroundColor(.montraTextPrimary)
                        Text("Every transformation creates another opportunity for impact.")
                            .font(.system(size: 12)).foregroundColor(.montraTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 8)

                    if isLoading {
                        ProgressView().tint(gold).padding(.vertical, 40)
                    } else {
                        statGrid
                    }

                    taglineCard

                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(Color.montraBackground.ignoresSafeArea())
            .navigationTitle("Impact Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundColor(gold)
                }
            }
            .task { await load() }
            .sheet(item: $activeMetric) { metric in
                ImpactMetricSheet(metric: metric)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.hidden)
            }
        }
    }

    private var statGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(Array(metrics.enumerated()), id: \.element.id) { idx, metric in
                let isWide = idx == metrics.count - 1
                statTile(metric: metric)
                    .gridCellColumns(isWide ? 2 : 1)
            }
        }
    }

    private func statTile(metric: ImpactMetric) -> some View {
        Button { activeMetric = metric } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(metric.color).frame(width: 40, height: 40)
                    Image(systemName: metric.icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                }
                Text(valueText(for: metric))
                    .font(.system(size: 22, weight: .bold)).foregroundColor(metric.color)
                    .lineLimit(1).minimumScaleFactor(0.6)
                VStack(spacing: 0) {
                    Text(metric.title)
                        .font(.system(size: 12, weight: .semibold)).foregroundColor(.montraTextPrimary)
                    Text(subtitleText(for: metric))
                        .font(.system(size: 11)).foregroundColor(.montraTextSecondary)
                }
                .multilineTextAlignment(.center)

                // Tap hint
                HStack(spacing: 3) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 9))
                    Text("Learn more")
                        .font(.system(size: 10))
                }
                .foregroundColor(metric.color.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .padding(.horizontal, 10)
            .montraCard(radius: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // Extract the big display value from the subtitle string (first token)
    private func valueText(for metric: ImpactMetric) -> String {
        metric.subtitle.components(separatedBy: " ").first ?? metric.subtitle
    }

    // Everything after the first token is the subtitle line
    private func subtitleText(for metric: ImpactMetric) -> String {
        let parts = metric.subtitle.components(separatedBy: " ")
        return parts.dropFirst().joined(separator: " ")
    }

    private var taglineCard: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "hands.sparkles.fill").font(.system(size: 20)).foregroundColor(gold)
                Text("Train with purpose.\nTransform yourself.\nImpact others.")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(.montraTextPrimary)
                Spacer()
            }
            Text("At MONTRA, every workout is more than a session. It's a step toward a healthier you and a better world.")
                .font(.system(size: 12)).foregroundColor(.montraTextSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .montraCard(radius: 16)
    }

    private func load() async {
        defer { isLoading = false }
        community = try? await ImpactAPI.loadCommunity()
    }

    private func number(_ value: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    private func currency(_ value: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return "$" + (f.string(from: NSNumber(value: value)) ?? String(value))
    }
}
