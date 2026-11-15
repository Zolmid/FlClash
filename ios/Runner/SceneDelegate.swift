import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var pendingShortcutFailure = false
  private var shortcutAttempt = 0

  @available(iOS 26.0, *)
  override func preferredWindowingControlStyle(
    for windowScene: UIWindowScene
  ) -> UIWindowScene.WindowingControlStyle {
    return .minimal
  }

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let shortcutItem = connectionOptions.shortcutItem,
      QuickAction(rawValue: shortcutItem.type) != nil {
      shortcutAttempt &+= 1
      let attempt = shortcutAttempt
      pendingShortcutFailure = false
      Task { @MainActor in
        let accepted = await self.handleShortcutItem(shortcutItem)
        guard self.shortcutAttempt == attempt else { return }
        self.pendingShortcutFailure = !accepted
        self.presentShortcutFailure(in: scene)
      }
    }
  }

  override func windowScene(
    _ windowScene: UIWindowScene,
    performActionFor shortcutItem: UIApplicationShortcutItem,
    completionHandler: @escaping (Bool) -> Void
  ) {
    shortcutAttempt &+= 1
    pendingShortcutFailure = false
    Task { @MainActor in completionHandler(await self.handleShortcutItem(shortcutItem)) }
  }

  @discardableResult
  private func handleShortcutItem(_ shortcutItem: UIApplicationShortcutItem) async -> Bool {
    guard let action = QuickAction(rawValue: shortcutItem.type) else {
      return false
    }
    return await ServiceChannel.request(action)
  }

  override func sceneDidBecomeActive(_ scene: UIScene) {
    super.sceneDidBecomeActive(scene)
    presentShortcutFailure(in: scene)
  }

  private func presentShortcutFailure(in scene: UIScene) {
    guard pendingShortcutFailure, scene.activationState == .foregroundActive,
      let windowScene = scene as? UIWindowScene,
      let root = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController
    else { return }
    var controller = root
    while let presented = controller.presentedViewController { controller = presented }
    pendingShortcutFailure = false
    let alert = UIAlertController(title: "ZolNit",
      message: NSLocalizedString("The VPN shortcut could not be accepted. Open ZolNit and try again.", comment: ""),
      preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
    controller.present(alert, animated: true)
  }
}
