import SwiftUI

struct ContentView: View {
    @State private var selectedTab: Tab = .dashboard

    enum Tab {
        case dashboard, sessions, progress, messages
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                Color.montraBackground
                    .ignoresSafeArea()

                TabView(selection: $selectedTab) {
                    DashboardView(
                        selectedTab: $selectedTab,
                        onOpenCoachChat: { selectedTab = .messages }
                    )
                        .tag(Tab.dashboard)

                    SessionsView(onOpenCoachChat: { selectedTab = .messages })
                        .tag(Tab.sessions)

                    WorkoutProgressView()
                        .tag(Tab.progress)

                    CoachChatSheet()
                        .tag(Tab.messages)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                MontraTabBar(
                    selectedTab: $selectedTab,
                    onOpenCoachChat: { selectedTab = .messages }
                )
            }

        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Custom Tab Bar

struct MontraTabBar: View {
    @Binding var selectedTab: ContentView.Tab
    let onOpenCoachChat: () -> Void

    private let items: [(tab: ContentView.Tab, icon: String, label: String)] = [
        (.dashboard, "house.fill",       "Dashboard"),
        (.sessions,  "calendar",          "Sessions"),
        (.progress,  "chart.bar.fill",    "Progress"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.label) { item in
                Button {
                    selectedTab = item.tab
                } label: {
                    Image(systemName: item.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(selectedTab == item.tab ? .montraOrange : .montraTextSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            // Messages tab
            Button {
                selectedTab = .messages
            } label: {
                Image(systemName: "message.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(selectedTab == .messages ? .montraOrange : .montraTextSecondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
        }
        .padding(.bottom, 16)
        .background(
            Color.montraTabBarBackground
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.montraDivider),
                    alignment: .top
                )
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

struct MontraSplashView: View {
    @Environment(\.colorScheme) private var colorScheme
    let showMatchingCard: Bool
    let onFinish: () -> Void

    private var montraLogoAsset: String {
        colorScheme == .dark ? "MontraLogoDark" : "MontraLogoLight"
    }

    @State private var iconScale: CGFloat = 0.9
    @State private var iconOpacity: Double = 0.0
    @State private var orbitRotation: Double = 58
    @State private var done = false

    var body: some View {
        ZStack {
            ZStack {
                Color.montraBackground.ignoresSafeArea()

                // Subtle vertical beam texture behind content.
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.white.opacity(0.0),
                        Color.white.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blur(radius: 28)
                .opacity(0.25)
                .ignoresSafeArea()
            }

            GeometryReader { geometry in
                let metrics = SplashLayoutMetrics(geometry: geometry)

                VStack(spacing: 0) {
                    Spacer(minLength: metrics.topInset)

                    VStack(spacing: metrics.stackSpacing) {
                        Image(montraLogoAsset)
                            .resizable()
                            .scaledToFit()
                            .frame(height: metrics.logoHeight)

                        (
                            Text("Loading ")
                                .foregroundColor(.montraTextPrimary) +
                            Text("your MONTRA")
                                .foregroundColor(.montraOrange) +
                            Text(" experience...")
                                .foregroundColor(.montraTextPrimary)
                        )
                        .font(.system(size: metrics.titleSize, weight: .bold))

                        Text("Syncing your app data and preparing your dashboard.")
                            .font(.system(size: metrics.subtitleSize, weight: .medium))
                            .foregroundColor(.montraTextSecondary)
                            .multilineTextAlignment(.center)
                            .lineSpacing(metrics.subtitleLineSpacing)

                        ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.montraOrange.opacity(0.16), Color.clear],
                                center: .center,
                                startRadius: 26,
                                endRadius: metrics.orbitDiameter * 0.64
                            )
                        )
                        .frame(width: metrics.orbitDiameter + 42, height: metrics.orbitDiameter + 42)
                        .blur(radius: 14)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.12), Color.clear],
                                center: .center,
                                startRadius: 18,
                                endRadius: metrics.orbitDiameter * 0.58
                            )
                        )
                        .frame(width: metrics.orbitDiameter + 18, height: metrics.orbitDiameter + 18)
                        .blur(radius: 10)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.24), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.4
                        )
                        .shadow(color: Color.white.opacity(0.16), radius: 4)
                        .frame(width: metrics.orbitDiameter, height: metrics.orbitDiameter)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#FFD08A").opacity(0.95), Color.montraOrange.opacity(0.65)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.7
                        )
                        .shadow(color: Color.montraOrange.opacity(0.36), radius: 7)
                        .overlay(
                            Circle()
                                .stroke(Color.montraOrange.opacity(0.32), lineWidth: 3)
                                .blur(radius: 2.6)
                        )
                        .frame(width: metrics.innerOrbitDiameter, height: metrics.innerOrbitDiameter)

                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 1.1)
                        .shadow(color: Color.montraOrange.opacity(0.2), radius: 4.5)
                        .frame(width: metrics.coreHaloDiameter, height: metrics.coreHaloDiameter)

                    // Cohesive comet: bright head with a compact tapered tail.
                    ForEach(0..<9, id: \.self) { step in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color(hex: "#FFEFD5"), Color(hex: "#FFAF42")],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 7
                                )
                            )
                                .frame(width: max(3.5, metrics.orbitDiameter * 0.040 - CGFloat(step) * 0.75), height: max(3.5, metrics.orbitDiameter * 0.040 - CGFloat(step) * 0.75))
                            .opacity(0.74 - Double(step) * 0.07)
                            .blur(radius: CGFloat(step) * 0.16)
                                .offset(y: -(metrics.innerOrbitDiameter / 2))
                            .rotationEffect(.degrees(orbitRotation - Double(step) * 2.4))
                    }

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white, Color(hex: "#FFF4DF"), Color(hex: "#FFB24A")],
                                center: .center,
                                startRadius: 0.2,
                                endRadius: 7.2
                            )
                        )
                        .frame(width: max(10, metrics.orbitDiameter * 0.049), height: max(10, metrics.orbitDiameter * 0.049))
                        .shadow(color: Color(hex: "#FF8A2A").opacity(0.48), radius: 2.6)
                        .offset(y: -(metrics.innerOrbitDiameter / 2))
                        .rotationEffect(.degrees(orbitRotation))

                    Circle()
                        .fill(colorScheme == .light ? Color.montraBackground : Color(hex: "#111111"))
                        .frame(width: metrics.coreDiameter, height: metrics.coreDiameter)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.montraOrange.opacity(0.24), Color.clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: metrics.coreGlowDiameter / 2
                            )
                        )
                        .frame(width: metrics.coreGlowDiameter, height: metrics.coreGlowDiameter)
                        .blur(radius: 7)

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.white.opacity(0.12), Color.clear],
                                center: .topLeading,
                                startRadius: 0,
                                endRadius: metrics.coreDiameter * 0.56
                            )
                        )
                        .frame(width: metrics.coreDiameter - 4, height: metrics.coreDiameter - 4)

                    Text("M")
                        .font(.system(size: metrics.coreDiameter * 0.52, weight: .black, design: .default))
                        .foregroundColor(colorScheme == .light ? .black : .white)
                        .shadow(color: colorScheme == .light ? Color.black.opacity(0.08) : Color.white.opacity(0.14), radius: 2)

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#FFD08A"), .montraOrange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.2
                        )
                        .frame(width: metrics.coreDiameter, height: metrics.coreDiameter)
                        .shadow(color: .montraOrange.opacity(0.68), radius: 11)
                        .overlay(
                            Circle()
                                .stroke(Color(hex: "#FFD08A").opacity(0.28), lineWidth: 3.4)
                                .blur(radius: 2.4)
                        )
                        }
                    }
                    .frame(maxWidth: min(420, geometry.size.width - 24))

                    Spacer(minLength: max(metrics.bottomInset, 18))

                    if showMatchingCard {
                        SplashGuaranteeCard(metrics: metrics)
                            .padding(.horizontal, metrics.guaranteeOuterHorizontalPadding)
                            .padding(.bottom, max(metrics.bottomInset, 10))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .scaleEffect(iconScale)
                .opacity(iconOpacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.8)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }

            withAnimation(.linear(duration: 3.6).repeatForever(autoreverses: false)) {
                orbitRotation = 418
            }

            let finishDelay = 2.6
            DispatchQueue.main.asyncAfter(deadline: .now() + finishDelay) {
                guard !done else { return }
                done = true
                onFinish()
            }
        }
    }
}

private struct SplashLayoutMetrics {
    let stackSpacing: CGFloat
    let logoHeight: CGFloat
    let titleSize: CGFloat
    let subtitleSize: CGFloat
    let subtitleLineSpacing: CGFloat
    let orbitDiameter: CGFloat
    let innerOrbitDiameter: CGFloat
    let coreDiameter: CGFloat
    let coreHaloDiameter: CGFloat
    let coreGlowDiameter: CGFloat
    let checklistStackSpacing: CGFloat
    let checklistRowSpacing: CGFloat
    let checklistIndicatorSize: CGFloat
    let checklistSpinnerSize: CGFloat
    let checklistConnectorHeight: CGFloat
    let checklistTitleSize: CGFloat
    let checklistSubtitleSize: CGFloat
    let checklistHorizontalPadding: CGFloat
    let guaranteeOuterHorizontalPadding: CGFloat
    let guaranteeIconSize: CGFloat
    let guaranteeIconWidth: CGFloat
    let guaranteeTitleSize: CGFloat
    let guaranteeSubtitleSize: CGFloat
    let guaranteeHorizontalPadding: CGFloat
    let guaranteeVerticalPadding: CGFloat
    let guaranteeCornerRadius: CGFloat
    let topInset: CGFloat
    let bottomInset: CGFloat

    init(geometry: GeometryProxy) {
        let safeHeight = max(geometry.size.height - geometry.safeAreaInsets.top - geometry.safeAreaInsets.bottom, 1)
        let safeWidth = max(geometry.size.width, 1)
        let heightProgress = SplashLayoutMetrics.normalized(value: safeHeight, min: 620, max: 920)
        let widthProgress = SplashLayoutMetrics.normalized(value: safeWidth, min: 320, max: 430)
        let progress = min(heightProgress, widthProgress)

        let orbitTarget = SplashLayoutMetrics.interpolate(from: 188, to: 246, progress: progress)
        let orbitHeightLimit = safeHeight * SplashLayoutMetrics.interpolate(from: 0.27, to: 0.34, progress: progress)
        let orbitWidthLimit = safeWidth - SplashLayoutMetrics.interpolate(from: 56, to: 52, progress: progress)
        let resolvedOrbit = max(176, min(orbitTarget, orbitHeightLimit, orbitWidthLimit))

        stackSpacing = SplashLayoutMetrics.interpolate(from: 10, to: 18, progress: progress)
        logoHeight = SplashLayoutMetrics.interpolate(from: 44, to: 56, progress: progress)
        titleSize = SplashLayoutMetrics.interpolate(from: 18, to: 22, progress: progress)
        subtitleSize = SplashLayoutMetrics.interpolate(from: 13, to: 15, progress: progress)
        subtitleLineSpacing = SplashLayoutMetrics.interpolate(from: 4, to: 5, progress: progress)
        orbitDiameter = resolvedOrbit
        innerOrbitDiameter = max(132, resolvedOrbit - 44)
        coreDiameter = resolvedOrbit * (108.0 / 246.0)
        coreHaloDiameter = coreDiameter + SplashLayoutMetrics.interpolate(from: 30, to: 40, progress: progress)
        coreGlowDiameter = coreDiameter + SplashLayoutMetrics.interpolate(from: 24, to: 32, progress: progress)
        checklistStackSpacing = SplashLayoutMetrics.interpolate(from: 6, to: 8, progress: progress)
        checklistRowSpacing = SplashLayoutMetrics.interpolate(from: 12, to: 14, progress: progress)
        checklistIndicatorSize = SplashLayoutMetrics.interpolate(from: 22, to: 26, progress: progress)
        checklistSpinnerSize = SplashLayoutMetrics.interpolate(from: 16, to: 20, progress: progress)
        checklistConnectorHeight = SplashLayoutMetrics.interpolate(from: 20, to: 34, progress: progress)
        checklistTitleSize = SplashLayoutMetrics.interpolate(from: 15, to: 17, progress: progress)
        checklistSubtitleSize = SplashLayoutMetrics.interpolate(from: 11, to: 12.5, progress: progress)
        checklistHorizontalPadding = SplashLayoutMetrics.interpolate(from: 18, to: 24, progress: progress)
        guaranteeOuterHorizontalPadding = SplashLayoutMetrics.interpolate(from: 16, to: 22, progress: progress)
        guaranteeIconSize = SplashLayoutMetrics.interpolate(from: 26, to: 34, progress: progress)
        guaranteeIconWidth = SplashLayoutMetrics.interpolate(from: 42, to: 54, progress: progress)
        guaranteeTitleSize = SplashLayoutMetrics.interpolate(from: 13.5, to: 16, progress: progress)
        guaranteeSubtitleSize = SplashLayoutMetrics.interpolate(from: 11, to: 12.5, progress: progress)
        guaranteeHorizontalPadding = SplashLayoutMetrics.interpolate(from: 13, to: 16, progress: progress)
        guaranteeVerticalPadding = SplashLayoutMetrics.interpolate(from: 11, to: 14, progress: progress)
        guaranteeCornerRadius = SplashLayoutMetrics.interpolate(from: 16, to: 18, progress: progress)
        topInset = max(geometry.safeAreaInsets.top, SplashLayoutMetrics.interpolate(from: 8, to: 18, progress: progress))
        bottomInset = max(geometry.safeAreaInsets.bottom, SplashLayoutMetrics.interpolate(from: 6, to: 16, progress: progress))
    }

    private static func normalized(value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        guard max > min else { return 1 }
        return Swift.max(0, Swift.min(1, (value - min) / (max - min)))
    }

    private static func interpolate(from minValue: CGFloat, to maxValue: CGFloat, progress: CGFloat) -> CGFloat {
        minValue + ((maxValue - minValue) * progress)
    }
}

private struct SplashChecklistRow: View {
    let title: String
    let subtitle: String
    let isComplete: Bool
    let isActive: Bool
    let showConnector: Bool
    let metrics: SplashLayoutMetrics

    var body: some View {
        HStack(alignment: .center, spacing: metrics.checklistRowSpacing) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.montraOrange.opacity(isComplete ? 0.2 : 0.0))
                        .frame(width: metrics.checklistIndicatorSize + 6, height: metrics.checklistIndicatorSize + 6)

                    Circle()
                        .fill((isComplete || isActive) ? Color.montraOrange.opacity(isComplete ? 0.95 : 0.15) : Color.clear)
                        .frame(width: metrics.checklistIndicatorSize, height: metrics.checklistIndicatorSize)
                        .overlay(
                            Circle()
                                .stroke(isComplete ? Color.montraOrange : Color.montraOrange.opacity(0.45), lineWidth: 1.7)
                        )

                    if isActive {
                        Circle()
                            .trim(from: 0.06, to: 0.86)
                            .stroke(Color.montraOrange, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                            .frame(width: metrics.checklistSpinnerSize, height: metrics.checklistSpinnerSize)
                            .rotationEffect(.degrees(-90))
                            .shadow(color: Color.montraOrange.opacity(0.6), radius: 3)
                    } else if isComplete {
                        Circle()
                            .fill(Color.black.opacity(0.85))
                            .frame(width: metrics.checklistIndicatorSize * 0.32, height: metrics.checklistIndicatorSize * 0.32)
                    }
                }
                .frame(width: metrics.checklistIndicatorSize, height: metrics.checklistIndicatorSize)

                if showConnector {
                    Rectangle()
                        .fill((isComplete ? Color.montraOrange : Color.white.opacity(0.1)).opacity(0.85))
                        .frame(width: 2, height: metrics.checklistConnectorHeight)
                        .padding(.top, 4)
                        .overlay(
                            Rectangle()
                                .fill(Color.montraOrange.opacity(isComplete ? 0.45 : 0.0))
                                .frame(width: 4, height: metrics.checklistConnectorHeight)
                                .blur(radius: 2)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: metrics.checklistTitleSize, weight: .semibold))
                    .foregroundColor(.montraTextPrimary)
                Text(subtitle)
                    .font(.system(size: metrics.checklistSubtitleSize, weight: .medium))
                    .foregroundColor(.montraTextSecondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isComplete || isActive ? 1.0 : 0.42)
    }
}

private struct SplashGuaranteeCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let metrics: SplashLayoutMetrics

    var body: some View {
        HStack(spacing: metrics.checklistRowSpacing) {
            ZStack {
                Image(systemName: "shield")
                    .font(.system(size: metrics.guaranteeIconSize + 2, weight: .regular))
                    .foregroundColor(.montraOrange)
                Image(systemName: "checkmark")
                    .font(.system(size: metrics.guaranteeIconSize * 0.56, weight: .bold))
                    .foregroundColor(.montraOrange)
                    .offset(y: 2)
            }
            .frame(width: metrics.guaranteeIconWidth)

            VStack(alignment: .leading, spacing: 5) {
                Text("MATCHING BASED ON YOUR QUIZ")
                    .font(.system(size: metrics.guaranteeTitleSize, weight: .bold))
                    .foregroundColor(.montraOrange)

                Text("We rank trainer options using your goal, schedule, location, and preferences.")
                    .font(.system(size: metrics.guaranteeSubtitleSize, weight: .medium))
                    .foregroundColor(.montraTextSecondary)
                    .lineSpacing(2)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, metrics.guaranteeHorizontalPadding)
        .padding(.vertical, metrics.guaranteeVerticalPadding)
        .background(
            RoundedRectangle(cornerRadius: metrics.guaranteeCornerRadius)
                .fill(
                    LinearGradient(
                        colors: colorScheme == .light
                            ? [Color.montraAccentFrost, Color.montraAccentFrost.opacity(0.92)]
                            : [Color.black.opacity(0.72), Color.black.opacity(0.5)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.guaranteeCornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [Color.montraOrange.opacity(0.4), Color.montraOrange.opacity(0.18)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.1
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: metrics.guaranteeCornerRadius)
                        .stroke(Color.montraOrange.opacity(0.12), lineWidth: 3)
                        .blur(radius: 3)
                )
        )
        .shadow(color: Color.montraOrange.opacity(0.16), radius: 12, x: 0, y: 6)
    }
}

#Preview {
    ContentView()
}
