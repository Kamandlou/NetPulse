import Foundation
import SwiftUI

public struct L10n {
    public static func string(_ key: Key, language: AppLanguage) -> String {
        switch language {
        case .english:
            return englishStrings[key] ?? key.rawValue
        case .persian:
            return persianStrings[key] ?? (englishStrings[key] ?? key.rawValue)
        }
    }

    public enum Key: String, CaseIterable {
        // App
        case appName = "app_name"
        case appDescription = "app_description"
        case developerName = "developer_name"

        // Status
        case internetConnected = "internet_connected"
        case internetDisconnected = "internet_disconnected"
        case checkingConnection = "checking_connection"
        case connectionUnstable = "connection_unstable"
        case unknownStatus = "unknown_status"
        case monitoringPaused = "monitoring_paused"

        // Details
        case networkInterface = "network_interface"
        case wifiSSID = "wifi_ssid"
        case connectionStatus = "connection_status"
        case lastCheck = "last_check"
        case latency = "latency"
        case currentUptime = "current_uptime"
        case notAvailable = "not_available"
        case justNow = "just_now"
        case secondsAgo = "seconds_ago"

        // Statistics
        case totalDowntimeToday = "total_downtime_today"
        case outagesToday = "outages_today"
        case lastOutageDuration = "last_outage_duration"
        case uptimeToday = "uptime_today"
        case availability = "availability"
        case longestOutage = "longest_outage"
        case averageDuration = "average_duration"
        case totalOutages = "total_outages"
        case totalDowntime = "total_downtime"

        // Actions
        case checkNow = "check_now"
        case pauseMonitoring = "pause_monitoring"
        case resumeMonitoring = "resume_monitoring"
        case settings = "settings"
        case connectionHistory = "connection_history"
        case quit = "quit"

        // Settings Tabs
        case tabGeneral = "tab_general"
        case tabNotifications = "tab_notifications"
        case tabConnectivity = "tab_connectivity"
        case tabHistory = "tab_history"
        case tabAbout = "tab_about"

        // General Settings
        case launchAtLogin = "launch_at_login"
        case startMonitoringAuto = "start_monitoring_auto"
        case showDockIcon = "show_dock_icon"
        case showLatencyMenuBar = "show_latency_menu_bar"
        case enableMonitoring = "enable_monitoring"
        case language = "language"
        case appearance = "appearance"

        // Notification Settings
        case enableNotifications = "enable_notifications"
        case notifyOnDisconnect = "notify_on_disconnect"
        case notifyOnReconnect = "notify_on_reconnect"
        case playNotificationSounds = "play_notification_sounds"
        case includeDowntime = "include_downtime"
        case minimumOutageDuration = "min_outage_duration"
        case notificationCooldown = "notification_cooldown"

        // Connectivity Settings
        case checkInterval = "check_interval"
        case requestTimeout = "request_timeout"
        case consecutiveFailures = "consecutive_failures"
        case consecutiveSuccesses = "consecutive_successes"
        case checkingStrategy = "checking_strategy"
        case endpoints = "endpoints"
        case resetDefaults = "reset_defaults"
        case testSelected = "test_selected"
        case addEndpoint = "add_endpoint"
        case editEndpoint = "edit_endpoint"
        case delete = "delete"
        case endpointName = "endpoint_name"
        case endpointURL = "endpoint_url"
        case expectedStatus = "expected_status"
        case expectedBody = "expected_body"
        case cancel = "cancel"
        case save = "save"
        case testSuccess = "test_success"
        case testFailure = "test_failure"

        // History Settings & Screen
        case enableLocalHistory = "enable_local_history"
        case historyRetention = "history_retention"
        case clearAllHistory = "clear_all_history"
        case clearHistoryConfirmTitle = "clear_history_confirm_title"
        case clearHistoryConfirmMessage = "clear_history_confirm_message"
        case exportCSV = "export_csv"
        case exportJSON = "export_json"
        case filterToday = "filter_today"
        case filter7Days = "filter_7_days"
        case filter30Days = "filter_30_days"
        case filterAllTime = "filter_all_time"
        case searchOutages = "search_outages"
        case noOutagesRecorded = "no_outages_recorded"
        case ongoingOutage = "ongoing_outage"
        case startTime = "start_time"
        case endTime = "end_time"
        case duration = "duration"
        case interface = "interface"
        case reason = "reason"
        case copy = "copy"

        // Notification Messages
        case notifDisconnectTitle = "notif_disconnect_title"
        case notifDisconnectBody = "notif_disconnect_body"
        case notifReconnectTitle = "notif_reconnect_title"
        case notifReconnectBody = "notif_reconnect_body"
        case notifReconnectBodyWithDowntime = "notif_reconnect_body_with_downtime"
    }

    private static let englishStrings: [Key: String] = [
        .appName: "NetPulse",
        .appDescription: "Lightweight, privacy-friendly macOS menu bar monitor for real internet connectivity.",
        .developerName: "Amir Hossein Kamandlou",

        .internetConnected: "Internet Connected",
        .internetDisconnected: "Internet Disconnected",
        .checkingConnection: "Checking Connection...",
        .connectionUnstable: "Connection Unstable",
        .unknownStatus: "Unknown Status",
        .monitoringPaused: "Monitoring Paused",

        .networkInterface: "Network Interface",
        .wifiSSID: "Wi-Fi Network",
        .connectionStatus: "Connection Status",
        .lastCheck: "Last Check",
        .latency: "Latency",
        .currentUptime: "Current Uptime",
        .notAvailable: "N/A",
        .justNow: "Just now",
        .secondsAgo: "%d sec ago",

        .totalDowntimeToday: "Downtime Today",
        .outagesToday: "Outages Today",
        .lastOutageDuration: "Last Outage",
        .uptimeToday: "Uptime Today",
        .availability: "Availability",
        .longestOutage: "Longest Outage",
        .averageDuration: "Avg Outage",
        .totalOutages: "Total Outages",
        .totalDowntime: "Total Downtime",

        .checkNow: "Check Connection Now",
        .pauseMonitoring: "Pause Monitoring",
        .resumeMonitoring: "Resume Monitoring",
        .settings: "Settings...",
        .connectionHistory: "Connection History...",
        .quit: "Quit NetPulse",

        .tabGeneral: "General",
        .tabNotifications: "Notifications",
        .tabConnectivity: "Connectivity",
        .tabHistory: "History & Privacy",
        .tabAbout: "About",

        .launchAtLogin: "Launch at Login",
        .startMonitoringAuto: "Start monitoring automatically on launch",
        .showDockIcon: "Show Dock Icon",
        .showLatencyMenuBar: "Show latency in menu bar",
        .enableMonitoring: "Enable Background Monitoring",
        .language: "Language",
        .appearance: "Appearance",

        .enableNotifications: "Enable Notifications",
        .notifyOnDisconnect: "Notify when internet disconnects",
        .notifyOnReconnect: "Notify when internet reconnects",
        .playNotificationSounds: "Play notification sound",
        .includeDowntime: "Include downtime duration in reconnection notification",
        .minimumOutageDuration: "Minimum outage before disconnect alert",
        .notificationCooldown: "Notification cooldown",

        .checkInterval: "Check Interval",
        .requestTimeout: "Request Timeout",
        .consecutiveFailures: "Consecutive failures to mark Offline",
        .consecutiveSuccesses: "Consecutive successes to mark Online",
        .checkingStrategy: "Checking Strategy",
        .endpoints: "Connectivity Verification Endpoints",
        .resetDefaults: "Reset to Defaults",
        .testSelected: "Test Endpoints",
        .addEndpoint: "Add Endpoint",
        .editEndpoint: "Edit Endpoint",
        .delete: "Delete",
        .endpointName: "Name",
        .endpointURL: "URL",
        .expectedStatus: "Expected HTTP Status Code (optional)",
        .expectedBody: "Expected Response Substring (optional)",
        .cancel: "Cancel",
        .save: "Save",
        .testSuccess: "Online",
        .testFailure: "Failed",

        .enableLocalHistory: "Record Outage History Locally",
        .historyRetention: "History Retention",
        .clearAllHistory: "Clear All History",
        .clearHistoryConfirmTitle: "Clear Outage History?",
        .clearHistoryConfirmMessage: "This will permanently remove all recorded outage history from this Mac.",
        .exportCSV: "Export History as CSV",
        .exportJSON: "Export History as JSON",
        .filterToday: "Today",
        .filter7Days: "Last 7 Days",
        .filter30Days: "Last 30 Days",
        .filterAllTime: "All Time",
        .searchOutages: "Search outages...",
        .noOutagesRecorded: "No internet outages recorded.",
        .ongoingOutage: "Ongoing Outage",
        .startTime: "Start Time",
        .endTime: "End Time",
        .duration: "Duration",
        .interface: "Interface",
        .reason: "Reason",
        .copy: "Copy",

        .notifDisconnectTitle: "Internet Disconnected",
        .notifDisconnectBody: "Your internet connection has been lost.",
        .notifReconnectTitle: "Internet Connected",
        .notifReconnectBody: "Your internet connection has been restored.",
        .notifReconnectBodyWithDowntime: "Your internet connection has been restored. Downtime: %@"
    ]

    private static let persianStrings: [Key: String] = [
        .appName: "NetPulse",
        .appDescription: "ابزار سبک و امن نوار منوی macOS برای پایش بلادرنگ اتصال واقعی به اینترنت.",
        .developerName: "امیرحسین کمندلو",

        .internetConnected: "اتصال اینترنت برقرار است",
        .internetDisconnected: "اتصال اینترنت قطع است",
        .checkingConnection: "در حال بررسی اتصال...",
        .connectionUnstable: "اتصال اینترنت ناپایدار است",
        .unknownStatus: "وضعیت نامشخص",
        .monitoringPaused: "پایش موقتاً متوقف شد",

        .networkInterface: "رابط شبکه",
        .wifiSSID: "نام شبکه وای‌فای (SSID)",
        .connectionStatus: "وضعیت اتصال",
        .lastCheck: "آخرین بررسی",
        .latency: "تأخیر (Latency)",
        .currentUptime: "مدت پایداری فعلی",
        .notAvailable: "نامشخص",
        .justNow: "هم‌اکنون",
        .secondsAgo: "%d ثانیه پیش",

        .totalDowntimeToday: "مدت قطعی امروز",
        .outagesToday: "تعداد قطعی‌های امروز",
        .lastOutageDuration: "آخرین قطعی",
        .uptimeToday: "پایداری امروز",
        .availability: "درصد دسترسی",
        .longestOutage: "طولانی‌ترین قطعی",
        .averageDuration: "میانگین قطعی",
        .totalOutages: "کل قطعی‌ها",
        .totalDowntime: "کل زمان قطعی",

        .checkNow: "بررسی مجدد اتصال همین حالا",
        .pauseMonitoring: "توقف موقت پایش",
        .resumeMonitoring: "ادامه پایش",
        .settings: "تنظیمات...",
        .connectionHistory: "تاریخچه قطعی‌های اینترنت...",
        .quit: "خروج از NetPulse",

        .tabGeneral: "عمومی",
        .tabNotifications: "اعلان‌ها",
        .tabConnectivity: "پایش اتصال",
        .tabHistory: "تاریخچه و حریم خصوصی",
        .tabAbout: "درباره",

        .launchAtLogin: "اجرای خودکار هنگام ورود به سیستم (Launch at Login)",
        .startMonitoringAuto: "آغاز خودکار پایش با باز شدن برنامه",
        .showDockIcon: "نمایش آیکون برنامه در داک (Dock)",
        .showLatencyMenuBar: "نمایش پینگ (Latency) در نوار منو",
        .enableMonitoring: "فعال بودن پایش پس‌زمینه",
        .language: "زبان (Language)",
        .appearance: "حالت ظاهری",

        .enableNotifications: "فعال‌سازی اعلان‌های سیستم",
        .notifyOnDisconnect: "ارسال اعلان هنگام قطع اینترنت",
        .notifyOnReconnect: "ارسال اعلان هنگام وصل مجدد اینترنت",
        .playNotificationSounds: "پخش صدای اعلان",
        .includeDowntime: "درج مدت زمان قطعی در اعلان وصل مجدد",
        .minimumOutageDuration: "حداقل زمان قطعی برای ارسال اعلان",
        .notificationCooldown: "زمان خنک‌سازی میان اعلان‌ها (Cooldown)",

        .checkInterval: "فاصله بررسی دوره‌ای",
        .requestTimeout: "مهلت پاسخ درخواست (Timeout)",
        .consecutiveFailures: "تعداد خطای متوالی برای ثبت وضعیت «قطع»",
        .consecutiveSuccesses: "تعداد موفقیت متوالی برای ثبت وضعیت «وصل»",
        .checkingStrategy: "راهبرد پایش",
        .endpoints: "آدرس‌های سرور سنجش اتصال",
        .resetDefaults: "بازنشانی به حالت پیش‌فرض",
        .testSelected: "تست آدرس‌های سنجش",
        .addEndpoint: "افزودن آدرس جدید",
        .editEndpoint: "ویرایش آدرس",
        .delete: "حذف",
        .endpointName: "نام آدرس",
        .endpointURL: "نشانی وب (URL)",
        .expectedStatus: "کد وضعیت HTTP مورد انتظار (اختیاری)",
        .expectedBody: "متن مورد انتظار در پاسخ (اختیاری)",
        .cancel: "انصراف",
        .save: "ذخیره",
        .testSuccess: "متصل",
        .testFailure: "ناموفق",

        .enableLocalHistory: "ثبت محلی تاریخچه قطعی‌ها",
        .historyRetention: "مدت نگهداری تاریخچه",
        .clearAllHistory: "پاک‌کردن تمام تاریخچه",
        .clearHistoryConfirmTitle: "آیا تاریخچه قطعی‌ها پاک شود؟",
        .clearHistoryConfirmMessage: "تمام سوابق قطعی ذخیره‌شده روی این مک برای همیشه حذف خواهند شد.",
        .exportCSV: "خروجی پرونده CSV",
        .exportJSON: "خروجی پرونده JSON",
        .filterToday: "امروز",
        .filter7Days: "۷ روز گذشته",
        .filter30Days: "۳۰ روز گذشته",
        .filterAllTime: "همه زمان‌ها",
        .searchOutages: "جستجوی قطعی‌ها...",
        .noOutagesRecorded: "هیچ قطعی اینترنتی ثبت نشده است.",
        .ongoingOutage: "قطعی در حال حاضر",
        .startTime: "زمان آغاز",
        .endTime: "زمان پایان",
        .duration: "مدت زمان",
        .interface: "رابط شبکه",
        .reason: "علت بروز",
        .copy: "کپی",

        .notifDisconnectTitle: "اتصال اینترنت قطع شد",
        .notifDisconnectBody: "ارتباط رایانه شما با شبکه جهانی اینترنت قطع گردید.",
        .notifReconnectTitle: "اتصال اینترنت وصل شد",
        .notifReconnectBody: "اتصال اینترنت با موفقیت بازیابی شد.",
        .notifReconnectBodyWithDowntime: "اتصال اینترنت با موفقیت بازیابی شد. مدت زمان قطعی: %@"
    ]
}
