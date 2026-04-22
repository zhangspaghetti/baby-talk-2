import Flutter
import UIKit
import app_links

class SceneDelegate: FlutterSceneDelegate {
  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    self.scene(scene, openURLContexts: connectionOptions.urlContexts)
    for userActivity in connectionOptions.userActivities {
      self.scene(scene, continue: userActivity)
    }
  }

  override func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    super.scene(scene, openURLContexts: URLContexts)
    for context in URLContexts {
      AppLinks.shared.handleLink(url: context.url)
    }
  }

  override func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
    super.scene(scene, continue: userActivity)
    if let url = userActivity.webpageURL {
      AppLinks.shared.handleLink(url: url)
    }
  }
}
