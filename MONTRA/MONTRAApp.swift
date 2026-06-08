import SwiftUI
import FirebaseCore

@main
struct MONTRAApp: App {

    @StateObject private var auth = AuthManager()
    @AppStorage("app.appearanceMode") private var appearanceMode: String = "dark"

    init() {
        // Requires GoogleService-Info.plist in the MONTRA target folder.
        // Obtain from console.firebase.google.com -> iOS app (bundle: com.elitehomefitness.montra).
        if FirebaseApp.app() == nil {
            if
                let configPath = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
                let options = FirebaseOptions(contentsOfFile: configPath)
            {
                FirebaseApp.configure(options: options)
            } else {
                print("[MONTRA] Firebase config missing. App will run without Firebase until configured.")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(preferredColorScheme)
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch appearanceMode {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

// MARK: - Root Router

struct RootView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("onboarding.completed") private var onboardingCompleted = false
    @AppStorage("onboarding.preAuthActive") private var preAuthOnboardingActive = false
    @AppStorage("app.liveDataConnected") private var liveDataConnected = false
    @State private var splashDone = false
    @State private var hasRunConnectivityCheck = false

    var body: some View {
        Group {
            if !splashDone || auth.isCheckingAuth {
                MontraSplashView(showMatchingCard: preAuthOnboardingActive || !onboardingCompleted) {
                    splashDone = true
                }
            } else if auth.user == nil && auth.demoRole == nil {
                LoginView()
            } else if auth.userRole == .trainer || auth.demoRole == .trainer {
                TrainerTabView()
            } else if !onboardingCompleted {
                OnboardingQuizView()
            } else {
                ContentView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: splashDone)
        .animation(.easeInOut(duration: 0.25), value: auth.user == nil)
        .animation(.easeInOut(duration: 0.25), value: onboardingCompleted)
        .task {
            guard !hasRunConnectivityCheck else { return }
            hasRunConnectivityCheck = true
            await refreshLiveDataConnectivity()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                await refreshLiveDataConnectivity()
            }
        }
    }

    @MainActor
    private func refreshLiveDataConnectivity() async {
        liveDataConnected = await LiveDataConnectivityProbe.detect()
    }
}


