import Flutter
import UIKit
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let DEEPLINK_CHANNEL = "com.red.app/deeplink"
  private var initialDeepLink: String? = nil
  private var deepLinkChannel: FlutterMethodChannel? = nil

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Configure background audio session for video player and PiP
    do {
      try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
      try AVAudioSession.sharedInstance().setActive(true)
    } catch {
      print("Failed to set AVAudioSession category: \(error)")
    }

    // Capture initial launch URL if present
    if let url = launchOptions?[.url] as? URL {
      initialDeepLink = url.absoluteString
    }

    if let controller = window?.rootViewController as? FlutterViewController {
      deepLinkChannel = FlutterMethodChannel(
        name: DEEPLINK_CHANNEL,
        binaryMessenger: controller.binaryMessenger
      )
      
      deepLinkChannel?.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
        if call.method == "getInitialLink" {
          let link = self?.initialDeepLink
          self?.initialDeepLink = nil
          result(link)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle Custom Scheme URLs (redapp://watch?id=...)
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    let urlString = url.absoluteString
    if let channel = deepLinkChannel {
      channel.invokeMethod("onLink", arguments: urlString)
    } else {
      initialDeepLink = urlString
    }
    return super.application(app, open: url, options: options)
  }

  // Handle Universal Links (https://redwatch.infinityredchillies.workers.dev/...)
  override func application(
    _ application: UIApplication,
    continue userActivity: NSUserActivity,
    restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
  ) -> Bool {
    if userActivity.activityType == NSUserActivityTypeBrowsingWeb, let url = userActivity.webpageURL {
      let urlString = url.absoluteString
      if let channel = deepLinkChannel {
        channel.invokeMethod("onLink", arguments: urlString)
      } else {
        initialDeepLink = urlString
      }
      return true
    }
    return super.application(application, continue: userActivity, restorationHandler: restorationHandler)
  }
}
