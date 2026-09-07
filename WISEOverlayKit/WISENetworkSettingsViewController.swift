import UIKit

@available(iOS 13.0, *)
final class WISENetworkSettingsViewController: UIViewController {
    private let policy: WISENetworkPolicy
    private let geminiWorker: WISEGeminiNetworkWorker

    private let appCellularSwitch = UISwitch()
    private let geminiRouteControl = UISegmentedControl(items: [
        "Cellular Only",
        "Wi-Fi Only",
        "System Default"
    ])
    private let fallbackSwitch = UISwitch()

    init(
        policy: WISENetworkPolicy,
        geminiWorker: WISEGeminiNetworkWorker
    ) {
        self.policy = policy
        self.geminiWorker = geminiWorker
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .formSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "Network Controls"
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(close)
        )

        appCellularSwitch.isOn = policy.mainAppMode == .wifiAndCellular
        appCellularSwitch.addTarget(
            self,
            action: #selector(appCellularChanged),
            for: .valueChanged
        )

        geminiRouteControl.selectedSegmentIndex = geminiWorker.route.rawValue
        geminiRouteControl.addTarget(
            self,
            action: #selector(geminiRouteChanged),
            for: .valueChanged
        )

        fallbackSwitch.isOn = geminiWorker.allowsFallbackToSystemDefault
        fallbackSwitch.addTarget(
            self,
            action: #selector(fallbackChanged),
            for: .valueChanged
        )

        let appRow = makeRow(
            title: "Allow cellular for main app traffic",
            detail: "Off means Wi-Fi only for sessions created through WISENetworkPolicy.",
            control: appCellularSwitch
        )
        let geminiRow = makeRow(
            title: "Gemini connection route",
            detail: "The selected interface is requested for Gemini NWConnection instances.",
            control: geminiRouteControl
        )
        let fallbackRow = makeRow(
            title: "Allow Gemini system fallback",
            detail: "If the requested interface fails, retry using the system-selected path.",
            control: fallbackSwitch
        )

        let stack = UIStackView(arrangedSubviews: [appRow, geminiRow, fallbackRow])
        stack.axis = .vertical
        stack.spacing = 20
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20)
        ])
    }

    private func makeRow(
        title: String,
        detail: String,
        control: UIView
    ) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.numberOfLines = 0

        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = .preferredFont(forTextStyle: .footnote)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 0

        let labels = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        labels.axis = .vertical
        labels.spacing = 4

        let row = UIStackView(arrangedSubviews: [labels, control])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(.required, for: .horizontal)
        return row
    }

    @objc private func appCellularChanged() {
        policy.mainAppMode = appCellularSwitch.isOn ? .wifiAndCellular : .wifiOnly
    }

    @objc private func geminiRouteChanged() {
        geminiWorker.route = WISEGeminiRoute(
            rawValue: geminiRouteControl.selectedSegmentIndex
        ) ?? .cellularOnly
    }

    @objc private func fallbackChanged() {
        geminiWorker.allowsFallbackToSystemDefault = fallbackSwitch.isOn
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}