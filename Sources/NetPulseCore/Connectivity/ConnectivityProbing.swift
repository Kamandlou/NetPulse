import Foundation

public protocol ConnectivityProbing: Sendable {
    func probe(endpoint: ConnectivityEndpoint, timeout: TimeInterval) async -> EndpointCheckResult
}

public final class URLSessionConnectivityProbe: ConnectivityProbing {
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            config.urlCache = nil
            config.waitsForConnectivity = false
            config.httpShouldSetCookies = false
            self.session = URLSession(configuration: config)
        }
    }

    public func probe(endpoint: ConnectivityEndpoint, timeout: TimeInterval) async -> EndpointCheckResult {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "GET"
        request.timeoutInterval = endpoint.customTimeout ?? timeout
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        request.setValue("NetPulse/1.0 (macOS)", forHTTPHeaderField: "User-Agent")

        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let (data, response) = try await session.data(for: request)
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0

            guard let httpResponse = response as? HTTPURLResponse else {
                return EndpointCheckResult(
                    endpoint: endpoint,
                    isSuccessful: false,
                    latencyMs: elapsedMs,
                    statusCode: nil,
                    errorMessage: "Non-HTTP response",
                    timestamp: Date()
                )
            }

            // Check status code if required
            if let expectedCode = endpoint.expectedStatusCode {
                if httpResponse.statusCode != expectedCode {
                    let reason: String
                    if httpResponse.statusCode == 301 || httpResponse.statusCode == 302 || httpResponse.statusCode == 307 {
                        reason = "Captive portal redirect detected (HTTP \(httpResponse.statusCode))"
                    } else {
                        reason = "Unexpected HTTP status: \(httpResponse.statusCode) (expected \(expectedCode))"
                    }
                    return EndpointCheckResult(
                        endpoint: endpoint,
                        isSuccessful: false,
                        latencyMs: elapsedMs,
                        statusCode: httpResponse.statusCode,
                        errorMessage: reason,
                        timestamp: Date()
                    )
                }
            } else {
                // If no specific code required, accept standard 2xx codes
                if !(200...299).contains(httpResponse.statusCode) {
                    return EndpointCheckResult(
                        endpoint: endpoint,
                        isSuccessful: false,
                        latencyMs: elapsedMs,
                        statusCode: httpResponse.statusCode,
                        errorMessage: "HTTP error: \(httpResponse.statusCode)",
                        timestamp: Date()
                    )
                }
            }

            // Check response body substring if required
            if let expectedSubstring = endpoint.expectedBodySubstring {
                let maxBytes = min(data.count, 4096)
                let prefixData = data.prefix(maxBytes)
                let bodyString = String(decoding: prefixData, as: UTF8.self)
                if !bodyString.contains(expectedSubstring) {
                    return EndpointCheckResult(
                        endpoint: endpoint,
                        isSuccessful: false,
                        latencyMs: elapsedMs,
                        statusCode: httpResponse.statusCode,
                        errorMessage: "Response body does not contain expected token (possible captive portal)",
                        timestamp: Date()
                    )
                }
            }

            return EndpointCheckResult(
                endpoint: endpoint,
                isSuccessful: true,
                latencyMs: elapsedMs,
                statusCode: httpResponse.statusCode,
                errorMessage: nil,
                timestamp: Date()
            )

        } catch {
            let elapsedMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000.0
            let nsError = error as NSError
            let technicalReason: String

            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorTimedOut:
                    technicalReason = "Request timed out (\(Int(timeout))s)"
                case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
                    technicalReason = "DNS resolution failure"
                case NSURLErrorCannotConnectToHost:
                    technicalReason = "Cannot connect to host"
                case NSURLErrorNetworkConnectionLost:
                    technicalReason = "Network connection lost"
                case NSURLErrorNotConnectedToInternet:
                    technicalReason = "No internet connection"
                case NSURLErrorSecureConnectionFailed, NSURLErrorServerCertificateUntrusted:
                    technicalReason = "TLS/SSL handshake failure"
                default:
                    technicalReason = nsError.localizedDescription
                }
            } else {
                technicalReason = error.localizedDescription
            }

            return EndpointCheckResult(
                endpoint: endpoint,
                isSuccessful: false,
                latencyMs: elapsedMs,
                statusCode: nil,
                errorMessage: technicalReason,
                timestamp: Date()
            )
        }
    }
}
