import SwiftUI
import UserNotifications
import FirebaseAuth
import FirebaseMessaging

// MARK: - PushNotificationManager
//
// Handles APNs permission, FCM token lifecycle, and notification routing.
// The backend stores device tokens via POST /api/me/device-token and uses them
// to push on: new client request, trainer accepted, new message, session booked,
// session cancelled — gated by the user's per-category toggle preferences here.

class PushNotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate, MessagingDelegate {

    static let shared = PushNotificationManager()

    @AppStorage("notif.sessionReminders") var sessionReminders = true
    @AppStorage("notif.messages")         var messages         = true
    @AppStorage("notif.progressUpdates")  var progressUpdates  = true
    @AppStorage("notif.promotions")       var promotions       = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
    }

    // Call once after the user signs in.
    func requestPermissionAndRegister() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
    }

    // AppDelegate receives the raw APNs token and hands it here.
    // FirebaseMessaging exchanges it for an FCM token asynchronously.
    func didReceiveAPNSToken(_ deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    // MARK: - MessagingDelegate

    // Called whenever FirebaseMessaging gets a new FCM token (first launch,
    // reinstall, token refresh). Upload it to the backend immediately.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task {
            guard let user = Auth.auth().currentUser,
                  let tokenResult = try? await user.getIDTokenResult(forcingRefresh: false) else { return }
            await uploadToken(fcmToken, authToken: tokenResult.token)
        }
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

    // Show banner even when the app is in the foreground, gated by user prefs.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let category = notification.request.content.userInfo["category"] as? String ?? ""
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

    // Deep-link when the user taps a push notification.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        let category = userInfo["category"] as? String ?? ""
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
    static let montraOpenTrainerInbox = Notification.Name("montraOpenTrainerInbox")
}
