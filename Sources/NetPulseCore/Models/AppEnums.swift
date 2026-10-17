import Foundation
import SwiftUI

public enum AppLanguage: String, Codable, Sendable, CaseIterable, Identifiable {
    case english = "en"
    case persian = "fa"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .english: return "English"
        case .persian: return "فارسی (Persian)"
        }
    }

    public var layoutDirection: LayoutDirection {
        switch self {
        case .english: return .leftToRight
        case .persian: return .rightToLeft
        }
    }
}

public enum AppAppearance: String, Codable, Sendable, CaseIterable, Identifiable {
    case system
    case light
    case dark

    public var id: String { rawValue }

    public func localizedName(for language: AppLanguage) -> String {
        switch language {
        case .english:
            switch self {
            case .system: return "Follow System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        case .persian:
            switch self {
            case .system: return "هماهنگ با سیستم"
            case .light: return "روشن"
            case .dark: return "تیره"
            }
        }
    }

    public var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

public enum CheckingStrategy: String, Codable, Sendable, CaseIterable, Identifiable {
    case balanced
    case fast
    case batterySaving

    public var id: String { rawValue }

    public func localizedName(for language: AppLanguage) -> String {
        switch language {
        case .english:
            switch self {
            case .balanced: return "Balanced (Recommended)"
            case .fast: return "Fast & Responsive"
            case .batterySaving: return "Battery Saving"
            }
        case .persian:
            switch self {
            case .balanced: return "متعادل (پیش‌نهادی)"
            case .fast: return "سریع و با واکنش بالا"
            case .batterySaving: return "بهینه‌سازی مصرف باتری"
            }
        }
    }

    public var defaultInterval: TimeInterval {
        switch self {
        case .balanced: return 5.0
        case .fast: return 2.0
        case .batterySaving: return 15.0
        }
    }

    public var defaultTimeout: TimeInterval {
        switch self {
        case .balanced: return 3.0
        case .fast: return 2.0
        case .batterySaving: return 4.0
        }
    }
}

public enum HistoryRetention: String, Codable, Sendable, CaseIterable, Identifiable {
    case oneWeek = "7_days"
    case oneMonth = "30_days"
    case threeMonths = "90_days"
    case forever = "forever"

    public var id: String { rawValue }

    public func localizedName(for language: AppLanguage) -> String {
        switch language {
        case .english:
            switch self {
            case .oneWeek: return "7 Days"
            case .oneMonth: return "30 Days"
            case .threeMonths: return "90 Days"
            case .forever: return "Never Delete"
            }
        case .persian:
            switch self {
            case .oneWeek: return "۷ روز"
            case .oneMonth: return "۳۰ روز"
            case .threeMonths: return "۹۰ روز"
            case .forever: return "حذف نشود"
            }
        }
    }

    public var maxAgeInSeconds: TimeInterval? {
        switch self {
        case .oneWeek: return 7 * 86400
        case .oneMonth: return 30 * 86400
        case .threeMonths: return 90 * 86400
        case .forever: return nil
        }
    }
}
