import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    ServiceChannel.register(with: engineBridge.applicationRegistrar.messenger())
    WebSessionBridge.register(engineBridge.applicationRegistrar.messenger())
  }
}

private final class WebSessionBridge: NSObject, WKNavigationDelegate, UIAdaptivePresentationControllerDelegate {
  private static let shared = WebSessionBridge()
  private let landing = "https://link.zolmid.com/theme/ZolNit/app-login.html"
  private let destinations: Set<String> = ["/", "/#/dashboard", "/theme/ZolNit/downloads.html"]
  private var controller: UIViewController?
  private var web: WKWebView?
  private var grant: (String, String)?
  private var openResult: FlutterResult?
  private var timeout: DispatchWorkItem?

  static func register(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "com.zolmid.zolnit/web_session", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "close": shared.close(); result(true)
      case "open":
        guard let args = call.arguments as? [String: String], let code = args["code"],
          let destination = args["destination"],
          code.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil,
          shared.destinations.contains(destination), let presenter = shared.presenter() else {
          result(false); return
        }
        shared.close()
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        let web = WKWebView(frame: .zero, configuration: config)
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        let close = UIButton(type: .system)
        close.setTitle("×", for: .normal)
        close.addTarget(shared, action: #selector(shared.close), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false
        web.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(close)
        vc.view.addSubview(web)
        NSLayoutConstraint.activate([
          close.topAnchor.constraint(equalTo: vc.view.safeAreaLayoutGuide.topAnchor),
          close.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor, constant: -16),
          close.heightAnchor.constraint(equalToConstant: 44),
          web.topAnchor.constraint(equalTo: close.bottomAnchor),
          web.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
          web.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
          web.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor),
        ])
        shared.controller = vc
        shared.web = web
        shared.grant = (code, destination)
        shared.openResult = result
        let timeout = DispatchWorkItem { [weak shared] in shared?.close() }
        shared.timeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
        web.navigationDelegate = shared
        presenter.present(vc, animated: true) {
          vc.presentationController?.delegate = shared
          web.load(URLRequest(url: URL(string: shared.landing)!))
        }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func presenter() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    var current = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }?.rootViewController
    while let next = current?.presentedViewController { current = next }
    return current
  }

  @objc private func close() {
    grant = nil
    timeout?.cancel()
    timeout = nil
    let pending = openResult
    openResult = nil
    pending?(false)
    web?.stopLoading()
    web?.navigationDelegate = nil
    web = nil
    let old = controller
    controller = nil
    old?.dismiss(animated: true)
  }

  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { close() }

  private func isInstallLink(_ url: URL) -> Bool {
    let profile = "^/api/v1/zolnit/client/apple/profile/[A-Za-z0-9_-]{43}/zolnit-device-enrollment\\.mobileconfig$"
    let manifest = "^/api/v1/zolnit/client/apple/ota/[A-Za-z0-9_-]{43}/manifest\\.plist$"
    func validHTTPS(_ value: URL, _ pattern: String) -> Bool {
      guard value.scheme == "https", value.host == "link.zolmid.com", value.port == nil || value.port == 443,
        value.user == nil, value.password == nil, value.query == nil, value.fragment == nil else { return false }
      return value.path.range(of: pattern, options: .regularExpression) != nil
    }
    if validHTTPS(url, profile) { return true }
    let prefix = "itms-services://?action=download-manifest&url="
    let raw = url.absoluteString
    guard raw.hasPrefix(prefix), raw.count <= 1024 else { return false }
    let encoded = String(raw.dropFirst(prefix.count))
    guard !encoded.isEmpty, encoded.rangeOfCharacter(from: CharacterSet(charactersIn: "&# \n\r\t")) == nil,
      let decoded = encoded.removingPercentEncoding, let manifestURL = URL(string: decoded) else { return false }
    return validHTTPS(manifestURL, manifest)
  }

  func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
               decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
    guard let url = action.request.url else { decisionHandler(.cancel); return }
    if grant != nil && action.targetFrame?.isMainFrame == true && url.absoluteString != landing {
      decisionHandler(.cancel); close(); return
    }
    if webView.url?.absoluteString == "https://link.zolmid.com/theme/ZolNit/downloads.html",
      action.targetFrame?.isMainFrame == true, isInstallLink(url) {
      decisionHandler(.cancel)
      let alert = UIAlertController(title: "ZolNit", message: "Open the installation link in iOS?", preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
      alert.addAction(UIAlertAction(title: "Open", style: .default) { _ in UIApplication.shared.open(url) })
      controller?.present(alert, animated: true)
      return
    }
    guard url.scheme == "https", url.host == "link.zolmid.com",
      url.port == nil || url.port == 443, url.user == nil, url.password == nil,
      action.targetFrame != nil else { decisionHandler(.cancel); return }
    decisionHandler(.allow)
  }

  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
    if grant != nil { close() }
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    guard webView === web, webView.url?.absoluteString == landing, let value = grant,
      let data = try? JSONSerialization.data(withJSONObject: [value.0, value.1]),
      let args = String(data: data, encoding: .utf8),
      let landingData = try? JSONSerialization.data(withJSONObject: [landing]),
      let landingArray = String(data: landingData, encoding: .utf8) else { return }
    grant = nil
    webView.evaluateJavaScript("(function(){if(window.top===window && window.location.href===\(landingArray)[0] && window.ZolNitWebSession && typeof window.ZolNitWebSession.accept==='function'){window.ZolNitWebSession.accept(...\(args));return true}return false})()") { [weak self, weak webView] value, error in
      guard let self = self, webView === self.web, let result = self.openResult else { return }
      if error != nil || (value as? Bool) != true { self.close(); return }
      self.timeout?.cancel()
      self.timeout = nil
      self.openResult = nil
      result(true)
    }
  }
}
