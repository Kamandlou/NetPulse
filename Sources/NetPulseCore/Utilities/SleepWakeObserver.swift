import Foundation
import AppKit

public protocol SleepWakeObserving: AnyObject, Sendable {
    func start(
        onSleep: @escaping @Sendable (Date) -> Void,
        onWake: @escaping @Sendable (Date, TimeInterval) -> Void
    )
    func stop()
}

public final class SleepWakeObserver: SleepWakeObserving, @unchecked Sendable {
    private var sleepObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var sleepStartDate: Date?
    private let lock = NSLock()

    public init() {}

    public func start(
        onSleep: @escaping @Sendable (Date) -> Void,
        onWake: @escaping @Sendable (Date, TimeInterval) -> Void
    ) {
        stop()

        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            self.lock.lock()
            self.sleepStartDate = now
            self.lock.unlock()
            onSleep(now)
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            let now = Date()
            self.lock.lock()
            let sleepStart = self.sleepStartDate ?? now
            let sleepDuration = max(0, now.timeIntervalSince(sleepStart))
            self.sleepStartDate = nil
            self.lock.unlock()
            onWake(now, sleepDuration)
        }
    }

    public func stop() {
        if let observer = sleepObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            sleepObserver = nil
        }
        if let observer = wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            wakeObserver = nil
        }
    }

    deinit {
        stop()
    }
}
