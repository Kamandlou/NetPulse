import Foundation

public struct ConnectivityEndpoint: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var url: URL
    public var expectedStatusCode: Int?
    public var expectedBodySubstring: String?
    public var isEnabled: Bool
    public var customTimeout: TimeInterval?

    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        expectedStatusCode: Int? = nil,
        expectedBodySubstring: String? = nil,
        isEnabled: Bool = true,
        customTimeout: TimeInterval? = nil
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.expectedStatusCode = expectedStatusCode
        self.expectedBodySubstring = expectedBodySubstring
        self.isEnabled = isEnabled
        self.customTimeout = customTimeout
    }

    public static var defaults: [ConnectivityEndpoint] {
        [
            ConnectivityEndpoint(
                id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                name: "Apple Captive Portal Check",
                url: URL(string: "https://www.apple.com/library/test/success.html")!,
                expectedStatusCode: 200,
                expectedBodySubstring: "Success",
                isEnabled: true
            ),
            ConnectivityEndpoint(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                name: "Google Generate 204",
                url: URL(string: "https://www.google.com/generate_204")!,
                expectedStatusCode: 204,
                expectedBodySubstring: nil,
                isEnabled: true
            ),
            ConnectivityEndpoint(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                name: "Cloudflare Edge Trace",
                url: URL(string: "https://cloudflare.com/cdn-cgi/trace")!,
                expectedStatusCode: 200,
                expectedBodySubstring: "fl=",
                isEnabled: true
            )
        ]
    }
}

public struct EndpointCheckResult: Sendable {
    public let endpoint: ConnectivityEndpoint
    public let isSuccessful: Bool
    public let latencyMs: Double
    public let statusCode: Int?
    public let errorMessage: String?
    public let timestamp: Date

    public init(
        endpoint: ConnectivityEndpoint,
        isSuccessful: Bool,
        latencyMs: Double,
        statusCode: Int? = nil,
        errorMessage: String? = nil,
        timestamp: Date = Date()
    ) {
        self.endpoint = endpoint
        self.isSuccessful = isSuccessful
        self.latencyMs = latencyMs
        self.statusCode = statusCode
        self.errorMessage = errorMessage
        self.timestamp = timestamp
    }
}
