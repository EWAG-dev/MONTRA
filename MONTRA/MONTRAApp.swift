import SwiftUI
import FirebaseCore

@main
struct MONTRAApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
    // Prevents flashing the agreement/orientation gate before we've had a chance
    // to confirm from the backend that the trainer already completed them.
    @State private var trainerGatesReady = false

    var body: some View {
        Group {
            if !splashDone || auth.isCheckingAuth {
                MontraSplashView(showMatchingCard: preAuthOnboardingActive || !onboardingCompleted) {
                    splashDone = true
                }
            } else if auth.user == nil {
                LoginView()
            } else if auth.userRole == .trainer {
                if !trainerGatesReady {
                    // Brief pause while we confirm gate status from the backend.
                    // Avoids flashing the agreement screen on a fresh install when
                    // the trainer has already signed remotely.
                    ZStack {
                        Color.montraBackground.ignoresSafeArea()
                        ProgressView().tint(.montraOrange)
                    }
                } else if !trainerAgreementSigned {
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
            guard auth.userRole == .trainer else { return }
            await syncTrainerGatesFromBackend()
            trainerGatesReady = true
        }
        .task(id: auth.user?.uid) {
            // Reset gate-ready so the sync runs fresh on each sign-in.
            if auth.user == nil { trainerGatesReady = false }
            hydrateTrainerProgressFromScopedStorage()
            if auth.user != nil {
                PushNotificationManager.shared.requestPermissionAndRegister()
            }
        }
    }

    @MainActor
    private func refreshLiveDataConnectivity() async {
        liveDataConnected = await LiveDataConnectivityProbe.detect()
    }

    // Fetches the trainer's profile from the backend and updates the local gate
    // flags from the authoritative server state. Called on every sign-in before
    // any gate screen is shown.
    @MainActor
    private func syncTrainerGatesFromBackend() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false),
              let url = MontraAPIConfig.url(for: "/api/trainers/my-profile") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(tokenResult.token)", forHTTPHeaderField: "Authorization")

        struct TrainerProfileResponse: Decodable {
            struct Trainer: Decodable {
                let orientationCompleted: Bool?
                let agreementSigned: Bool?
            }
            let trainer: Trainer
        }

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let payload = try? JSONDecoder().decode(TrainerProfileResponse.self, from: data) else { return }

        let uid = auth.user?.uid
        if payload.trainer.orientationCompleted == true {
            trainerOrientationCompleted = true
            if let uid { UserDefaults.standard.set(true, forKey: "trainer.orientationCompleted.\(uid)") }
        }
        if payload.trainer.agreementSigned == true {
            trainerAgreementSigned = true
            if let uid { UserDefaults.standard.set(true, forKey: "trainer.agreementSigned.\(uid)") }
        }
    }

    private func hydrateTrainerProgressFromScopedStorage() {
        guard let uid = auth.user?.uid else { return }

        let defaults = UserDefaults.standard
        if let scopedAgreement = defaults.object(forKey: "trainer.agreementSigned.\(uid)") as? Bool {
            trainerAgreementSigned = scopedAgreement
        } else if trainerAgreementSigned {
            defaults.set(true, forKey: "trainer.agreementSigned.\(uid)")
        }

        if let scopedOrientation = defaults.object(forKey: "trainer.orientationCompleted.\(uid)") as? Bool {
            trainerOrientationCompleted = scopedOrientation
        } else if trainerOrientationCompleted {
            defaults.set(true, forKey: "trainer.orientationCompleted.\(uid)")
        }
    }
}


