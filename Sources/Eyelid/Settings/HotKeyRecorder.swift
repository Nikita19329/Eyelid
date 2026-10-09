import Carbon.HIToolbox
import SwiftUI

/// Shows a shortcut, and records a new one after a click.
struct HotKeyRecorder: View {
    @Binding var hotKey: HotKey
    let shortcut: Shortcut
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            isRecording ? stopRecording() : startRecording()
        } label: {
            Text(isRecording ? "Type a shortcut…" : hotKey.displayString)
                .monospacedDigit()
                .frame(minWidth: 110)
        }
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        isRecording = true
        // Otherwise pressing the current shortcut would act instead of being recorded.
        shortcut.isSuspended = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
            } else if let new = HotKey(keyCode: event.keyCode, modifierFlags: event.modifierFlags) {
                hotKey = new
                stopRecording()
            } else {
                // A shortcut needs ⌘, ⌥ or ⌃.
                NSSound.beep()
            }
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
        shortcut.isSuspended = false
    }
}
