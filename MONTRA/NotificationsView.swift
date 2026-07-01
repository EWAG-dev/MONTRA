import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var auth: AuthManager
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notif.unreadCount") private var unreadCount = 0
    @AppStorage("notif.dismissedIds") private var dismissedIdsRaw = ""
    @State private var notifications: [MontraNotification] = []
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Notifications")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.montraOrange)
                }
                .padding(.top, 8)

                if isLoading && notifications.isEmpty {
                    ProgressView()
                        .tint(.montraOrange)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if let errorText, notifications.isEmpty {
                    NotificationsEmptyState(
                        icon: "exclamationmark.triangle",
                        title: "Couldn't load notifications",
                        message: errorText
                    )
                } else if notifications.isEmpty {
                    NotificationsEmptyState(
                        icon: "bell",
                        title: "You're all caught up",
                        message: "New requests and messages will show up here."
                    )
                } else {
                    ForEach(notifications) { item in
                        MontraNotificationRow(item: item) {
                            Task { await handleTap(on: item) }
                        }
                    }
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.montraBackground)
        .refreshable { await load() }
        .task { await load() }
    }

    private func load() async {
        guard let user = auth.user,
              let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else {
            errorText = "Please sign in again to see notifications."
            return
        }

        if notifications.isEmpty { isLoading = true }
        defer { isLoading = false }

        do {
            let loaded = try await NotificationsAPI.loadMine(token: tokenResult.token)
            let dismissedIds = dismissedIdSet
            notifications = loaded.filter { !dismissedIds.contains($0.id) }
            unreadCount = notifications.filter(\.unread).count
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private var dismissedIdSet: Set<String> {
        Set(dismissedIdsRaw.split(separator: ",").map { String($0) }.filter { !$0.isEmpty })
    }

    private func dismissNotificationLocally(_ id: String) {
        var ids = dismissedIdSet
        ids.insert(id)
        dismissedIdsRaw = ids.sorted().joined(separator: ",")
        notifications.removeAll { $0.id == id }
        unreadCount = notifications.filter(\.unread).count
    }

    private func handleTap(on item: MontraNotification) async {
        if auth.userRole == .trainer, item.category == "request" {
            dismissNotificationLocally(item.id)
            NotificationCenter.default.post(
                name: .montraOpenTrainerInbox,
                object: nil,
                userInfo: ["segment": "requests"]
            )
            dismiss()
            return
        }
    }
}

struct NotificationsEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 30, weight: .light))
                .foregroundColor(.montraTextSecondary)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.montraTextPrimary)
            Text(message)
                .font(.system(size: 13))
                .foregroundColor(.montraTextSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 50)
    }
}

struct MontraNotificationRow: View {
    let item: MontraNotification
    var onTap: (() -> Void)? = nil

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(item.unread ? Color.montraOrange : Color.montraDivider)
                    .frame(width: 9, height: 9)
                    .padding(.top, 6)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(item.title)
                            .font(.system(size: 15, weight: item.unread ? .semibold : .regular))
                            .foregroundColor(.montraTextPrimary)
                        Spacer()
                        Text(MontraNotificationRow.relativeTime(from: item.createdAt))
                            .font(.system(size: 11))
                            .foregroundColor(.montraTextSecondary)
                    }

                    Text(item.detail)
                        .font(.system(size: 13))
                        .foregroundColor(.montraTextSecondary)
                }
            }
        }
        .padding(14)
        .montraCard(radius: 14)
        .buttonStyle(.plain)
    }

    static func relativeTime(from iso: String) -> String {
        guard !iso.isEmpty else { return "" }
        let withFractional = ISO8601DateFormatter()
        withFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = withFractional.date(from: iso) ?? ISO8601DateFormatter().date(from: iso)
        guard let date else { return "" }
        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .abbreviated
        return relative.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    NotificationsView()
        .environmentObject(AuthManager())
}
