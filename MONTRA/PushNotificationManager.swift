import SwiftUI
import UserNotifications
import FirebaseAuth

// MARK: - PushNotificationManager
//
// Handles APNs permission request, FCM token upload to the backend, and
// incoming notification routing. FirebaseMessaging is not imported here
// because it requires the FirebaseMessaging SPM package to be added in
// Xcode first — see HUMAN_TASKS.md for the steps. Once the package is
// added, uncomment the FirebaseMessaging lines below.
//
// NOTE: The app polls /api/notifications/my every 8 seconds while open,
// so in-app alerts work without push. Push notifications add background
// delivery for users who aren't actively in the app.

class PushNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let shared = PushNotificationManager()

    @AppStorage("notif.sessionReminders") var sessionReminders = true
    @AppStorage("notif.messages")         var messages         = true
    @AppStorage("notif.progressUpdates")  var progressUpdates  = true
    @AppStorage("notif.promotions")       var promotions       = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    // Call once from MONTRAApp.init() or after the user signs in.
    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // Called by AppDelegate.didRegisterForRemoteNotificationsWithDeviceToken.
    // Pass the raw APNs token here; FirebaseMessaging will exchange it for an
    // FCM token once the package is installed (see HUMAN_TASKS.md).
    func didReceiveAPNSToken(_ deviceToken: Data) {
        // TODO (after FirebaseMessaging package is added):
        //   import FirebaseMessaging
        //   Messaging.messaging().apnsToken = deviceToken
        //   Messaging.messaging().token { token, _ in
        //       guard let token else { return }
        //       Task { await PushNotificationManager.shared.uploadToken(token) }
        //   }
        _ = deviceToken // silence unused warning until FirebaseMessaging is linked
    }

    // Upload the FCM token to the backend so it can target this device.
    func uploadToken(_ fcmToken: String, authToken: String) async {
        guard let url = MontraAPIConfig.url(for: "/api/me/device-token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["token": fcmToken])
        _ = try? await URLSession.shared.data(for: request)
    }

    // Remove the device token on sign-out.
    func deleteToken(authToken: String) async {
        guard let url = MontraAPIConfig.url(for: "/api/me/device-token") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        _ = try? await URLSession.shared.data(for: request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    // Show notification banner even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let category = notification.request.content.userInfo["category"] as? String ?? ""

        // Respect user's per-category toggle preferences
        var shouldShow = true
        switch category {
        case "session":  shouldShow = sessionReminders
        case "message":  shouldShow = messages
        case "progress": shouldShow = progressUpdates
        case "promo":    shouldShow = promotions
        default:         shouldShow = true
        }

        completionHandler(shouldShow ? [.banner, .sound, .badge] : [])
    }

    // Handle tap on a notification (app was in background / not running).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let category = userInfo["category"] as? String ?? ""

        // Post an internal notification so the app can deep-link.
        // Views observe NotificationCenter to react (e.g., open the inbox tab).
        NotificationCenter.default.post(
            name: .montraPushTapped,
            object: nil,
            userInfo: ["category": category, "data": userInfo]
        )
        completionHandler()
    }
}

extension Notification.Name {
    static let montraPushTapped = Notification.Name("montraPushTapped")
}
