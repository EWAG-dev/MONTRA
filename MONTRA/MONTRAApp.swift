import SwiftUI
import FirebaseCore

@main
struct MONTRAApp: App {

    @StateObject private var auth = AuthManager()

    init() {
        // Requires GoogleService-Info.plist in the MONTRA target folder.
        // Obtain from console.firebase.google.com → iOS app (bundle: com.montra.app).
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(auth)
                .preferredColorScheme(.dark)
        }
    }
}

// MARK: - Root Router

struct RootView: View {
    @EnvironmentObject private var auth: AuthManager
    @AppStorage("onboarding.completed") private var onboardingCompleted = false
    @State private var splashDone = false

    var body: some View {
        Group {
            if !splashDone || auth.isCheckingAuth {
                MontraSplashView {
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
    }
}


