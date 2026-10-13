import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pushChannel: FlutterMethodChannel?
  private var deviceToken: String?
  private var pendingNotification: [String: Any]?
  private var listenerReady = false
  private var environment: String {
    #if DEBUG
    return "sandbox"
    #else
    return "production"
    #endif
  }
  override func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
    pendingNotification = launchOptions?[.remoteNotification] as? [String: Any]
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "MushroomAPNs") else { return }
    let channel = FlutterMethodChannel(name: "com.example.thu/apns", binaryMessenger: registrar.messenger())
    pushChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "register":
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
          DispatchQueue.main.async {
            if let error = error { result(FlutterError(code: "APNS_PERMISSION", message: error.localizedDescription, details: nil)); return }
            if granted && self.deviceToken == nil { UIApplication.shared.registerForRemoteNotifications() }
            var reply: [String: Any] = ["environment": self.environment, "granted": granted]
            if let token = self.deviceToken { reply["token"] = token }
            result(reply)
          }
        }
      case "unregister":
        UIApplication.shared.unregisterForRemoteNotifications()
        self.deviceToken = nil
        self.pendingNotification = nil
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        result(nil)
      case "pending":
        self.listenerReady = true
        result(self.pendingNotification)
        self.pendingNotification = nil
      default: result(FlutterMethodNotImplemented)
      }
    }
  }
  override func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
    deviceToken = token.map { String(format: "%02x", $0) }.joined()
    pushChannel?.invokeMethod("token", arguments: deviceToken)
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: token)
  }
  override func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    pushChannel?.invokeMethod("error", arguments: error.localizedDescription)
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }
  override func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
    let payload = notification.request.content.userInfo
    pushChannel?.invokeMethod("foreground", arguments: payload)
    // Display only generic text. Dart verifies account/registration before opening.
    completionHandler([])
  }
  override func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
    let payload = response.notification.request.content.userInfo
    pendingNotification = payload as? [String: Any]
    if listenerReady, let channel = pushChannel {
      channel.invokeMethod("opened", arguments: payload)
      pendingNotification = nil
    }
    completionHandler()
  }
}
