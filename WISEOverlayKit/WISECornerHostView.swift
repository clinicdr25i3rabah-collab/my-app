import UIKit

@available(iOS 13.0, *)
final class WISECornerHostView: UIView {
    private lazy var topRightControl = WISECornerControl { [weak self] in
        self?.onTopRightTap?()
    }
    private lazy var topLeftControl = WISECornerControl { [weak self] in
        self?.onTopLeftTap?()
    }
    private let onTopRightTap: (() -> Void)?
    private let onTopLeftTap: (() -> Void)?

    init(
        onTopRightTap: @escaping () -> Void,
        onTopLeftTap: @escaping () -> Void
    ) {
        self.onTopRightTap = onTopRightTap
        self.onTopLeftTap = onTopLeftTap
        super.init(frame: .zero)

        isOpaque = false
        backgroundColor = .clear
        clipsToBounds = false
        accessibilityElementsHidden = true

        addSubview(topRightControl)
        addSubview(topLeftControl)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let size: CGFloat = 64
        let topInset = max(0, safeAreaInsets.top - 8)
        topLeftControl.frame = CGRect(
            x: 0,
            y: topInset,
            width: size,
            height: size
        )
        topRightControl.frame = CGRect(
            x: max(0, bounds.width - size),
            y: topInset,
            width: size,
            height: size
        )
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        topLeftControl.frame.contains(point) || topRightControl.frame.contains(point)
    }
}

private final class WISECornerControl: UIControl {
    private let onTap: () -> Void

    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
        super.init(frame: .zero)
        backgroundColor = .clear
        isOpaque = false
        accessibilityElementsHidden = true
        addTarget(self, action: #selector(handleTap), for: .primaryActionTriggered)
    }

    override init(frame: CGRect) {
        self.onTap = {}
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
        accessibilityElementsHidden = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        onTap()
    }
}