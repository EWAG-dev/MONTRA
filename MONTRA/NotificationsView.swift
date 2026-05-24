import SwiftUI

struct NotificationsView: View {
    private let notifications: [AppNotification] = [
        AppNotification(id: 1, title: "Session confirmed", detail: "Alex confirmed your 10:00 AM Friday session.", time: "2m", isUnread: true),
        AppNotification(id: 2, title: "Program update", detail: "Your Strength Builder plan has a new week 3 block.", time: "1h", isUnread: true),
        AppNotification(id: 3, title: "Hydration reminder", detail: "Aim for 2.5L water today before training.", time: "3h", isUnread: false),
        AppNotification(id: 4, title: "Payment receipt", detail: "Your monthly training invoice is available.", time: "Yesterday", isUnread: false),
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Notifications")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.montraTextPrimary)
                    Spacer()
                }
                .padding(.top, 8)

                ForEach(notifications) { item in
                    NotificationRow(item: item)
                }

                Spacer(minLength: 80)
            }
            .padding(.horizontal, 20)
        }
        .background(Color.montraBackground)
    }
}

struct AppNotification: Identifiable {
    let id: Int
    let title: String
    let detail: String
    let time: String
    let isUnread: Bool
}

struct NotificationRow: View {
    let item: AppNotification

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(item.isUnread ? Color.montraOrange : Color.montraDivider)
                .frame(width: 9, height: 9)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.system(size: 15, weight: item.isUnread ? .semibold : .regular))
                        .foregroundColor(.montraTextPrimary)
                    Spacer()
                    Text(item.time)
                        .font(.system(size: 11))
                        .foregroundColor(.montraTextSecondary)
                }

                Text(item.detail)
                    .font(.system(size: 13))
                    .foregroundColor(.montraTextSecondary)
            }
        }
        .padding(14)
        .montraCard(radius: 14)
    }
}

#Preview {
    NotificationsView()
}
