#if os(iOS)
import Flutter
import UIKit
#elseif os(macOS)
import AppKit
import FlutterMacOS
#endif
import SwiftUI

public final class ZolnitNativeUiPlugin: NSObject, FlutterPlugin {
    private let store = NativeUiStore()
    private lazy var bridge = NativeUiBridge(store: store) { [weak self] command, completion in
        guard let self else {
            completion(nil)
            return
        }
        self.perform(command: command, completion: completion)
    }
    private var channel: FlutterMethodChannel?

    deinit {
        channel?.setMethodCallHandler(nil)
        store.clear()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = ZolnitNativeUiPlugin()
        let channel = FlutterMethodChannel(
            name: NativeUiContract.channel,
            binaryMessenger: nativeMessenger(registrar)
        )
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.register(NativeHomeFactory(plugin: instance), withId: NativeUiContract.viewType)
        instance.requestInitialSnapshot()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            result(true)
        case "publishSnapshot":
            guard let json = call.arguments as? String else {
                result(FlutterError(code: "invalid_snapshot", message: nil, details: nil))
                return
            }
            DispatchQueue.main.async {
                guard self.store.publish(json: json) else {
                    result(FlutterError(code: "rejected_snapshot", message: nil, details: nil))
                    return
                }
                result(nil)
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func requestInitialSnapshot() {
        channel?.invokeMethod("getSnapshot", arguments: nil) { [weak self] response in
            guard let json = response as? String else { return }
            DispatchQueue.main.async { _ = self?.store.publish(json: json) }
        }
    }

    private func perform(command: String, completion: @escaping (String?) -> Void) {
        channel?.invokeMethod("performCommand", arguments: command) { response in
            completion(response as? String)
        }
    }

    fileprivate func makeView() -> NativeHomeView { NativeHomeView(bridge: bridge) }
}

private final class NativeHomeFactory: NSObject, FlutterPlatformViewFactory {
    private weak var plugin: ZolnitNativeUiPlugin?

    init(plugin: ZolnitNativeUiPlugin) { self.plugin = plugin }

    #if os(iOS)
    func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?) -> FlutterPlatformView {
        NativeHomePlatformView(frame: frame, content: plugin?.makeView())
    }
    #elseif os(macOS)
    func create(withViewIdentifier viewId: Int64, arguments args: Any?) -> NSView {
        let brightness = (args as? [String: Any])?["brightness"] as? String
        return NativeHomePlatformView(content: plugin?.makeView(), brightness: brightness)
    }
    #endif
}

#if os(iOS)
private func nativeMessenger(_ registrar: FlutterPluginRegistrar) -> FlutterBinaryMessenger { registrar.messenger() }

private final class NativeHomePlatformView: NSObject, FlutterPlatformView {
    private let hostingController: UIHostingController<AnyView>

    init(frame: CGRect, content: NativeHomeView?) {
        hostingController = UIHostingController(rootView: content.map { AnyView($0) } ?? AnyView(NativeHomeUnavailableView()))
        super.init()
        hostingController.view.frame = frame
        hostingController.view.backgroundColor = .clear
    }

    func view() -> UIView { hostingController.view }

    func dispose() {
        hostingController.willMove(toParent: nil)
        hostingController.view.removeFromSuperview()
        hostingController.removeFromParent()
    }
}
#elseif os(macOS)
private func nativeMessenger(_ registrar: FlutterPluginRegistrar) -> FlutterBinaryMessenger { registrar.messenger }

private final class NativeHomePlatformView: NSView {
    private let hostingController: NSHostingController<AnyView>

    init(content: NativeHomeView?, brightness: String?) {
        let scheme: ColorScheme? = brightness == "dark" ? .dark : brightness == "light" ? .light : nil
        let contentView = content.map { AnyView($0) } ?? AnyView(NativeHomeUnavailableView())
        hostingController = NSHostingController(rootView: AnyView(contentView.preferredColorScheme(scheme)))
        super.init(frame: .zero)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { nil }

    deinit {
        hostingController.view.removeFromSuperview()
    }
}
#endif

private struct NativeHomeUnavailableView: View {
    var body: some View { ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity) }
}
