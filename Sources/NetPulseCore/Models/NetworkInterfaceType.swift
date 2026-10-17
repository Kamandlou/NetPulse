import Foundation
import SwiftUI

public enum NetworkInterfaceType: String, Codable, Sendable, CaseIterable {
    case wifi
    case ethernet
    case cellular
    case other
    case none

    public var sfSymbol: String {
        switch self {
        case .wifi: return "wifi"
        case .ethernet: return "cable.connector"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .other: return "network"
        case .none: return "slash.circle"
        }
    }

    public func localizedName(for language: AppLanguage) -> String {
        switch language {
        case .english:
            switch self {
            case .wifi: return "Wi-Fi"
            case .ethernet: return "Ethernet"
            case .cellular: return "Cellular"
            case .other: return "Other Network"
            case .none: return "No Network Interface"
            }
        case .persian:
            switch self {
            case .wifi: return "وای‌فای (Wi-Fi)"
            case .ethernet: return "اترنت (Ethernet)"
            case .cellular: return "دیتای همراه (Cellular)"
            case .other: return "شبکه دیگر"
            case .none: return "هیچ رابط شبکه‌ای متصل نیست"
            }
        }
    }
}
