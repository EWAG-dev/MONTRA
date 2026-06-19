import SwiftUI

struct TrainerOrientationView: View {
    @AppStorage("trainer.orientationCompleted") private var orientationCompleted = false
    @State private var watched: Set<Int> = []

    private let videos: [(title: String, description: String, url: String)] = [
        ("Welcome to MONTRA",
         "An overview of the platform, how client matching works, and what your journey as a MONTRA coach looks like.",
         "https://drive.google.com/file/d/1Vt_2LoNYNNXzv0E6S_JxS9sBR1nVhLaC/view"),
        ("MONTRA Standards & Code of Conduct",
         "The professional standards, prohibited conduct rules, and values every MONTRA coach is held to.",
         "https://drive.google.com/file/d/1esOaU6tWSSNPqLmDt35g-3PIymFCN_tS/view"),
        ("Client Request & Session Flow",
         "How to review match requests, accept clients, schedule sessions, and log session records correctly.",
         "https://drive.google.com/file/d/1T62RymHKQP3d1RJk3w9_QzJ6bWrSJZIy/view"),
        ("Safety, Liability & Scope of Practice",
         "Injury protocols, client screening, maintaining your CPR/AED cert, insurance requirements, and staying within your scope.",
         "https://drive.google.com/file/d/1kVX3kzmFOS7CQ6pE0Xw77oJbuEFgGwnD/view"),
        ("Communication & Professionalism",
         "Response time expectations, how to message clients, handling rescheduling, and representing the MONTRA brand.",
         "https://drive.google.com/file/d/1nRDFo77-BR5jr2u7H1NvqkDVoaKeylQ2/view"),
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
                                url: videos[i].url,
                                isWatched: watched.contains(i)
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    watched.insert(i)
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
                            Text("Watch each video above — they'll be marked complete automatically.")
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
    let url: String
    let isWatched: Bool
    let onWatch: () -> Void

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 16) {
            // Check / number icon
            ZStack {
                Circle()
                    .fill(isWatched ? Color.montraOrange : Color.white.opacity(0.08))
                    .frame(width: 44, height: 44)
                if isWatched {
                    Image(systemName: "checkmark")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.black)
                } else {
                    Text("\(index)")
                        .font(.system(size: 14, weight: .black))
                        .foregroundColor(.montraTextSecondary)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.montraTextSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }

            Spacer()

            // Watch button
            Button {
                if let videoURL = URL(string: url) {
                    openURL(videoURL)
                }
                withAnimation(.easeInOut(duration: 0.2)) {
                    onWatch()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isWatched ? "checkmark" : "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text(isWatched ? "Done" : "Watch")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(isWatched ? .montraOrange : .black)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(isWatched ? Color.montraOrange.opacity(0.12) : Color.montraOrange)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(isWatched ? Color.montraOrange.opacity(0.06) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isWatched ? Color.montraOrange.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

#Preview {
    TrainerOrientationView()
}
