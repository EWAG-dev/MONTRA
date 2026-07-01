import SwiftUI

struct TrainerOrientationView: View {
    var isReplay: Bool = false
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var watched: Set<Int> = []

    private let videos: [(title: String, description: String, url: String)] = [
        (
            "Welcome to MONTRA",
            "An overview of the platform, how client matching works, and what your journey as a MONTRA coach looks like.",
            "https://drive.google.com/file/d/1Vt_2LoNYNNXzv0E6S_JxS9sBR1nVhLaC/view"
        ),
        (
            "MONTRA Standards & Code of Conduct",
            "The professional standards, prohibited conduct rules, and values every MONTRA coach is held to.",
            "https://drive.google.com/file/d/1esOaU6tWSSNPqLmDt35g-3PIymFCN_tS/view"
        ),
        (
            "Client Request & Session Flow",
            "How to review match requests, accept clients, schedule sessions, and log session records correctly.",
            "https://drive.google.com/file/d/1T62RymHKQP3d1RJk3w9_QzJ6bWrSJZIy/view"
        ),
        (
            "Safety, Liability & Scope of Practice",
            "Injury protocols, client screening, CPR/AED cert, insurance requirements, and staying within your scope.",
            "https://drive.google.com/file/d/1kVX3kzmFOS7CQ6pE0Xw77oJbuEFgGwnD/view"
        ),
        (
            "Communication & Professionalism",
            "Response time expectations, messaging clients, handling rescheduling, and representing the MONTRA brand.",
            "https://drive.google.com/file/d/1nRDFo77-BR5jr2u7H1NvqkDVoaKeylQ2/view"
        ),
    ]

    private var allWatched: Bool { watched.count == videos.count }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.montraBackground.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    headerSection
                    progressSection
                    videoSection
                    if !isReplay {
                        ctaSection
                    }
                }
            }
            if isReplay {
                closeButton
            }
        }
        .task(id: auth.user?.uid) {
            loadWatchedState()
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.montraTextSecondary)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.08))
                .clipShape(Circle())
        }
        .padding(.top, 56)
        .padding(.trailing, 24)
    }

    private var headerSection: some View {
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
            Text("Watch each orientation video before you start accepting clients.")
                .font(.system(size: 14))
                .foregroundColor(.montraTextSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 24)
        .padding(.top, 64)
        .padding(.bottom, 32)
    }

    private var progressSection: some View {
        let total = videos.count
        let done = watched.count
        let pct = total > 0 ? Int(Double(done) / Double(total) * 100) : 0
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(done) of \(total) completed")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.montraTextSecondary)
                Spacer()
                Text("\(pct)%")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.montraOrange)
            }
            GeometryReader { geo in
                let fillWidth: CGFloat = total > 0 ? geo.size.width * CGFloat(done) / CGFloat(total) : 0
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(Color.white.opacity(0.08)).frame(height: 6)
                    RoundedRectangle(cornerRadius: 3).fill(Color.montraOrange).frame(width: fillWidth, height: 6)
                }
            }
            .frame(height: 6)
            .animation(Animation.easeInOut(duration: 0.3), value: done)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var videoSection: some View {
        VStack(spacing: 12) {
            ForEach(videos.indices, id: \.self) { i in
                OrientationVideoCard(
                    index: i + 1,
                    title: videos[i].title,
                    description: videos[i].description,
                    url: videos[i].url,
                    isWatched: watched.contains(i)
                ) {
                    watched.insert(i)
                    persistWatchedState()
                }
            }
        }
        .padding(.horizontal, 24)
    }

    private var ctaSection: some View {
        VStack(spacing: 12) {
            ctaButton
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

    private var ctaButton: some View {
        let label: String = allWatched ? "Begin Taking Clients" : "Watch all videos to continue"
        let fg: Color = allWatched ? .black : .montraTextSecondary
        let bg: Color = allWatched ? .montraOrange : Color.white.opacity(0.08)
        return Button {
            guard allWatched else { return }
            markOrientationCompleted()
            Task { await syncOrientationCompletion() }
        } label: {
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(fg)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(bg)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!allWatched)
        .animation(Animation.easeInOut(duration: 0.2), value: allWatched)
    }

    private func markOrientationCompleted() {
        auth.markOrientationCompleted()
        if let uid = auth.user?.uid {
            UserDefaults.standard.removeObject(forKey: "trainer.orientationWatched.\(uid)")
        }
    }

    private func loadWatchedState() {
        guard let uid = auth.user?.uid else {
            watched = []
            return
        }

        let key = "trainer.orientationWatched.\(uid)"
        guard let raw = UserDefaults.standard.string(forKey: key), !raw.isEmpty else {
            watched = []
            return
        }

        let values = raw
            .split(separator: ",")
            .compactMap { Int($0) }
            .filter { $0 >= 0 && $0 < videos.count }
        watched = Set(values)
    }

    private func persistWatchedState() {
        guard let uid = auth.user?.uid else { return }
        let key = "trainer.orientationWatched.\(uid)"
        let raw = watched.sorted().map(String.init).joined(separator: ",")
        UserDefaults.standard.set(raw, forKey: key)
    }

    private func syncOrientationCompletion() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let url = MontraAPIConfig.url(for: "/api/trainers/my-profile/orientation-complete") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(tokenResult.token)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: request)
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
            circleIcon
            infoStack
            Spacer()
            watchButton
        }
        .padding(16)
        .background(isWatched ? Color.montraOrange.opacity(0.06) : Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(isWatched ? Color.montraOrange.opacity(0.35) : Color.white.opacity(0.08), lineWidth: 1)
        )
        .animation(Animation.easeInOut(duration: 0.2), value: isWatched)
    }

    private var circleIcon: some View {
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
    }

    private var infoStack: some View {
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
    }

    private var watchButton: some View {
        let icon: String = isWatched ? "checkmark" : "play.fill"
        let label: String = isWatched ? "Done" : "Watch"
        let fg: Color = isWatched ? .montraOrange : .black
        let bg: Color = isWatched ? Color.montraOrange.opacity(0.12) : .montraOrange
        return Button {
            if let videoURL = URL(string: url) { openURL(videoURL) }
            onWatch()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
                Text(label).font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(fg)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(bg)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TrainerOrientationView()
        .environmentObject(AuthManager())
}
