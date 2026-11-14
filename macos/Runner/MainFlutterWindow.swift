import Cocoa
import FlutterMacOS
import window
import LaunchAtLogin
import WebKit

class MainFlutterWindow: NSWindow {
    private let webSession = DesktopWebSession()
    override func awakeFromNib() {
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)
        
        FlutterMethodChannel(
            name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
        )
        .setMethodCallHandler { (_ call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "launchAtStartupIsEnabled":
                result(LaunchAtLogin.isEnabled)
            case "launchAtStartupSetEnabled":
                if let arguments = call.arguments as? [String: Any] {
                    LaunchAtLogin.isEnabled = arguments["setEnabledValue"] as! Bool
                }
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        webSession.register(flutterViewController.engine.binaryMessenger)
        RegisterGeneratedPlugins(registry: flutterViewController)
        super.awakeFromNib()
    }
    override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
        super.order(place, relativeTo: otherWin)
        hiddenWindowAtLaunch()
    }
}

private final class DesktopWebSession: NSObject, WKNavigationDelegate, WKUIDelegate, NSWindowDelegate {
    private let landing = "https://link.zolmid.com/theme/ZolNit/app-login.html"
    private let destinations: Set<String> = ["/", "/#/dashboard", "/theme/ZolNit/downloads.html"]
    private var window: NSWindow?
    private var web: WKWebView?
    private var grant: (String, String)?
    private var pending: FlutterResult?
    private var timeout: DispatchWorkItem?

    func register(_ messenger: FlutterBinaryMessenger) {
        FlutterMethodChannel(name: "com.zolmid.zolnit/web_session", binaryMessenger: messenger)
            .setMethodCallHandler { [weak self] call, result in
                guard let self = self else { result(false); return }
                switch call.method {
                case "close": self.close(); result(true)
                case "open":
                    guard let args = call.arguments as? [String: String], let code = args["code"],
                          let destination = args["destination"],
                          code.range(of: "^[A-Za-z0-9_-]{43}$", options: .regularExpression) != nil,
                          self.destinations.contains(destination) else { result(false); return }
                    self.close()
                    let config = WKWebViewConfiguration()
                    config.websiteDataStore = .nonPersistent()
                    config.userContentController.addUserScript(WKUserScript(
                        source: "Object.defineProperty(navigator,'geolocation',{value:undefined,configurable:false});",
                        injectionTime: .atDocumentStart,
                        forMainFrameOnly: false
                    ))
                    let web = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 720), configuration: config)
                    let window = NSWindow(contentRect: web.frame, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
                    window.title = "ZolNit"
                    window.isReleasedWhenClosed = false
                    window.contentView = web
                    window.delegate = self
                    web.navigationDelegate = self
                    web.uiDelegate = self
                    self.window = window
                    self.web = web
                    self.grant = (code, destination)
                    self.pending = result
                    let timeout = DispatchWorkItem { [weak self] in self?.close() }
                    self.timeout = timeout
                    DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
                    window.center()
                    window.makeKeyAndOrderFront(nil)
                    web.load(URLRequest(url: URL(string: self.landing)!))
                default: result(FlutterMethodNotImplemented)
                }
            }
    }

    private func close() {
        grant = nil
        timeout?.cancel()
        timeout = nil
        let response = pending
        pending = nil
        response?(false)
        web?.stopLoading()
        web?.navigationDelegate = nil
        web?.uiDelegate = nil
        web = nil
        let old = window
        window = nil
        old?.delegate = nil
        old?.close()
    }

    func windowWillClose(_ notification: Notification) { close() }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = action.request.url, action.targetFrame != nil,
              url.scheme == "https", url.host == "link.zolmid.com", url.port == nil || url.port == 443,
              url.user == nil, url.password == nil else { decisionHandler(.cancel); return }
        if grant != nil && action.targetFrame?.isMainFrame == true && url.absoluteString != landing {
            decisionHandler(.cancel)
            close()
            return
        }
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
            guard let self = self, webView === self.web, let result = self.pending else { return }
            if error != nil || (value as? Bool) != true { self.close(); return }
            self.timeout?.cancel()
            self.timeout = nil
            self.pending = nil
            result(true)
        }
    }

    @available(macOS 27.0, *)
    func webView(_ webView: WKWebView, requestGeolocationPermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.deny)
    }

    @available(macOS 12.0, *)
    func webView(_ webView: WKWebView, requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo, type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.deny)
    }
}
