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
    public func detectVPN() -> VPNStatusInfo {
        // 1. Check SystemConfiguration DynamicStore for primary network service
        if let dynamicStore = SCDynamicStoreCreate(nil, "ir.kamandlou.NetPulse" as CFString, nil, nil) {
            if let ipv4 = SCDynamicStoreCopyValue(dynamicStore, "State:/Network/Global/IPv4" as CFString) as? [String: Any] {
                if let primaryInterface = ipv4["PrimaryInterface"] as? String, isVPNInterface(primaryInterface) {
                    return VPNStatusInfo(isConnected: true, interfaceName: primaryInterface)
                }

                if let primaryService = ipv4["PrimaryService"] as? String {
                    let serviceKey = "State:/Network/Service/\(primaryService)/IPv4" as CFString
                    if let serviceDict = SCDynamicStoreCopyValue(dynamicStore, serviceKey) as? [String: Any],
                       let ifName = serviceDict["InterfaceName"] as? String,
                       isVPNInterface(ifName) {
                        return VPNStatusInfo(isConnected: true, interfaceName: ifName)
                    }
                }
            }
        }

        // 2. Fall back to inspecting running network tunnel interfaces (getifaddrs)
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

            if isUp && isRunning && isVPNInterface(name) {
                return VPNStatusInfo(isConnected: true, interfaceName: name)
            }
        }

        return VPNStatusInfo(isConnected: false, interfaceName: nil)
    }

    private func isVPNInterface(_ name: String) -> Bool {
        let lower = name.lowercased()
        return lower.hasPrefix("utun") ||
               lower.hasPrefix("ppp") ||
               lower.hasPrefix("ipsec") ||
               lower.hasPrefix("tun") ||
               lower.hasPrefix("tap") ||
               lower.hasPrefix("wireguard")
    }
}
