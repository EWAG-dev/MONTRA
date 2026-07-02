import Foundation
import FirebaseAuth
import FirebaseCore

private func decodedImageData(from dataUrl: String?) -> Data {
    let trimmed = (dataUrl ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return Data() }

    let base64 = trimmed.components(separatedBy: ",").last ?? trimmed
    return Data(base64Encoded: base64) ?? Data()
}

@MainActor
final class AuthManager: ObservableObject {

     @Published private(set) var user: FirebaseAuth.User?
     @Published private(set) var userDisplayName: String = ""
     @Published private(set) var userRole: UserRole = .unknown
     @Published private(set) var isCheckingAuth = true   // true only on cold start

     // Trainer-only gate flags. Populated during refreshRole so they are always
     // authoritative by the time the splash exits. RootView reads these directly
     // instead of relying on local UserDefaults (which don't survive reinstalls).
     @Published private(set) var trainerAgreementSigned = false
     @Published private(set) var trainerOrientationCompleted = false

     enum UserRole {
         case unknown
         case user
         case trainer
      }

     private var stateHandle: AuthStateDidChangeListenerHandle?

     init() {
         stateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
             Task { @MainActor [weak self] in
                 guard let self else { return }
                 self.isCheckingAuth = true
                 self.user = firebaseUser
                 self.userDisplayName = firebaseUser?.displayName ?? ""
                 if let firebaseUser {
                     await self.refreshRole(for: firebaseUser)
                  } else {
                     self.userRole = .unknown
                     self.trainerAgreementSigned = false
                     self.trainerOrientationCompleted = false
                     self.isCheckingAuth = false
                  }
              }
          }
      }

    deinit {
        if let stateHandle {
            Auth.auth().removeStateDidChangeListener(stateHandle)
        }
    }

    // MARK: - Role Detection

    private func refreshRole(for user: FirebaseAuth.User) async {
        do {
            let result = try await user.getIDTokenResult(forcingRefresh: false)
            let role = result.claims["role"] as? String
            userRole = role == "trainer" ? .trainer : .user

            if userRole == .trainer {
                // Sync gate flags from the backend BEFORE isCheckingAuth goes false.
                // This guarantees the splash never exits until we know whether to show
                // the agreement / orientation screens.
                await syncTrainerGates(user: user, token: result.token)
            } else {
                await syncClientState(user: user, token: result.token)
            }
        } catch {
            userRole = .user
        }
        isCheckingAuth = false
    }

    // Fetches the trainer profile and updates gate flags. Failures are silent
    // (flags stay false → gates show, which is the safe fallback).
    private func syncTrainerGates(user: FirebaseAuth.User, token: String) async {
        guard let url = MontraAPIConfig.url(for: "/api/trainers/my-profile") else { return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        struct Response: Decodable {
            struct Trainer: Decodable {
                let agreementSigned: Bool?
                let orientationCompleted: Bool?
                let photoDataUrl: String?
            }
            let trainer: Trainer
        }

        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let payload = try? JSONDecoder().decode(Response.self, from: data) else { return }

        trainerAgreementSigned = payload.trainer.agreementSigned == true
        trainerOrientationCompleted = payload.trainer.orientationCompleted == true
          UserDefaults.standard.set(decodedImageData(from: payload.trainer.photoDataUrl), forKey: "trainerProfileImageData")

        // Mirror to UserDefaults so TrainerAgreementView / TrainerOrientationView
        // can read the values via their existing @AppStorage bindings.
        let uid = user.uid
        if trainerAgreementSigned {
            UserDefaults.standard.set(true, forKey: "trainer.agreementSigned")
            UserDefaults.standard.set(true, forKey: "trainer.agreementSigned.\(uid)")
        }
        if trainerOrientationCompleted {
            UserDefaults.standard.set(true, forKey: "trainer.orientationCompleted")
            UserDefaults.standard.set(true, forKey: "trainer.orientationCompleted.\(uid)")
        }
    }

    private func syncClientState(user: FirebaseAuth.User, token: String) async {
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "client.rematchRequested") {
            defaults.set(false, forKey: "onboarding.preAuthActive")
            defaults.set(false, forKey: "onboarding.completed")
            defaults.removeObject(forKey: "quiz.requestedTrainer")
            defaults.removeObject(forKey: "quiz.requestedTrainerName")
            return
        }

        guard let url = MontraAPIConfig.url(for: "/api/client/requests") else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        struct Response: Decodable {
            struct ClientRequest: Decodable {
                struct ClientProfile: Decodable {
                    let firstName: String?
                }

                let trainerId: String?
                let trainerName: String?
                let status: String?
                let clientProfile: ClientProfile?
            }

            let requests: [ClientRequest]
        }

        guard let (data, resp) = try? await URLSession.shared.data(for: request),
              let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode),
              let payload = try? JSONDecoder().decode(Response.self, from: data) else { return }

        let activeRequests = payload.requests.filter {
            ($0.status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != "declined"
        }
        let currentRequest = activeRequests.first {
            ($0.status ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "accepted"
        } ?? activeRequests.first

        defaults.set(false, forKey: "onboarding.preAuthActive")
        defaults.set(!activeRequests.isEmpty, forKey: "onboarding.completed")

        let firstName = currentRequest?.clientProfile?.firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !firstName.isEmpty {
            defaults.set(firstName, forKey: "quiz.firstName")
        }

        let trainerId = currentRequest?.trainerId?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trainerName = currentRequest?.trainerName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if trainerId.isEmpty {
            defaults.removeObject(forKey: "quiz.requestedTrainer")
            defaults.removeObject(forKey: "quiz.requestedTrainerName")
        } else {
            defaults.set(trainerId, forKey: "quiz.requestedTrainer")
            defaults.set(trainerName, forKey: "quiz.requestedTrainerName")
        }
    }

    // Called by TrainerAgreementView after the trainer accepts.
    func markAgreementSigned() {
        trainerAgreementSigned = true
        if let uid = user?.uid {
            UserDefaults.standard.set(true, forKey: "trainer.agreementSigned")
            UserDefaults.standard.set(true, forKey: "trainer.agreementSigned.\(uid)")
        }
    }

    // Called by TrainerOrientationView after the trainer finishes all videos.
    func markOrientationCompleted() {
        trainerOrientationCompleted = true
        if let uid = user?.uid {
            UserDefaults.standard.set(true, forKey: "trainer.orientationCompleted")
            UserDefaults.standard.set(true, forKey: "trainer.orientationCompleted.\(uid)")
        }
    }

    // MARK: - Auth Actions

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func createAccount(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw NSError(domain: "AuthManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No authenticated user found for verification email."])
        }
        // Reload first to reduce stale-session errors when immediately resending.
        try? await user.reload()
        if user.isEmailVerified {
            return
        }

        if let endpoint = MontraAPIConfig.url(for: "/api/auth/send-verification-email") {
            do {
                let token = try await user.getIDToken()
                var request = URLRequest(url: endpoint)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                request.httpBody = Data("{}".utf8)

                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                    return
                }

                let backendError = String(data: data, encoding: .utf8) ?? "Unknown backend error"
                throw NSError(
                    domain: "AuthManager",
                    code: -10,
                    userInfo: [NSLocalizedDescriptionKey: "Backend verification email error: \(backendError)"]
                )
            } catch {
                // Keep a Firebase fallback so verification still works if backend email service is unavailable.
                try await user.sendEmailVerification()
                return
            }
        }

        try await user.sendEmailVerification()
    }

    func refreshEmailVerificationStatus() async -> Bool {
        guard let current = Auth.auth().currentUser else { return false }

        do {
            try await current.reload()
            let refreshed = Auth.auth().currentUser
            user = refreshed
            userDisplayName = refreshed?.displayName ?? ""
            return refreshed?.isEmailVerified ?? false
        } catch {
            return current.isEmailVerified
        }
    }

    func applyEmailVerificationCode(_ code: String) async throws -> Bool {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NSError(domain: "AuthManager", code: -2, userInfo: [NSLocalizedDescriptionKey: "Verification code is empty."])
        }

        try await Auth.auth().applyActionCode(trimmed)
        return await refreshEmailVerificationStatus()
    }

    func applyEmailVerificationLink(_ link: String) async throws -> Bool {
        let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed) else {
            throw NSError(domain: "AuthManager", code: -3, userInfo: [NSLocalizedDescriptionKey: "Invalid verification link."])
        }

        let code = components.queryItems?.first(where: { $0.name == "oobCode" })?.value ?? ""
        return try await applyEmailVerificationCode(code)
    }

    func setUserDisplayName(_ name: String) async {
        guard let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest() else { return }
        changeRequest.displayName = name
        do {
            try await changeRequest.commitChanges()
            userDisplayName = name
        } catch {
            print("Failed to set display name: \(error.localizedDescription)")
        }
    }

    func signOut() {
        // Clear all user-scoped UserDefaults so the next login starts clean
        let keys = [
            "quiz.firstName",
            "quiz.goal",
            "quiz.experience",
            "quiz.location",
            "quiz.equipmentAccess",
            "quiz.injuries",
            "quiz.lifestyleDays",
            "quiz.stressLevel",
            "quiz.sleepRange",
            "quiz.nutritionHabits",
            "quiz.nutritionChallenges",
            "quiz.why",
            "quiz.accountability",
            "quiz.communicationStyle",
            "quiz.commitmentReadiness",
            "quiz.schedule",
            "quiz.frequency",
            "quiz.coachPreference",
            "quiz.requestedTrainer",
            "quiz.requestedTrainerName",
            "quiz.matchChecklistShown",
            "client.rematchRequested",
            "dashboardProfileImageData",
            "trainerProfileImageData",
            "onboarding.completed",
            "notif.unreadCount"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        userDisplayName = ""

        // Fire-and-forget: remove the device token so pushes stop after sign-out.
        if let user = Auth.auth().currentUser {
            Task {
                if let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) {
                    await PushNotificationManager.shared.deleteToken(authToken: tokenResult.token)
                }
            }
        }

        try? Auth.auth().signOut()
     }

    func sendPasswordReset(to email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func deleteAccount() async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await user.delete()
    }
}
