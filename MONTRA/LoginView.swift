import SwiftUI

struct LoginView: View {

    @EnvironmentObject private var auth: AuthManager
    @AppStorage("onboarding.completed") private var onboardingCompleted = false

    @State private var isSignUp = false
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showForgotPassword = false
    @State private var forgotEmail = ""
    @State private var resetSent = false

    var body: some View {
        ZStack {
            Color.montraBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: Logo
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(hex: "#FFCE7A"), Color(hex: "#FF6820"), Color(hex: "#FF9C40")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 2
                                )
                                .frame(width: 72, height: 72)
                            Image("MontraLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 38, height: 38)
                        }
                        .padding(.bottom, 4)

                        Image("MontraLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 44)
                            .padding(.top, 4)

                        Text("Your personal training platform")
                            .font(.system(size: 14))
                            .foregroundColor(.montraTextSecondary)
                    }
                    .padding(.top, 72)
                    .padding(.bottom, 48)

                    // MARK: Form
                    VStack(spacing: 14) {

                        // Sign In / Sign Up toggle pills
                        HStack(spacing: 0) {
                            ForEach(["Sign In", "Create Account"], id: \.self) { label in
                                let active = (label == "Sign In") == !isSignUp
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isSignUp = label == "Create Account"
                                        errorMessage = nil
                                    }
                                } label: {
                                    Text(label)
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(active ? .black : .montraTextSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(active ? Color(hex: "#FF6820") : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding(4)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                        .padding(.bottom, 6)

                        // Email
                        MontraInputField(placeholder: "Email address", text: $email, keyboardType: .emailAddress, isSecure: false)

                        // Password
                        MontraInputField(placeholder: "Password", text: $password, keyboardType: .default, isSecure: true)

                        // Confirm password (sign up only)
                        if isSignUp {
                            MontraInputField(placeholder: "Confirm password", text: $confirmPassword, keyboardType: .default, isSecure: true)
                        }

                        // Error message
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 13))
                                .foregroundColor(Color(hex: "#FF6B6B"))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 4)
                        }

                        // Primary action button
                        Button {
                            Task { await submit() }
                        } label: {
                            ZStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.black)
                                } else {
                                    Text(isSignUp ? "Create Account" : "Sign In")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.black)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color(hex: "#FF6820"))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(isLoading)
                        .padding(.top, 4)

                        // Forgot password (sign in only)
                        if !isSignUp {
                            Button {
                                forgotEmail = email
                                resetSent = false
                                showForgotPassword = true
                            } label: {
                                Text("Forgot password?")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.montraTextSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)

                    // MARK: Demo Buttons
                    VStack(spacing: 10) {
                        Text("Try a demo")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color.white.opacity(0.25))
                            .kerning(0.5)

                        HStack(spacing: 10) {
                            Button {
                                onboardingCompleted = true
                                auth.enableDemo(as: .user)
                            } label: {
                                Text("Client")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.montraTextSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                            }
                            Button {
                                auth.enableDemo(as: .trainer)
                            } label: {
                                Text("Trainer")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.montraTextSecondary)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.1), lineWidth: 0.8))
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Text("Powered by Elite Home Fitness")
                .font(.system(size: 11))
                .foregroundColor(Color.white.opacity(0.25))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 16)
        }
        .sheet(isPresented: $showForgotPassword) {
            ForgotPasswordSheet(email: $forgotEmail, resetSent: $resetSent)
                .environmentObject(auth)
        }
    }

    // MARK: - Submit

    private func submit() async {
        errorMessage = nil
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPassword = password

        guard !trimmedEmail.isEmpty, !trimmedPassword.isEmpty else {
            errorMessage = "Please enter your email and password."
            return
        }

        if isSignUp {
            guard trimmedPassword == confirmPassword else {
                errorMessage = "Passwords don't match."
                return
            }
            guard trimmedPassword.count >= 8 else {
                errorMessage = "Password must be at least 8 characters."
                return
            }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            if isSignUp {
                try await auth.createAccount(email: trimmedEmail, password: trimmedPassword)
            } else {
                try await auth.signIn(email: trimmedEmail, password: trimmedPassword)
            }
        } catch {
            errorMessage = firebaseErrorMessage(error)
        }
    }

    private func firebaseErrorMessage(_ error: Error) -> String {
        let code = (error as NSError).code
        switch code {
        case 17011: return "No account found with that email."
        case 17009: return "Incorrect password. Please try again."
        case 17007: return "An account with this email already exists."
        case 17008: return "Please enter a valid email address."
        case 17026: return "Password must be at least 6 characters."
        case 17010: return "Too many attempts. Please try again later."
        default:    return error.localizedDescription
        }
    }
}

// MARK: - Reusable Input Field

struct MontraInputField: View {
    let placeholder: String
    @Binding var text: String
    let keyboardType: UIKeyboardType
    let isSecure: Bool

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    .keyboardType(keyboardType)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }
        }
        .font(.system(size: 15))
        .foregroundColor(.montraTextPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.montraCardBorder, lineWidth: 0.8)
        )
    }
}

// MARK: - Forgot Password Sheet

struct ForgotPasswordSheet: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @Binding var email: String
    @Binding var resetSent: Bool
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if resetSent {
                    VStack(spacing: 12) {
                        Image(systemName: "envelope.badge.checkmark.fill")
                            .font(.system(size: 48))
                            .foregroundColor(Color(hex: "#FF6820"))
                        Text("Check your email")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.montraTextPrimary)
                        Text("We sent a password reset link to\n\(email)")
                            .font(.system(size: 14))
                            .foregroundColor(.montraTextSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enter your email address and we'll send you a link to reset your password.")
                            .font(.system(size: 14))
                            .foregroundColor(.montraTextSecondary)
                    }
                    .padding(.top, 8)

                    MontraInputField(placeholder: "Email address", text: $email, keyboardType: .emailAddress, isSecure: false)

                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 13))
                            .foregroundColor(Color(hex: "#FF6B6B"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Button {
                        Task {
                            isLoading = true
                            do {
                                try await auth.sendPasswordReset(to: email.trimmingCharacters(in: .whitespacesAndNewlines))
                                resetSent = true
                            } catch {
                                errorMessage = error.localizedDescription
                            }
                            isLoading = false
                        }
                    } label: {
                        ZStack {
                            if isLoading { ProgressView().tint(.black) }
                            else { Text("Send Reset Link").font(.system(size: 15, weight: .bold)).foregroundColor(.black) }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(hex: "#FF6820"))
                        .clipShape(RoundedRectangle(cornerRadius: 13))
                    }
                    .disabled(isLoading)
                }

                Spacer()
            }
            .padding(.horizontal, 24)
            .background(Color.montraBackground.ignoresSafeArea())
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundColor(Color(hex: "#FF6820"))
                }
            }
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager())
}
