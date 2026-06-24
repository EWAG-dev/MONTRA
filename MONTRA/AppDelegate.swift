import UIKit
import FirebaseMessaging

// AppDelegate is required to receive the raw APNs device token from UIKit and
// forward it to FirebaseMessaging, which exchanges it for an FCM token.
// MONTRAApp wires this in via @UIApplicationDelegateAdaptor.

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushNotificationManager.shared.didReceiveAPNSToken(deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[Push] APNs registration failed: \(error.localizedDescription)")
    }

    // Required for FirebaseMessaging to handle background FCM delivery
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        completionHandler(.newData)
    }
}
