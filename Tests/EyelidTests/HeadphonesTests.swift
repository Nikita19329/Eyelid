import Foundation
import Testing
@testable import Eyelid

@Suite("Headphones")
struct HeadphonesTests {
    /// Trimmed from `system_profiler SPBluetoothDataType -json` with AirPods Pro connected.
    private let report = Data("""
    {
      "SPBluetoothDataType": [{
        "controller_properties": { "controller_state": "attrib_on" },
        "device_connected": [
          { "AirPods Pro": {
              "device_address": "AA:BB:CC:DD:EE:FF",
              "device_batteryLevelCase": "48%",
              "device_batteryLevelLeft": "100%",
              "device_batteryLevelRight": "93%",
              "device_minorType": "Headphones"
          } },
          { "Speaker": { "device_minorType": "Speaker" } },
          { "AirPods Max": { "device_batteryLevelMain": "64%" } }
        ],
        "device_not_connected": [
          { "Old AirPods": { "device_batteryLevelLeft": "10%", "device_batteryLevelRight": "10%" } }
        ]
      }]
    }
    """.utf8)

    @Test func readsEachEarbudAndTheCase() throws {
        let battery = try #require(HeadphonesBattery(systemProfilerJSON: report, deviceName: "AirPods Pro"))

        #expect(battery == HeadphonesBattery(left: 100, right: 93, case: 48, main: nil))
        // The emptier earbud runs out first.
        #expect(battery.level == 93)
    }

    @Test func overEarHeadphonesHaveOneLevel() throws {
        let battery = try #require(HeadphonesBattery(systemProfilerJSON: report, deviceName: "AirPods Max"))

        #expect(battery.level == 64)
    }

    @Test func noBatteryForDevicesThatDontReportOneOrArentConnected() {
        #expect(HeadphonesBattery(systemProfilerJSON: report, deviceName: "Speaker") == nil)
        #expect(HeadphonesBattery(systemProfilerJSON: report, deviceName: "Old AirPods") == nil)
        #expect(HeadphonesBattery(systemProfilerJSON: report, deviceName: "Nothing") == nil)
        #expect(HeadphonesBattery(systemProfilerJSON: Data("not json".utf8), deviceName: "AirPods Pro") == nil)
    }

    @Test func onlyNewBluetoothOutputsCountAsConnecting() {
        func device(_ id: String, _ transport: OutputDevice.Transport) -> OutputDevice {
            OutputDevice(id: id, name: id, transport: transport, isHeadphoneJack: false, modelUID: nil)
        }
        let devices = [device("speakers", .builtIn), device("airpods", .bluetooth), device("beats", .bluetooth)]

        let new = HeadphonesService.newBluetoothDevices(in: devices, known: ["beats"])

        #expect(new.map(\.id) == ["airpods"])
    }
}
