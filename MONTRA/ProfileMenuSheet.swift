import SwiftUI
import PhotosUI

struct ProfileMenuSheet: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss

    let isClient: Bool

    @AppStorage("dashboardProfileImageData") private var profileImageData: Data = Data()
    @AppStorage("quiz.firstName") private var quizFirstName: String = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var showPersonalInfo      = false
    @State private var showNotificationPrefs = false

    private var displayName: String {
        isClient ? (quizFirstName.isEmpty ? "Member" : quizFirstName) : "Alex Morgan"
    }

    private var roleLabel: String {
        isClient ? "MONTRA Member" : "Personal Trainer · MONTRA"
    }

    var body: some View {
        ZStack {
            Color.montraBackground.ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Nav bar ───────────────────────────────────────────
                HStack(alignment: .center) {
                    Text("Profile")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                    Spacer()
                    Button {} label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20))
                            .foregroundColor(.montraTextSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {

                        // ── Hero card ─────────────────────────────────
                        HStack(spacing: 16) {
                            // Avatar — tappable for client to change photo
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                ZStack(alignment: .bottomTrailing) {
                                    avatarView
                                    if isClient {
                                        Circle()
                                            .fill(Color.montraOrange)
                                            .frame(width: 22, height: 22)
                                            .overlay(
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 9, weight: .semibold))
                                                    .foregroundColor(.black)
                                            )
                                            .offset(x: 3, y: 3)
                                    }
                                }
                            }
                            .disabled(!isClient)
                            .buttonStyle(.plain)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName)
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundColor(.montraTextPrimary)
                                Text(roleLabel)
                                    .font(.system(size: 13))
                                    .foregroundColor(.montraTextSecondary)
                                HStack(spacing: 5) {
                                    Circle()
                                        .fill(Color(hex: "#22C55E"))
                                        .frame(width: 7, height: 7)
                                    Text("Active")
                                        .font(.system(size: 12))
                                        .foregroundColor(.montraTextSecondary)
                                }
                                .padding(.top, 2)
                            }

                            Spacer()

                            Button {} label: {
                                Text("Edit Profile")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.montraTextPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 9)
                                    .background(Color.white.opacity(0.07))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 0.8)
                                    )
                            }
                        }
                        .padding(16)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                        )

                        // ── Account section ───────────────────────────
                        ProfileSectionCard(title: "ACCOUNT") {
                            Button { showPersonalInfo = true } label: {
                                ProfileRow(icon: "person.fill", label: "Personal Information")
                            }
                            .buttonStyle(.plain)
                            rowDivider
                            ProfileRow(icon: "creditcard.fill",   label: "Payment Methods")
                            rowDivider
                            if isClient {
                                ProfileRow(icon: "location.fill", label: "Addresses")
                                rowDivider
                            }
                            Button { showNotificationPrefs = true } label: {
                                ProfileRow(icon: "bell.fill", label: "Notification Preferences")
                            }
                            .buttonStyle(.plain)
                            rowDivider
                            ProfileRow(icon: "lock.fill",         label: "Privacy & Security")
                        }

                        // ── Sign out section ──────────────────────────
                        ProfileSectionCard(title: "") {
                            Button {
                                auth.signOut()
                                dismiss()
                            } label: {
                                ProfileRow(
                                    icon: "rectangle.portrait.and.arrow.right",
                                    label: "Sign Out",
                                    tint: Color(hex: "#FF6B6B"),
                                    showChevron: false
                                )
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self) {
                    profileImageData = data
                }
            }
        }
        .sheet(isPresented: $showPersonalInfo)      { PersonalInfoSheet() }
        .sheet(isPresented: $showNotificationPrefs) { NotificationPrefsSheet() }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.montraBackground)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatarView: some View {
        ZStack {
            if isClient, let uiImage = UIImage(data: profileImageData), !profileImageData.isEmpty {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 68, height: 68)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.montraSurface)
                    .frame(width: 68, height: 68)
                    .overlay(
                        Text(String(displayName.prefix(1)).uppercased())
                            .font(.system(size: 24, weight: .black))
                            .foregroundColor(.montraOrange)
                    )
            }
        }
        .overlay(Circle().stroke(Color.montraOrange, lineWidth: 1.5))
    }

    // MARK: - Helpers

    private var rowDivider: some View {
        Divider()
            .background(Color.white.opacity(0.06))
            .padding(.leading, 52)
    }
}

// MARK: - Section Card

private struct ProfileSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.montraTextSecondary)
                    .kerning(1.2)
                    .padding(.leading, 4)
                    .padding(.bottom, 8)
            }
            VStack(spacing: 0) {
                content
            }
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
            )
        }
    }
}

// MARK: - Row

private struct ProfileRow: View {
    let icon: String
    let label: String
    var tint: Color = .montraTextPrimary
    var showChevron: Bool = true

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(tint)
                .frame(width: 28)
            Text(label)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(tint)
            Spacer()
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.18))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
    }
}

// MARK: - Personal Information Sheet

struct PersonalInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("quiz.firstName")    private var storedFirst: String = ""
    @AppStorage("profile.lastName")  private var storedLast:  String = ""
    @AppStorage("profile.email")     private var storedEmail: String = ""
    @AppStorage("profile.phone")     private var storedPhone: String = ""

    @State private var draftFirst = ""
    @State private var draftLast  = ""
    @State private var draftEmail = ""
    @State private var draftPhone = ""

    var body: some View {
        ZStack {
            Color.montraBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.montraTextSecondary)
                    Spacer()
                    Text("Personal Info")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                    Spacer()
                    Button("Save") {
                        storedFirst = draftFirst.trimmingCharacters(in: .whitespacesAndNewlines)
                        storedLast  = draftLast.trimmingCharacters(in: .whitespacesAndNewlines)
                        storedEmail = draftEmail.trimmingCharacters(in: .whitespacesAndNewlines)
                        storedPhone = draftPhone.trimmingCharacters(in: .whitespacesAndNewlines)
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.montraOrange)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 14) {
                        PersonalInfoField(label: "FIRST NAME",    text: $draftFirst, contentType: .givenName)
                        PersonalInfoField(label: "LAST NAME",     text: $draftLast,  contentType: .familyName)
                        PersonalInfoField(label: "EMAIL ADDRESS", text: $draftEmail, contentType: .emailAddress, keyboardType: .emailAddress)
                        PersonalInfoField(label: "PHONE NUMBER",  text: $draftPhone, contentType: .telephoneNumber, keyboardType: .phonePad)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
        }
        .onAppear {
            draftFirst = storedFirst
            draftLast  = storedLast
            draftEmail = storedEmail
            draftPhone = storedPhone
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.montraBackground)
    }
}

private struct PersonalInfoField: View {
    let label: String
    @Binding var text: String
    var contentType: UITextContentType? = nil
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.montraTextSecondary)
                .kerning(0.8)
            TextField("", text: $text)
                .font(.system(size: 15))
                .foregroundColor(.montraTextPrimary)
                .keyboardType(keyboardType)
                .autocorrectionDisabled()
                .textContentType(contentType)
                .padding(14)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                )
        }
    }
}

// MARK: - Notification Preferences Sheet

struct NotificationPrefsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notif.sessionReminders") private var sessionReminders = true
    @AppStorage("notif.messages")         private var messages         = true
    @AppStorage("notif.progressUpdates")  private var progressUpdates  = true
    @AppStorage("notif.promotions")       private var promotions       = false

    var body: some View {
        ZStack {
            Color.montraBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer().frame(width: 44)
                    Spacer()
                    Text("Notifications")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.montraOrange)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        ProfileSectionCard(title: "PUSH NOTIFICATIONS") {
                            NotifToggleRow(icon: "calendar.badge.clock",
                                           label: "Session Reminders",
                                           subtitle: "Get reminded before your sessions",
                                           isOn: $sessionReminders)
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                            NotifToggleRow(icon: "bubble.left.fill",
                                           label: "New Messages",
                                           subtitle: "Notifications from your trainer",
                                           isOn: $messages)
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                            NotifToggleRow(icon: "chart.bar.fill",
                                           label: "Progress Updates",
                                           subtitle: "Weekly progress summaries",
                                           isOn: $progressUpdates)
                            Divider().background(Color.white.opacity(0.06)).padding(.leading, 52)
                            NotifToggleRow(icon: "tag.fill",
                                           label: "Promotions & Offers",
                                           subtitle: "Deals and special offers",
                                           isOn: $promotions)
                        }
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.montraBackground)
    }
}

private struct NotifToggleRow: View {
    let icon: String
    let label: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.montraTextPrimary)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.montraTextPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.montraTextSecondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .tint(.montraOrange)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
