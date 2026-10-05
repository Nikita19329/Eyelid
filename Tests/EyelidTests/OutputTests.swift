import Foundation
import IOKit.ps
import Testing
@testable import Eyelid

@Suite("Sound output")
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

    private func parse(_ sources: [[String: Any]], name: String = "AirPods Pro", productID: Int? = 0x2024) -> HeadphonesBattery? {
        HeadphonesBattery(powerSources: sources, deviceName: name, productID: productID)
    }

    @Test func readsEachEarbudAndTheCase() throws {
        let battery = try #require(parse(airpods()))

        #expect(battery.left == 100)
        #expect(battery.right == 81)
        #expect(battery.case == 48)
        #expect(battery.rightIsInCase)
        #expect(!battery.leftIsInCase)
    }

    @Test func theEarbudInUseIsTheOneOutOfTheCase() throws {
        let leftOnly = try #require(parse(airpods()))
        #expect(leftOnly.singleEarbud == .left)
        #expect(leftOnly.level == 100)

        let rightOnly = try #require(parse(airpods(left: kIOPSACPowerValue, right: kIOPSBatteryPowerValue)))
        #expect(rightOnly.singleEarbud == .right)
        #expect(rightOnly.level == 81)
    }

    @Test func bothEarbudsShowTheEmptierOne() throws {
        let both = try #require(parse(airpods(left: kIOPSBatteryPowerValue, right: kIOPSBatteryPowerValue)))

        #expect(both.singleEarbud == nil)
        #expect(both.level == 81)
        #expect(both.isInUse)
    }

    @Test func bothInTheCaseIsNotInUseYet() throws {
        let stale = try #require(parse(airpods(left: kIOPSACPowerValue, right: kIOPSACPowerValue)))

        #expect(!stale.isInUse)
        #expect(stale.singleEarbud == nil)
    }

    @Test func overEarHeadphonesHaveOneLevel() throws {
        let max = try #require(parse([["Name": "AirPods Max", "Current Capacity": 64, "Product ID": 0x200A]],
                                       name: "AirPods Max", productID: 0x200A))

        #expect(max.level == 64)
        #expect(max.isInUse)
    }

    @Test func otherDevicesDontCount() {
        #expect(parse(airpods(), name: "Beats Studio") == nil)
        #expect(parse(airpods(), productID: 0x200E) == nil)
        #expect(parse([]) == nil)
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

    @Test func earbudsOutOfTheCase() throws {
        #expect(try #require(parse(airpods())).earbudsInUse == [.left])
        #expect(try #require(parse(airpods(right: kIOPSBatteryPowerValue))).earbudsInUse == [.left, .right])
        #expect(try #require(parse(airpods(left: kIOPSACPowerValue))).earbudsInUse.isEmpty)
    }

    @Test func earbudsGoingInOrOutShowAgain() {
        // The second earbud joins, or one of two leaves.
        #expect(OutputService.isWorthShowing(from: [.left], to: [.left, .right]))
        #expect(OutputService.isWorthShowing(from: [.left, .right], to: [.right]))
        #expect(OutputService.isWorthShowing(from: [], to: [.left]))
        // Nothing changed, or both went back in the case, which disconnects them anyway.
        #expect(!OutputService.isWorthShowing(from: [.left], to: [.left]))
        #expect(!OutputService.isWorthShowing(from: [.left, .right], to: []))
    }

    @Test func volumeShowsTheEarbudInUse() {
        let left = HUDEvent(kind: .volume, level: 0.5, deviceIcon: .airpodsPro, earbud: .left)
        let both = HUDEvent(kind: .volume, level: 0.5, deviceIcon: .airpodsPro)
        let headset = HUDEvent(kind: .volume, level: 0.5, deviceIcon: .headset, earbud: .right)

        #expect(left.symbolName == "airpodpro.left")
        #expect(both.symbolName == DeviceIcon.airpodsPro.availableSymbolName)
        // An icon picked for the device that has no earbuds of its own stays as it is.
        #expect(headset.symbolName == DeviceIcon.headset.availableSymbolName)
    }

    @Test func onlyAppleBluetoothHeadphonesReportACharge() {
        let speakers = OutputDevice(id: "BuiltInSpeakerDevice", name: "MacBook Pro Speakers", transport: .builtIn, isHeadphoneJack: false, modelUID: nil)
        let jabra = OutputDevice(id: "jabra", name: "Jabra", transport: .bluetooth, isHeadphoneJack: false, modelUID: "1234 b0e")

        #expect(HeadphonesBattery.current(for: speakers) == nil)
        #expect(HeadphonesBattery.current(for: jabra) == nil)
    }

    @Test func bothEarbudsInComeAsOneCombinedPart() throws {
        // What macOS lists with both AirPods in: the case and one part for the pair.
        let sources: [[String: Any]] = [
            ["Name": "AirPods Pro Case", "Part Identifier": "Case", "Current Capacity": 48, "Product ID": 0x2024],
            ["Name": "AirPods Pro", "Part Identifier": "Combined", "Current Capacity": 98, "Product ID": 0x2024,
             "Power Source State": kIOPSBatteryPowerValue],
        ]

        let both = try #require(parse(sources))

        #expect(both.earbudsInUse == [.left, .right])
        #expect(both.singleEarbud == nil)
        #expect(both.level == 98)
        #expect(both.case == 48)
    }
}
