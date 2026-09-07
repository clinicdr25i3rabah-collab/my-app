import UIKit

@available(iOS 13.0, *)
public final class WISEOverlayKit: NSObject {
    public static let shared = WISEOverlayKit()

    public let networkPolicy = WISENetworkPolicy.shared
    public let geminiWorker = WISEGeminiNetworkWorker.shared

    private var didStart = false
    private var notificationTokens: [NSObjectProtocol] = []

    private override init() {
        super.init()
    }

    public func configureGemini(
        endpoint: URL,
        apiKey: String,
        allowsFallbackToSystemDefault: Bool = false
    ) {
        geminiWorker.endpoint = endpoint
        geminiWorker.apiKey = apiKey
        geminiWorker.allowsFallbackToSystemDefault = allowsFallbackToSystemDefault
    }

    public func start() {
        dispatchPrecondition(condition: .onQueue(.main))
        guard !didStart else {
            attachToVisibleWindows()
            return
        }

        didStart = true

        notificationTokens.append(
            NotificationCenter.default.addObserver(
                forName: UIApplication.didBecomeActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.attachToVisibleWindows()
            }
        )

        if #available(iOS 13.0, *) {
            notificationTokens.append(
                NotificationCenter.default.addObserver(
                    forName: UIScene.didActivateNotification,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    self?.attachToVisibleWindows()
                }
            )
        }

        attachToVisibleWindows()
    }

    private func attachToVisibleWindows() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.attachToVisibleWindows()
            }
            return
        }

        let windows: [UIWindow]
        if #available(iOS 13.0, *) {
            windows = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .filter {
                    $0.activationState == .foregroundActive ||
                    $0.activationState == .foregroundInactive
                }
                .flatMap(\.windows)
        } else {
            windows = UIApplication.shared.windows
        }

        for window in windows where isUsable(window) {
            attach(to: window)
        }
    }

    private func isUsable(_ window: UIWindow) -> Bool {
        !window.isHidden &&
        window.alpha > 0 &&
        window.windowLevel == .normal &&
        window.rootViewController != nil
    }

    private func attach(to window: UIWindow) {
        guard window.viewWithTag(WISECornerHostView.viewTag) == nil else {
            return
        }

        let hostView = WISECornerHostView(
            onTopRightTap: { [weak self, weak window] in
                self?.presentAssistant(from: window)
            },
            onTopLeftTap: { [weak self, weak window] in
                self?.presentSettings(from: window)
            }
        )
        hostView.tag = WISECornerHostView.viewTag
        hostView.frame = window.bounds
        hostView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(hostView)
    }

    private func presentAssistant(from window: UIWindow?) {
        guard let presenter = topViewController(in: window?.rootViewController) else {
            return
        }

        if presenter is WISEGeminiAssistantViewController {
            presenter.navigationController?.dismiss(animated: true)
            return
        }
        if presenter is WISENetworkSettingsViewController {
            presenter.navigationController?.dismiss(animated: true)
            return
        }

        let controller = WISEGeminiAssistantViewController(worker: geminiWorker)
        presenter.present(
            UINavigationController(rootViewController: controller),
            animated: true
        )
    }

    private func presentSettings(from window: UIWindow?) {
        guard let presenter = topViewController(in: window?.rootViewController) else {
            return
        }

        if presenter is WISEGeminiAssistantViewController {
            presenter.navigationController?.dismiss(animated: true)
            return
        }
        if presenter is WISENetworkSettingsViewController {
            presenter.navigationController?.dismiss(animated: true)
            return
        }

        let controller = WISENetworkSettingsViewController(
            policy: networkPolicy,
            geminiWorker: geminiWorker
        )
        presenter.present(
            UINavigationController(rootViewController: controller),
            animated: true
        )
    }

    private func topViewController(in root: UIViewController?) -> UIViewController? {
        guard let root else {
            return nil
        }

        if let presented = root.presentedViewController, !presented.isBeingDismissed {
            return topViewController(in: presented)
        }
        if let navigation = root as? UINavigationController {
            return topViewController(in: navigation.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(in: tab.selectedViewController)
        }
        if let split = root as? UISplitViewController {
            return topViewController(in: split.viewControllers.last)
        }
        return root
    }

    deinit {
        notificationTokens.forEach(NotificationCenter.default.removeObserver)
    }
}

@available(iOS 13.0, *)
@_cdecl("WISEOverlayKitBootstrap")
public func WISEOverlayKitBootstrap() {
    DispatchQueue.main.async {
        WISEOverlayKit.shared.start()
    }
}

@available(iOS 13.0, *)
private extension WISECornerHostView {
    static let viewTag = 0x57495345
}