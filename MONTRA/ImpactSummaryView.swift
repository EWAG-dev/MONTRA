import SwiftUI

/// The "MONTRA Community Impact" panel — aggregate totals from real directed
/// credits (GET /api/impact/community), shown as a sheet.
struct ImpactSummaryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var community: CommunityImpact?
    @State private var isLoading = true

    private let gold = Color(hex: "#C9A063")

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
        }
    }

    private var statGrid: some View {
        let c = community
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            statTile(value: currency(c?.amountDirected ?? 0), title: "Directed to Causes", subtitle: "Through Impact Credits",
                     icon: "person.3.fill", color: Color(hex: "#4CAF50"))
            statTile(value: number(c?.creditsActivated ?? 0), title: "Impact Credits", subtitle: "Activated",
                     icon: "hands.and.sparkles.fill", color: Color(hex: "#E8772E"))
            statTile(value: number(c?.causesSupported ?? 0), title: "Causes", subtitle: "Supported",
                     icon: "heart.fill", color: Color(hex: "#7E5BD0"))
            statTile(value: number(c?.livesImpacted ?? 0), title: "Lives", subtitle: "Impacted",
                     icon: "person.3.sequence.fill", color: Color(hex: "#3E9BD0"))
            statTile(value: "Stronger", title: "Communities", subtitle: "Built Together",
                     icon: "chart.line.uptrend.xyaxis", color: gold)
                .gridCellColumns(2)
        }
    }

    private func statTile(value: String, title: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            ZStack {
                Circle().fill(color).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
            }
            Text(value).font(.system(size: 22, weight: .bold)).foregroundColor(color)
                .lineLimit(1).minimumScaleFactor(0.6)
            VStack(spacing: 0) {
                Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(.montraTextPrimary)
                Text(subtitle).font(.system(size: 11)).foregroundColor(.montraTextSecondary)
            }
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .padding(.horizontal, 10)
        .montraCard(radius: 16)
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
