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
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 22, weight: .medium))
                        Text(item.label)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundColor(selectedTab == item.tab ? .montraOrange : .montraTextSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            // Messages tab
            Button {
                selectedTab = .messages
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 22, weight: .medium))
                    Text("Messages")
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundColor(selectedTab == .messages ? .montraOrange : .montraTextSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
        }
        .background(
            Color(hex: "#0C0C0C")
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(Color.montraDivider),
                    alignment: .top
                )
        )

    }
}

struct MontraSplashView: View {
    let onFinish: () -> Void

    private let iconDiameter: CGFloat = 88
    @State private var iconScale: CGFloat = 0.6
    @State private var iconOpacity: Double = 0.0
    @State private var glowRadius: CGFloat = 6
    @State private var done = false

    var body: some View {
        ZStack {
            Color.montraBackground.ignoresSafeArea()

            ZStack {
                // White ripple rings — staggered, each drives its own animation
                SplashRipple(delay: 0.45, diameter: iconDiameter, startOpacity: 0.45, lineWidth: 1.2)
                SplashRipple(delay: 0.75, diameter: iconDiameter, startOpacity: 0.30, lineWidth: 0.8)
                SplashRipple(delay: 1.05, diameter: iconDiameter, startOpacity: 0.18, lineWidth: 0.6)

                // Center: dark circle + bold M
                Circle()
                    .fill(Color.black)
                    .frame(width: iconDiameter, height: iconDiameter)

                Text("M")
                    .font(.system(size: 38, weight: .bold, design: .default))
                    .foregroundColor(.white)

                // Orange ring with glow — sits right on the icon edge
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FFD08A"),
                                Color.montraOrangeLight,
                                Color.montraOrange,
                                Color(hex: "#FFB24C")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: iconDiameter, height: iconDiameter)
                    .shadow(color: Color.montraOrangeLight.opacity(0.7), radius: glowRadius)
                    .shadow(color: Color.montraOrange.opacity(0.5), radius: glowRadius * 1.2)
            }
            .scaleEffect(iconScale)
            .opacity(iconOpacity)
        }
        .onAppear {
            // Pop icon in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                iconScale = 1.0
                iconOpacity = 1.0
            }
            // Pulse the orange glow
            withAnimation(.easeInOut(duration: 0.6).delay(0.2).repeatCount(2, autoreverses: true)) {
                glowRadius = 18
            }
            // Dismiss
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                guard !done else { return }
                done = true
                onFinish()
            }
        }
    }
}

// Each ring starts at the icon's diameter and expands outward, fading to nothing
private struct SplashRipple: View {
    let delay: Double
    let diameter: CGFloat
    let startOpacity: Double
    let lineWidth: CGFloat

    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.0

    var body: some View {
        Circle()
            .stroke(Color.white.opacity(opacity), lineWidth: lineWidth)
            .frame(width: diameter, height: diameter)
            .scaleEffect(scale)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    opacity = startOpacity
                    withAnimation(.easeOut(duration: 1.1)) {
                        scale = 4.2
                        opacity = 0.0
                    }
                }
            }
    }
}

#Preview {
    ContentView()
}
