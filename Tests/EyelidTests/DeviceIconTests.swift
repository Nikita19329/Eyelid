import AppKit
import Testing
@testable import Eyelid

@Suite("Output device icons")
struct DeviceIconTests {
    private func device(
        _ name: String,
        transport: OutputDevice.Transport = .bluetooth,
        modelUID: String? = nil,
        isHeadphoneJack: Bool = false
    ) -> OutputDevice {
        OutputDevice(id: "uid", name: name, transport: transport, isHeadphoneJack: isHeadphoneJack, modelUID: modelUID)
    }

    @Test func readsAppleProductIDsFromTheModelUID() {
        #expect(device("AirPods Pro", modelUID: "2024 4c").appleProductID == 0x2024)
        #expect(device("Speaker", modelUID: "1234 5a").appleProductID == nil)
        #expect(device("MacBook Pro Speakers", modelUID: "Speaker").appleProductID == nil)
    }

    @Test func knowsAirPodsByProductIDEvenWhenRenamed() {
        // The model UID of the AirPods Pro 2 this was developed with.
        #expect(DeviceIcon.automatic(for: device("Nikita's earphones", modelUID: "2024 4c")) == .airpodsPro)
        #expect(DeviceIcon.automatic(for: device("Studio", modelUID: "200a 4c")) == .airpodsMax)
    }

    @Test(arguments: zip(
        ["AirPods Max", "Nikita's AirPods Pro", "AirPods 4", "AirPods", "Beats Studio Buds+", "Powerbeats Pro", "Beats Solo 4"],
        [DeviceIcon.airpodsMax, .airpodsPro, .airpods4, .airpods, .beatsEarbuds, .beatsEarbuds, .beatsHeadphones]
    ))
    func knowsAppleHeadphonesByTheirDefaultName(name: String, icon: DeviceIcon) {
        #expect(DeviceIcon.automatic(for: device(name)) == icon)
    }

    @Test func otherBluetoothDevicesLookLikeHeadphones() {
        #expect(DeviceIcon.automatic(for: device("JBL Tune 510BT", modelUID: "0f1a 57")) == .headphones)
    }

    @Test func builtInOutputIsTheSpeakerUnlessHeadphonesArePluggedIn() {
        #expect(DeviceIcon.automatic(for: device("MacBook Pro Speakers", transport: .builtIn)) == .speaker)
        #expect(DeviceIcon.automatic(for: device("External Headphones", transport: .builtIn, isHeadphoneJack: true)) == .headphones)
    }

    @Test(arguments: zip(
        [OutputDevice.Transport.hdmi, .displayPort, .airPlay, .usb],
        [DeviceIcon.tv, .display, .airPlay, .speaker]
    ))
    func otherConnectionsGetTheirOwnIcon(transport: OutputDevice.Transport, icon: DeviceIcon) {
        #expect(DeviceIcon.automatic(for: device("Device", transport: transport)) == icon)
    }

    @Test(arguments: DeviceIcon.allCases)
    func everyIconExists(icon: DeviceIcon) {
        // CI runs an older macOS than development, so this also covers the minimum supported symbols.
        #expect(NSImage(systemSymbolName: icon.symbolName, accessibilityDescription: nil) != nil)
    }

    @Test func fourCharacterCodes() {
        #expect(UInt32(fourCharacterCode: "hdpn") == 0x6864_706E)
    }

    // MARK: HUD

    @Test func volumeHUDShowsTheDeviceIcon() {
        #expect(HUDEvent(kind: .volume, level: 0.5, deviceIcon: .airpodsPro).symbolName == "airpods.pro")
        #expect(HUDEvent(kind: .volume, level: 0.5, deviceIcon: .speaker).symbolName == "speaker.wave.2.fill")
    }

    @Test func mutedDeviceIconsDim() {
        #expect(HUDEvent(kind: .volume, level: 0.5, isMuted: true, deviceIcon: .airpodsPro).dimsIcon)
        #expect(HUDEvent(kind: .volume, level: 0, deviceIcon: .headphones).dimsIcon)
        #expect(!HUDEvent(kind: .volume, level: 0.5, deviceIcon: .airpodsPro).dimsIcon)
        // The speaker has its own muted symbol instead.
        #expect(!HUDEvent(kind: .volume, level: 0.5, isMuted: true, deviceIcon: .speaker).dimsIcon)
    }

    @Test(arguments: zip([0, 0.03, 0.5, 0.97, 1] as [Float], [0, 0, 8, 16, 16]))
    func segmentsLightUpPerStep(level: Float, lit: Int) {
        #expect(LevelStyle.litSegments(for: level) == lit)
    }
}
