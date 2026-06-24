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
    @AppStorage("trainer.agreementSigned") private var trainerAgreementSigned = false
    @AppStorage("trainer.orientationCompleted") private var trainerOrientationCompleted = false
    @AppStorage("app.liveDataConnected") private var liveDataConnected = false
    @State private var splashDone = false
    @State private var hasRunConnectivityCheck = false

    var body: some View {
        Group {
            if !splashDone || auth.isCheckingAuth {
                MontraSplashView(showMatchingCard: preAuthOnboardingActive || !onboardingCompleted) {
                    splashDone = true
                }
            } else if auth.user == nil {
                LoginView()
            } else if auth.userRole == .trainer {
                if !trainerAgreementSigned {
                    TrainerAgreementView()
                } else if !trainerOrientationCompleted {
                    TrainerOrientationView()
                } else {
                    TrainerTabView()
                }
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
        .task(id: auth.userRole) {
            guard auth.userRole == .trainer, !trainerOrientationCompleted else { return }
            await syncOrientationStatusFromBackend()
        }
        .task(id: auth.user?.uid) {
            if auth.user != nil {
                // Request APNs permission when the user signs in.
                PushNotificationManager.shared.requestPermissionAndRegister()
            }
        }
    }

    @MainActor
    private func refreshLiveDataConnectivity() async {
        liveDataConnected = await LiveDataConnectivityProbe.detect()
    }

    @MainActor
    private func syncOrientationStatusFromBackend() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let url = MontraAPIConfig.url(for: "/api/trainers/my-profile") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(tokenResult.token)", forHTTPHeaderField: "Authorization")

        struct TrainerProfileResponse: Decodable {
            struct Trainer: Decodable { let orientationCompleted: Bool? }
            let trainer: Trainer
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let payload = try? JSONDecoder().decode(TrainerProfileResponse.self, from: data) else { return }

        if payload.trainer.orientationCompleted == true {
            trainerOrientationCompleted = true
        }
    }
}


