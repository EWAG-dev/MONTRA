import Foundation
import FirebaseAuth

@MainActor
final class AuthManager: ObservableObject {

    @Published private(set) var user: FirebaseAuth.User?
    @Published private(set) var userRole: UserRole = .unknown
    @Published private(set) var isCheckingAuth = true  // true only on cold start
    @Published private(set) var demoRole: UserRole? = nil  // set by demo login, bypasses Firebase

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

    // MARK: - Demo Mode

    func enableDemo(as role: UserRole) {
        demoRole = role
        isCheckingAuth = false
    }

    func disableDemo() {
        demoRole = nil
    }

    // MARK: - Auth Actions

    func signIn(email: String, password: String) async throws {
        try await Auth.auth().signIn(withEmail: email, password: password)
    }

    func createAccount(email: String, password: String) async throws {
        try await Auth.auth().createUser(withEmail: email, password: password)
    }

    func signOut() {
        try? Auth.auth().signOut()
        demoRole = nil
    }

    func sendPasswordReset(to email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }
}
