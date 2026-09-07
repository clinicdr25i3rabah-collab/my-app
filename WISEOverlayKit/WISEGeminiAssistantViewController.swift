import UIKit

@available(iOS 13.0, *)
final class WISEGeminiAssistantViewController: UIViewController {
    private let worker: WISEGeminiNetworkWorker
    private let transcriptView = UITextView()
    private let promptField = UITextField()
    private let sendButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    init(worker: WISEGeminiNetworkWorker) {
        self.worker = worker
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .systemBackground
        title = "Gemini Assistant"

        let closeButton = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(close)
        )
        navigationItem.leftBarButtonItem = closeButton

        transcriptView.isEditable = false
        transcriptView.font = .preferredFont(forTextStyle: .body)
        transcriptView.layer.cornerRadius = 12
        transcriptView.backgroundColor = .secondarySystemBackground
        transcriptView.text = "Ask a question about the current app experience."

        promptField.borderStyle = .roundedRect
        promptField.placeholder = "Ask Gemini"
        promptField.returnKeyType = .send
        promptField.delegate = self

        sendButton.setTitle("Send", for: .normal)
        sendButton.addTarget(
            self,
            action: #selector(sendPrompt),
            for: .primaryActionTriggered
        )

        statusLabel.font = .preferredFont(forTextStyle: .footnote)
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 0

        let inputStack = UIStackView(arrangedSubviews: [promptField, sendButton])
        inputStack.axis = .horizontal
        inputStack.spacing = 8
        promptField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        sendButton.setContentHuggingPriority(.required, for: .horizontal)

        let stack = UIStackView(arrangedSubviews: [transcriptView, inputStack, statusLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            transcriptView.heightAnchor.constraint(greaterThanOrEqualToConstant: 240),
            promptField.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    @objc private func close() {
        dismiss(animated: true)
    }

    @objc private func sendPrompt() {
        guard let prompt = promptField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !prompt.isEmpty else {
            return
        }

        promptField.resignFirstResponder()
        sendButton.isEnabled = false
        statusLabel.text = "Connecting using the selected Gemini route…"

        let previousText = transcriptView.text ?? ""
        transcriptView.text = previousText + "\n\nYou: " + prompt
        promptField.text = nil

        worker.request(prompt: prompt) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.sendButton.isEnabled = true

                switch result {
                case .success(let response):
                    self.transcriptView.text += "\n\nGemini: " + response
                    self.statusLabel.text = "Complete"
                case .failure(let error):
                    self.statusLabel.text = error.localizedDescription
                }

                let end = NSRange(location: max(0, self.transcriptView.text.count - 1), length: 1)
                self.transcriptView.scrollRangeToVisible(end)
            }
        }
    }
}

@available(iOS 13.0, *)
extension WISEGeminiAssistantViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendPrompt()
        return false
    }
}