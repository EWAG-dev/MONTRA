import Foundation
import FirebaseAuth
import FirebaseCore

@MainActor
final class AuthManager: ObservableObject {

     @Published private(set) var user: FirebaseAuth.User?
     @Published private(set) var userDisplayName: String = ""
     @Published private(set) var userRole: UserRole = .unknown
     @Published private(set) var isCheckingAuth = true   // true only on cold start

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
                 self.user = firebaseUser
                 self.userDisplayName = firebaseUser?.displayName ?? ""
                 if let firebaseUser {
                     await self.refreshRole(for: firebaseUser)
                  } else {
                     self.userRole = .unknown
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
        } catch {
            userRole = .user
        }
        isCheckingAuth = false
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
        if !user.isEmailVerified {
            try await user.sendEmailVerification()
        }
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
            "dashboardProfileImageData",
            "onboarding.completed"
        ]
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        userDisplayName = ""
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
