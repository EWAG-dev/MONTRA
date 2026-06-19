import SwiftUI

struct TrainerOrientationView: View {
    @AppStorage("trainer.orientationCompleted") private var orientationCompleted = false
    @State private var watched: Set<Int> = []

    private let videos: [(title: String, description: String)] = [
        ("Welcome to MONTRA",                  "An overview of the platform, how client matching works, and what your journey as a MONTRA coach looks like."),
        ("MONTRA Standards & Code of Conduct", "The professional standards, prohibited conduct rules, and values every MONTRA coach is held to."),
        ("Client Request & Session Flow",      "How to review match requests, accept clients, schedule sessions, and log session records correctly."),
        ("Safety, Liability & Scope of Practice", "Injury protocols, client screening, maintaining your CPR/AED cert, insurance requirements, and staying within your scope."),
        ("Communication & Professionalism",    "Response time expectations, how to message clients, handling rescheduling, and representing the MONTRA brand."),
    ]

    var allWatched: Bool { watched.count == videos.count }

    var body: some View {
        ZStack {
            Color.montraBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {

                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MONTRA")
                            .font(.system(size: 11, weight: .black))
                            .kerning(1.8)
                            .foregroundColor(.montraOrange)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.montraOrange.opacity(0.12))
                            .clipShape(Capsule())

                        Text("Trainer Orientation")
                            .font(.system(size: 30, weight: .black))
                            .foregroundColor(.montraTextPrimary)
                            .padding(.top, 8)

                        Text("Watch each orientation video before you start accepting clients. Tap each card to mark it as watched.")
                            .font(.system(size: 14))
                            .foregroundColor(.montraTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 64)
                    .padding(.bottom, 32)

                    // Progress bar
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("\(watched.count) of \(videos.count) completed")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.montraTextSecondary)
                            Spacer()
                            Text("\(Int(Double(watched.count) / Double(videos.count) * 100))%")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.montraOrange)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                                    .fill(Color.montraOrange)
                                    .frame(width: geo.size.width * (CGFloat(watched.count) / CGFloat(videos.count)), height: 6)
                                    .animation(.easeInOut(duration: 0.3), value: watched.count)
                            }
                        }
                        .frame(height: 6)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)

                    // Video cards
                    VStack(spacing: 12) {
                        ForEach(videos.indices, id: \.self) { i in
                            OrientationVideoCard(
                                index: i + 1,
                                title: videos[i].title,
                                description: videos[i].description,
                                isWatched: watched.contains(i)
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if watched.contains(i) { watched.remove(i) }
                                    else { watched.insert(i) }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // CTA
                    VStack(spacing: 12) {
                        Button {
                            guard allWatched else { return }
                            orientationCompleted = true
                        } label: {
                            Text(allWatched ? "Begin Taking Clients" : "Watch all videos to continue")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(allWatched ? .black : .montraTextSecondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(allWatched ? Color.montraOrange : Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .animation(.easeInOut(duration: 0.2), value: allWatched)
                        }
                        .disabled(!allWatched)

                        if !allWatched {
                            Text("Tap each card above to mark it as watched.")
                                .font(.system(size: 12))
                                .foregroundColor(.montraTextSecondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 32)
                    .padding(.bottom, 60)
                }
            }
        }
    }
}

// MARK: - Video Card

private struct OrientationVideoCard: View {
    let index: Int
    let title: String
    let description: String
    let isWatched: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Play / check icon
                ZStack {
                    Circle()
                        .fill(isWatched ? Color.montraOrange : Color.whipacity(0.08))
                        .frame(width: 44, height: 44)
                    Image(systemName: isWatched ? "checkmark" : "play.fill")
                        .font(.system(size: isWatched ? 15 : 12, weight: .bold))
                        .foregroundColor(isWatched ? .black : .montraOrange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("\(index). \(title)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.montraTextPrimary)
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.montraTextSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(16)
            .background(isWatched ? Color.montraOrange.opacity(0.08) : Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isWatched ? Color.montraOrange.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TrainerOrientationView()
}
