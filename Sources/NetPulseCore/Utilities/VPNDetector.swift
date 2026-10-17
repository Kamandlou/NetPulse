import Foundation
import SystemConfiguration

public struct VPNStatusInfo: Sendable, Equatable {
    public let isConnected: Bool
    public let interfaceName: String?

    public init(isConnected: Bool, interfaceName: String? = nil) {
        self.isConnected = isConnected
        self.interfaceName = interfaceName
    }
}

public final class VPNDetector: Sendable {
    public static let shared = VPNDetector()

    public init() {}

    /// Detects if an active VPN tunnel (WireGuard, OpenVPN, IKEv2, Cisco, Tailscale, etc.) is active on macOS.
    /// In macOS:
    /// - System utun0..utun5 are reserved internal tunnels (AirDrop, Continuity, Back to My Mac).
    /// - User VPN tunnels are either the PrimaryInterface in State:/Network/Global/IPv4 or have an active State:/Network/Service/*/VPN entry.
    /// - Third-party VPN tunnels (WireGuard, Clash, V2Ray, OpenVPN) assign an IPv4 address (AF_INET = 2) to a utun/tun interface.
    public func detectVPN() -> VPNStatusInfo {
        guard let dynamicStore = SCDynamicStoreCreate(nil, "ir.kamandlou.NetPulse" as CFString, nil, nil) else {
            return fallbackDetectVPN()
        }

        // 1. Check if PrimaryInterface is a VPN interface (utun*, ppp*, ipsec*)
        if let ipv4 = SCDynamicStoreCopyValue(dynamicStore, "State:/Network/Global/IPv4" as CFString) as? [String: Any] {
            if let primaryInterface = ipv4["PrimaryInterface"] as? String, isUserVPNInterfaceName(primaryInterface) {
                return VPNStatusInfo(isConnected: true, interfaceName: primaryInterface)
            }

            if let primaryService = ipv4["PrimaryService"] as? String {
                // Check if this primary service has a VPN dictionary
                let vpnKey = "State:/Network/Service/\(primaryService)/VPN" as CFString
                if let vpnDict = SCDynamicStoreCopyValue(dynamicStore, vpnKey) as? [String: Any] {
                    // Status == 7 indicates Connected in macOS VPN status enum
                    let status = vpnDict["Status"] as? Int ?? 0
                    if status == 7 || status > 0 {
                        let ifName = (ipv4["PrimaryInterface"] as? String) ?? "VPN"
                        return VPNStatusInfo(isConnected: true, interfaceName: ifName)
                    }
                }
            }
        }

        // 2. Check any other active VPN service state in SCDynamicStore
        let vpnServiceKeys = SCDynamicStoreCopyKeyList(dynamicStore, "State:/Network/Service/.*/VPN" as CFString) as? [String] ?? []
        for key in vpnServiceKeys {
            if let vpnDict = SCDynamicStoreCopyValue(dynamicStore, key as CFString) as? [String: Any] {
                let status = vpnDict["Status"] as? Int ?? 0
                if status == 7 || status == 1 { // 7 = Connected
                    return VPNStatusInfo(isConnected: true, interfaceName: "VPN")
                }
            }
        }

        // 3. Check for third-party VPN tunnel interfaces that have an assigned IPv4 address (family 2 = AF_INET)
        // macOS built-in system utuns (AirDrop/Continuity) only have Link (18) and IPv6 (30), NEVER IPv4!
        return fallbackDetectVPN()
    }

    private func fallbackDetectVPN() -> VPNStatusInfo {
        var ifaddrsPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrsPtr) == 0, let first = ifaddrsPtr else {
            return VPNStatusInfo(isConnected: false, interfaceName: nil)
        }
        defer { freeifaddrs(ifaddrsPtr) }

        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let name = String(cString: ptr.pointee.ifa_name)
            let flags = Int32(ptr.pointee.ifa_flags)
            let isUp = (flags & IFF_UP) != 0
            let isRunning = (flags & IFF_RUNNING) != 0

            guard isUp && isRunning && isUserVPNInterfaceName(name) else { continue }
            guard let addr = ptr.pointee.ifa_addr else { continue }

            // AF_INET is 2 (IPv4). Only actual routing VPNs carry an IPv4 address.
            if addr.pointee.sa_family == UInt8(AF_INET) {
                return VPNStatusInfo(isConnected: true, interfaceName: name)
            }
        }

        return VPNStatusInfo(isConnected: false, interfaceName: nil)
    }

    private func isUserVPNInterfaceName(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("utun") ||
               lower.hasPrefix("ppp") ||
               lower.hasPrefix("ipsec") ||
               lower.hasPrefix("tun") ||
               lower.hasPrefix("tap") ||
               lower.hasPrefix("wireguard")
    }
}
