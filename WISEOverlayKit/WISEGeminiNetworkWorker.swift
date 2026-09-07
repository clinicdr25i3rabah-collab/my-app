import Foundation
import Network

@available(iOS 13.0, *)
@objc public enum WISEGeminiRoute: Int {
    case cellularOnly = 0
    case wifiOnly = 1
    case systemDefault = 2
}

@available(iOS 13.0, *)
public enum WISEGeminiNetworkError: LocalizedError {
    case notConfigured
    case invalidEndpoint
    case requestEncodingFailed
    case invalidResponse
    case serverError(String)
    case connectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Gemini is not configured."
        case .invalidEndpoint:
            return "The Gemini endpoint must be an HTTPS URL."
        case .requestEncodingFailed:
            return "The Gemini request could not be encoded."
        case .invalidResponse:
            return "Gemini returned an invalid response."
        case .serverError(let message):
            return message
        case .connectionFailed(let message):
            return message
        }
    }
}

@available(iOS 13.0, *)
public final class WISEGeminiNetworkWorker: NSObject {
    public static let shared = WISEGeminiNetworkWorker()

    public var route: WISEGeminiRoute = .cellularOnly
    public var allowsFallbackToSystemDefault = false
    public var endpoint: URL?
    public var apiKey: String?
    public var requestTimeout: TimeInterval = 30

    private let workQueue = DispatchQueue(
        label: "com.wise.overlaykit.gemini-network",
        qos: .userInitiated
    )

    public func request(
        prompt: String,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        workQueue.async { [weak self] in
            guard let self else {
                return
            }

            self.performRequest(
                prompt: prompt,
                route: self.route,
                allowFallback: self.allowsFallbackToSystemDefault,
                completion: completion
            )
        }
    }

    private func performRequest(
        prompt: String,
        route: WISEGeminiRoute,
        allowFallback: Bool,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        do {
            let request = try makeRequest(prompt: prompt, route: route)
            send(
                request: request,
                route: route,
                completion: { [weak self] result in
                    guard let self else {
                        completion(result)
                        return
                    }

                    if case .failure = result,
                       allowFallback,
                       route != .systemDefault {
                        self.performRequest(
                            prompt: prompt,
                            route: .systemDefault,
                            allowFallback: false,
                            completion: completion
                        )
                    } else {
                        completion(result)
                    }
                }
            )
        } catch {
            completion(.failure(error))
        }
    }

    private func makeRequest(
        prompt: String,
        route: WISEGeminiRoute
    ) throws -> HTTPRequest {
        guard let endpoint, endpoint.scheme?.lowercased() == "https",
              let host = endpoint.host,
              let apiKey, !apiKey.isEmpty else {
            throw WISEGeminiNetworkError.notConfigured
        }

        let portNumber = endpoint.port ?? 443
        guard (1...65_535).contains(portNumber),
              let port = NWEndpoint.Port(rawValue: UInt16(portNumber)) else {
            throw WISEGeminiNetworkError.invalidEndpoint
        }

        var target = endpoint.path.isEmpty ? "/" : endpoint.path
        if let query = endpoint.query, !query.isEmpty {
            target += "?" + query
        }

        let bodyObject: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": prompt]]
                ]
            ]
        ]

        guard JSONSerialization.isValidJSONObject(bodyObject),
              let body = try? JSONSerialization.data(withJSONObject: bodyObject) else {
            throw WISEGeminiNetworkError.requestEncodingFailed
        }

        return HTTPRequest(
            host: host,
            port: port,
            target: target,
            body: body,
            apiKey: apiKey,
            route: route
        )
    }

    private func send(
        request: HTTPRequest,
        route: WISEGeminiRoute,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        let tlsOptions = NWProtocolTLS.Options()
        sec_protocol_options_set_min_tls_protocol_version(
            tlsOptions.securityProtocolOptions,
            .TLSv12
        )

        let parameters = NWParameters(
            tls: tlsOptions,
            tcp: NWProtocolTCP.Options()
        )

        switch route {
        case .cellularOnly:
            parameters.requiredInterfaceType = .cellular
        case .wifiOnly:
            parameters.requiredInterfaceType = .wifi
        case .systemDefault:
            break
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(request.host),
            port: request.port,
            using: parameters
        )

        let lock = NSLock()
        var didFinish = false
        var responseData = Data()
        var timeoutWorkItem: DispatchWorkItem?

        func finish(_ result: Result<String, Error>) {
            lock.lock()
            guard !didFinish else {
                lock.unlock()
                return
            }
            didFinish = true
            lock.unlock()

            timeoutWorkItem?.cancel()
            connection.cancel()
            completion(result)
        }

        func readResponse() {
            connection.receive(
                minimumIncompleteLength: 1,
                maximumLength: 64 * 1024
            ) { data, _, isComplete, error in
                if let data {
                    responseData.append(data)
                }

                if let error {
                    finish(.failure(
                        WISEGeminiNetworkError.connectionFailed(error.localizedDescription)
                    ))
                    return
                }

                if isComplete {
                    finish(self.parseResponse(responseData))
                } else {
                    readResponse()
                }
            }
        }

        let timeout = DispatchWorkItem {
            finish(.failure(
                WISEGeminiNetworkError.connectionFailed("The request timed out.")
            ))
        }
        timeoutWorkItem = timeout
        workQueue.asyncAfter(deadline: .now() + requestTimeout, execute: timeout)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                guard let requestData = request.serialized() else {
                    finish(.failure(WISEGeminiNetworkError.requestEncodingFailed))
                    return
                }

                connection.send(
                    content: requestData,
                    completion: .contentProcessed { error in
                        if let error {
                            finish(.failure(
                                WISEGeminiNetworkError.connectionFailed(
                                    error.localizedDescription
                                )
                            ))
                        } else {
                            readResponse()
                        }
                    }
                )
            case .failed(let error):
                finish(.failure(
                    WISEGeminiNetworkError.connectionFailed(error.localizedDescription)
                ))
            case .cancelled:
                finish(.failure(
                    WISEGeminiNetworkError.connectionFailed("The connection was cancelled.")
                ))
            default:
                break
            }
        }

        connection.start(queue: workQueue)
    }

    private func parseResponse(_ data: Data) -> Result<String, Error> {
        guard let headerRange = data.range(of: Data("\r\n\r\n".utf8)) else {
            return .failure(WISEGeminiNetworkError.invalidResponse)
        }

        let headerData = data[..<headerRange.lowerBound]
        let bodyData = data[headerRange.upperBound...]
        let header = String(decoding: headerData, as: UTF8.self)
        let statusLine = header.components(separatedBy: "\r\n").first ?? ""

        guard let statusCode = statusLine.split(separator: " ").dropFirst().first
                .flatMap({ Int($0) }) else {
            return .failure(WISEGeminiNetworkError.invalidResponse)
        }

        guard (200..<300).contains(statusCode) else {
            let message = String(data: bodyData, encoding: .utf8) ?? "Gemini request failed."
            return .failure(WISEGeminiNetworkError.serverError(message))
        }

        guard let json = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            return .failure(WISEGeminiNetworkError.invalidResponse)
        }

        return .success(text)
    }
}

@available(iOS 13.0, *)
private struct HTTPRequest {
    let host: String
    let port: NWEndpoint.Port
    let target: String
    let body: Data
    let apiKey: String
    let route: WISEGeminiRoute

    func serialized() -> Data? {
        var request = ""
        request += "POST \(target) HTTP/1.1\r\n"
        request += "Host: \(host)\r\n"
        request += "Connection: close\r\n"
        request += "Content-Type: application/json\r\n"
        request += "X-Goog-Api-Key: \(apiKey)\r\n"
        request += "Content-Length: \(body.count)\r\n"
        request += "\r\n"

        var data = Data(request.utf8)
        data.append(body)
        return data
    }
}