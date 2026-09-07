import Foundation

@available(iOS 13.0, *)
@objc public enum WISEMainAppNetworkMode: Int {
    case wifiOnly = 0
    case wifiAndCellular = 1
}

@available(iOS 13.0, *)
public final class WISENetworkPolicy: NSObject {
    public static let shared = WISENetworkPolicy()

    private let defaults: UserDefaults
    private let modeKey = "WISEOverlayKit.mainAppNetworkMode"

    public var mainAppMode: WISEMainAppNetworkMode {
        get {
            WISEMainAppNetworkMode(
                rawValue: defaults.integer(forKey: modeKey)
            ) ?? .wifiOnly
        }
        set {
            defaults.set(newValue.rawValue, forKey: modeKey)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        super.init()

        if defaults.object(forKey: modeKey) == nil {
            defaults.set(WISEMainAppNetworkMode.wifiOnly.rawValue, forKey: modeKey)
        }
    }

    public func makeConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true

        switch mainAppMode {
        case .wifiOnly:
            configuration.allowsCellularAccess = false
            configuration.allowsExpensiveNetworkAccess = false
            configuration.allowsConstrainedNetworkAccess = false
        case .wifiAndCellular:
            configuration.allowsCellularAccess = true
            configuration.allowsExpensiveNetworkAccess = true
            configuration.allowsConstrainedNetworkAccess = true
        }

        return configuration
    }

    public func makeSession(
        delegate: URLSessionDelegate? = nil,
        delegateQueue: OperationQueue? = nil
    ) -> URLSession {
        URLSession(
            configuration: makeConfiguration(),
            delegate: delegate,
            delegateQueue: delegateQueue
        )
    }
}