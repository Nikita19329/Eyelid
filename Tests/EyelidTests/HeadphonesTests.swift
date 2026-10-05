import Foundation
import IOKit.ps
import Testing
@testable import Eyelid

@Suite("Headphones")
struct HeadphonesTests {
    /// What macOS reports for AirPods Pro with the left earbud in an ear and the right one in the case,
    /// trimmed to the keys Eyelid reads.
    private func airpods(left: String = kIOPSBatteryPowerValue, right: String = kIOPSACPowerValue) -> [[String: Any]] {
        [
            ["Name": "AirPods Pro Case", "Part Identifier": "Case", "Current Capacity": 48, "Product ID": 0x2024,
             "Power Source State": kIOPSBatteryPowerValue],
            ["Name": "AirPods Pro", "Part Identifier": "Left", "Current Capacity": 100, "Product ID": 0x2024,
             "Power Source State": left],
            ["Name": "AirPods Pro", "Part Identifier": "Right", "Current Capacity": 81, "Product ID": 0x2024,
             "Power Source State": right],
        ]
    }

    private func battery(_ sources: [[String: Any]], name: String = "AirPods Pro", productID: Int? = 0x2024) -> HeadphonesBattery? {
        HeadphonesBattery(powerSources: sources, deviceName: name, productID: productID)
    }

    @Test func readsEachEarbudAndTheCase() throws {
        let battery = try #require(battery(airpods()))

        #expect(battery.left == 100)
        #expect(battery.right == 81)
        #expect(battery.case == 48)
        #expect(battery.rightIsInCase)
        #expect(!battery.leftIsInCase)
    }

    @Test func theEarbudInUseIsTheOneOutOfTheCase() throws {
        let leftOnly = try #require(battery(airpods()))
        #expect(leftOnly.singleEarbud == .left)
        #expect(leftOnly.level == 100)

        let rightOnly = try #require(battery(airpods(left: kIOPSACPowerValue, right: kIOPSBatteryPowerValue)))
        #expect(rightOnly.singleEarbud == .right)
        #expect(rightOnly.level == 81)
    }

    @Test func bothEarbudsShowTheEmptierOne() throws {
        let both = try #require(battery(airpods(left: kIOPSBatteryPowerValue, right: kIOPSBatteryPowerValue)))

        #expect(both.singleEarbud == nil)
        #expect(both.level == 81)
        #expect(both.isInUse)
    }

    @Test func bothInTheCaseIsNotInUseYet() throws {
        let stale = try #require(battery(airpods(left: kIOPSACPowerValue, right: kIOPSACPowerValue)))

        #expect(!stale.isInUse)
        #expect(stale.singleEarbud == nil)
    }

    @Test func overEarHeadphonesHaveOneLevel() throws {
        let max = try #require(battery([["Name": "AirPods Max", "Current Capacity": 64, "Product ID": 0x200A]],
                                       name: "AirPods Max", productID: 0x200A))

        #expect(max.level == 64)
        #expect(max.isInUse)
    }

    @Test func otherDevicesDontCount() {
        #expect(battery(airpods(), name: "Beats Studio") == nil)
        #expect(battery(airpods(), productID: 0x200E) == nil)
        #expect(battery([]) == nil)
    }

    @Test func onlyNewBluetoothOutputsCountAsConnecting() {
        func device(_ id: String, _ transport: OutputDevice.Transport) -> OutputDevice {
            OutputDevice(id: id, name: id, transport: transport, isHeadphoneJack: false, modelUID: nil)
        }
        let devices = [device("speakers", .builtIn), device("airpods", .bluetooth), device("beats", .bluetooth)]

        let new = HeadphonesService.newBluetoothDevices(in: devices, known: ["beats"])

        #expect(new.map(\.id) == ["airpods"])
    }

    @Test func earbudsHaveSymbolsForEachSide() {
        #expect(DeviceIcon.airpodsPro.earbudSymbolName(.left) == "airpodpro.left")
        #expect(DeviceIcon.airpods4.earbudSymbolName(.right) == "airpod.gen3.right")
        #expect(DeviceIcon.airpodsMax.earbudSymbolName(.left) == nil)
        #expect(DeviceIcon.headphones.earbudSymbolName(.left) == nil)
    }

    @Test func theAccessoryPowerSourcesCallStillExists() {
        // The list itself depends on what's connected, so only the private call is checked.
        #expect(AccessoryPowerSources.isAvailable)
    }
}
