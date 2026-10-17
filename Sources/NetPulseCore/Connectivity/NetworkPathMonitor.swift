import Foundation
import Network
import CoreWLAN

public protocol NetworkPathMonitoring: AnyObject, Sendable {
    func start(onUpdate: @escaping @Sendable (NetworkPathInfo) -> Void)
    func stop()
    func currentPathInfo() -> NetworkPathInfo
}

public struct NetworkPathInfo: Sendable, Equatable {
    public let isSatisfied: Bool
    public let interfaceType: NetworkInterfaceType
    public let ssid: String?
    public let isExpensive: Bool
    public let isConstrained: Bool

    public init(
        isSatisfied: Bool,
        interfaceType: NetworkInterfaceType,
        ssid: String? = nil,
        isExpensive: Bool = false,
        isConstrained: Bool = false
    ) {
        self.isSatisfied = isSatisfied
        self.interfaceType = interfaceType
        self.ssid = ssid
        self.isExpensive = isExpensive
        self.isConstrained = isConstrained
    }
}

public final class SystemNetworkPathMonitor: NetworkPathMonitoring, @unchecked Sendable {
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "ir.kamandlou.NetPulse.NWPathMonitor", qos: .utility)
    private var isRunning = false
    private let lock = NSLock()
    private var lastInfo = NetworkPathInfo(isSatisfied: false, interfaceType: .none)

    public init() {
        self.monitor = NWPathMonitor()
    }

    public func start(onUpdate: @escaping @Sendable (NetworkPathInfo) -> Void) {
        lock.lock()
        guard !isRunning else {
            lock.unlock()
            return
        }
        isRunning = true
        lock.unlock()

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }
            let info = self.extractInfo(from: path)
            self.lock.lock()
            self.lastInfo = info
            self.lock.unlock()
            onUpdate(info)
        }

        monitor.start(queue: queue)
    }

    public func stop() {
        lock.lock()
        defer { lock.unlock() }
        guard isRunning else { return }
        monitor.cancel()
        isRunning = false
    }

    public func currentPathInfo() -> NetworkPathInfo {
        lock.lock()
        defer { lock.unlock() }
        return lastInfo
    }

    private func extractInfo(from path: NWPath) -> NetworkPathInfo {
        let isSatisfied = (path.status == .satisfied)
        let interfaceType: NetworkInterfaceType

        if path.usesInterfaceType(.wifi) {
            interfaceType = .wifi
        } else if path.usesInterfaceType(.wiredEthernet) {
            interfaceType = .ethernet
        } else if path.usesInterfaceType(.cellular) {
            interfaceType = .cellular
        } else if path.usesInterfaceType(.other) {
            interfaceType = .other
        } else {
            interfaceType = .none
        }

        let ssid = (interfaceType == .wifi) ? Self.fetchCurrentSSID() : nil

        return NetworkPathInfo(
            isSatisfied: isSatisfied,
            interfaceType: interfaceType,
            ssid: ssid,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained
        )
    }

    public static func fetchCurrentSSID() -> String? {
        #if os(macOS)
        let client = CWWiFiClient.shared()
        if let interface = client.interface() {
            return interface.ssid()
        }
        #endif
        return nil
    }
}
