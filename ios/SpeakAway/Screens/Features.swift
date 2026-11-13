import Foundation

/// Switches for parts of the app that are not finished. Each stays off until its step ships.
enum Features {
    /// "Record meeting" on the Meetings screen: record with the microphone, transcribe on the phone and keep the
    /// notes. Saved meetings always show, with the button on or off.
    static let meetingRecorder = true
}
