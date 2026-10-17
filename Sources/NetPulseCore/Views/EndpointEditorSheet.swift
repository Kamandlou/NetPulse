import SwiftUI

@MainActor
public final class EndpointEditorViewModel: ObservableObject {
    @Published public var name: String = ""
    @Published public var urlString: String = "https://"
    @Published public var expectedStatusCode: String = ""
    @Published public var expectedBodySubstring: String = ""
    @Published public var isEnabled: Bool = true
    @Published public var errorMessage: String?

    public init(endpoint: ConnectivityEndpoint? = nil) {
        if let ep = endpoint {
            self.name = ep.name
            self.urlString = ep.url.absoluteString
            self.expectedStatusCode = ep.expectedStatusCode.map { "\($0)" } ?? ""
            self.expectedBodySubstring = ep.expectedBodySubstring ?? ""
            self.isEnabled = ep.isEnabled
        }
    }

    public func buildEndpoint(id: UUID) -> ConnectivityEndpoint? {
        guard let url = URL(string: urlString), url.scheme != nil else {
            errorMessage = "Invalid URL format"
            return nil
        }

        let statusCode = Int(expectedStatusCode.trimmingCharacters(in: .whitespaces))
        let bodySub = expectedBodySubstring.trimmingCharacters(in: .whitespaces).isEmpty ? nil : expectedBodySubstring

        return ConnectivityEndpoint(
            id: id,
            name: name.isEmpty ? (url.host ?? "Custom Endpoint") : name,
            url: url,
            expectedStatusCode: statusCode,
            expectedBodySubstring: bodySub,
            isEnabled: isEnabled
        )
    }
}

public struct EndpointEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings: SettingsManager
    @StateObject private var viewModel: EndpointEditorViewModel

    private let initialEndpoint: ConnectivityEndpoint?
    private let onSave: (ConnectivityEndpoint) -> Void

    @MainActor
    public init(
        settings: SettingsManager? = nil,
        endpoint: ConnectivityEndpoint? = nil,
        onSave: @escaping (ConnectivityEndpoint) -> Void
    ) {
        let activeSettings = settings ?? .shared
        self.settings = activeSettings
        self.initialEndpoint = endpoint
        self.onSave = onSave
        self._viewModel = StateObject(wrappedValue: EndpointEditorViewModel(endpoint: endpoint))
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text(initialEndpoint == nil ? L10n.string(.addEndpoint, language: settings.language) : L10n.string(.editEndpoint, language: settings.language))
                .font(.headline)

            Form {
                TextField(L10n.string(.endpointName, language: settings.language), text: $viewModel.name)
                TextField(L10n.string(.endpointURL, language: settings.language), text: $viewModel.urlString)
                TextField(L10n.string(.expectedStatus, language: settings.language), text: $viewModel.expectedStatusCode)
                TextField(L10n.string(.expectedBody, language: settings.language), text: $viewModel.expectedBodySubstring)
                Toggle("Enabled", isOn: $viewModel.isEnabled)
            }
            .formStyle(.grouped)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }

            HStack {
                Button(L10n.string(.cancel, language: settings.language)) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button(L10n.string(.save, language: settings.language)) {
                    if let endpoint = viewModel.buildEndpoint(id: initialEndpoint?.id ?? UUID()) {
                        onSave(endpoint)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 440)
        .environment(\.layoutDirection, settings.language.layoutDirection)
    }
}
