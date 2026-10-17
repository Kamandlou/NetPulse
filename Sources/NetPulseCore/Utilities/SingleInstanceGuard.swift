import AppKit
import Darwin

public final class SingleInstanceGuard {
    private static var lockFileDescriptor: Int32 = -1

    /// Ensures that only a single instance of NetPulse runs at any given time.
    /// If an existing instance is already running, it activates the existing instance and returns false.
    @discardableResult
    public static func enforceSingleInstance(bundleIdentifier: String? = nil) -> Bool {
        // If this process already acquired the lock in this run, return true
        if lockFileDescriptor >= 0 {
            return true
        }

        let bundleID = bundleIdentifier ?? Bundle.main.bundleIdentifier ?? "ir.kamandlou.NetPulse"
        let currentPID = ProcessInfo.processInfo.processIdentifier

        // 1. Check running applications via LaunchServices
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        let otherApps = runningApps.filter { $0.processIdentifier != currentPID }

        if let existing = otherApps.first {
            activateApp(existing)
            return false
        }

        // 2. Advisory POSIX file lock to handle rapid simultaneous launches
        let lockName = "\(bundleID).lock"
        let lockPath = (NSTemporaryDirectory() as NSString).appendingPathComponent(lockName)
        let fd = open(lockPath, O_CREAT | O_WRONLY, 0o644)
        if fd >= 0 {
            if flock(fd, LOCK_EX | LOCK_NB) != 0 {
                // Another instance holds the lock
                close(fd)
                if let existing = otherApps.first {
                    activateApp(existing)
                }
                return false
            }
            // Lock acquired; hold file descriptor open for process lifetime
            lockFileDescriptor = fd
        }

        return true
    }

    private static func activateApp(_ app: NSRunningApplication) {
        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}
