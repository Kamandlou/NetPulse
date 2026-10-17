import Foundation
import Testing
@testable import NetPulseCore

@Suite struct OutageHistoryStoreTests {

    @Test @MainActor func recordOutageLifecycle() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_outages_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = OutageHistoryStore(fileURL: tempURL)
        #expect(store.records.isEmpty)
        #expect(store.ongoingOutage == nil)

        let startDate = Date(timeIntervalSince1970: 1000)
        let outage = store.recordOutageStarted(
            startDate: startDate,
            interfaceType: .wifi,
            technicalReason: "Connection timeout"
        )

        #expect(outage.isOngoing)
        #expect(store.ongoingOutage?.id == outage.id)
        #expect(store.records.count == 1)

        // Ending outage after 60 seconds
        let endDate = Date(timeIntervalSince1970: 1060)
        let resolved = store.recordOutageEnded(endDate: endDate)

        #expect(resolved != nil)
        #expect(!resolved!.isOngoing)
        #expect(resolved?.duration == 60)
        #expect(store.ongoingOutage == nil)
        #expect(store.records.first?.duration == 60)
    }

    @Test @MainActor func sleepDurationDeduction() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_outages_sleep_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = OutageHistoryStore(fileURL: tempURL)
        let start = Date(timeIntervalSince1970: 1000)
        _ = store.recordOutageStarted(startDate: start, interfaceType: .ethernet, technicalReason: nil)

        // Mac slept for 120 seconds during outage
        store.deductSleepDuration(120)

        // Outage ends after 200 total elapsed seconds
        let end = Date(timeIntervalSince1970: 1200)
        let resolved = store.recordOutageEnded(endDate: end)

        // Expected downtime: 200 - 120 = 80 seconds
        #expect(resolved?.duration == 80)
    }

    @Test @MainActor func persistenceAndReload() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_outages_persist_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store1 = OutageHistoryStore(fileURL: tempURL)
        let start = Date()
        _ = store1.recordOutageStarted(startDate: start, interfaceType: .wifi, technicalReason: "Captive redirect")
        _ = store1.recordOutageEnded(endDate: start.addingTimeInterval(45))

        // Create new store pointing to same file (simulating app restart)
        let store2 = OutageHistoryStore(fileURL: tempURL)
        #expect(store2.records.count == 1)
        #expect(store2.records.first?.technicalReason == "Captive redirect")
        #expect(store2.records.first?.duration == 45)
    }

    @Test @MainActor func exportCSVAndJSON() {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_outages_export_\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let store = OutageHistoryStore(fileURL: tempURL)
        let start = Date(timeIntervalSince1970: 1700000000)
        _ = store.recordOutageStarted(startDate: start, interfaceType: .wifi, technicalReason: "No route to host")
        _ = store.recordOutageEnded(endDate: start.addingTimeInterval(30))

        let csv = store.exportCSV()
        #expect(csv.contains("No route to host"))
        #expect(csv.contains("wifi"))
        #expect(csv.contains("30"))

        let json = store.exportJSON()
        #expect(json.contains("No route to host"))
        #expect(json.contains("\"duration\" : 30"))
    }
}
