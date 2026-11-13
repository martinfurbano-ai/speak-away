import Foundation

/// Switches for parts of the app that are not finished. Each stays off until its step ships.
enum Features {
    /// "Record meeting" on the Meetings screen. The recorder itself is step 4 of the iPhone work, so the button
    /// stays hidden until then. Saved meetings (from the sample data, or from a later version) always show.
    static let meetingRecorder = false
}
