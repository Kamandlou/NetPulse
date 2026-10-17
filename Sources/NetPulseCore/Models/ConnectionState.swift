import Foundation
import SwiftUI

/// Authoritative connection states for NetPulse
public enum ConnectionState: String, Codable, Sendable, CaseIterable {
    case online
    case offline
    case checking
    case unstable
    case unknown

    public var sfSymbol: String {
        switch self {
        case .online:
            return "checkmark.circle.fill"
        case .offline:
            return "xmark.circle.fill"
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .unstable:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }

    public var menuBarSymbol: String {
        switch self {
        case .online:
            return "wifi"
        case .offline:
            return "wifi.slash"
        case .checking:
            return "arrow.triangle.2.circlepath"
        case .unstable:
            return "exclamationmark.triangle.fill"
        case .unknown:
            return "wifi.exclamationmark"
        }
    }

    public var color: Color {
        switch self {
        case .online:
            return .green
        case .offline:
            return .red
        case .checking:
            return .gray
        case .unstable:
            return .orange
        case .unknown:
            return .secondary
        }
    }

    public func localizedTitle(for language: AppLanguage) -> String {
        switch language {
        case .english:
            switch self {
            case .online: return "Internet Connected"
            case .offline: return "Internet Disconnected"
            case .checking: return "Checking Connection..."
            case .unstable: return "Connection Unstable"
            case .unknown: return "Unknown Status"
            }
        case .persian:
            switch self {
            case .online: return "اتصال اینترنت برقرار است"
            case .offline: return "اتصال اینترنت قطع است"
            case .checking: return "در حال بررسی اتصال..."
            case .unstable: return "اتصال ناپایدار است"
            case .unknown: return "وضعیت نامشخص"
            }
        }
    }
}
