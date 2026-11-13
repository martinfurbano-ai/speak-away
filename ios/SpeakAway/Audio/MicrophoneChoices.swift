import AVFoundation

/// The microphones the Settings picker offers. The first row is always "the one the system picks".
struct MicrophoneChoice: Equatable, Identifiable {
    /// The `AVAudioSessionPortDescription.uid`, or empty for the automatic choice.
    let uid: String
    let name: String

    var id: String { uid }
}

enum MicrophoneChoices {
    /// The inputs connected right now: the iPhone's own mic, wired or Bluetooth headsets, AirPods.
    static func current(session: AVAudioSession = .sharedInstance()) -> [MicrophoneChoice] {
        if (session.availableInputs ?? []).isEmpty {
            // Inputs are only listed for a category that can record. The options are the ones a dictation uses, and
            // the session is not activated here, so nothing that is playing is interrupted.
            try? session.setCategory(.playAndRecord, mode: .default,
                                     options: [.mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker])
        }
        return (session.availableInputs ?? []).map { MicrophoneChoice(uid: $0.uid, name: $0.portName) }
    }

    /// The connected input with that uid, or `nil` (use the system's choice).
    static func availableInput(uid: String, in inputs: [AVAudioSessionPortDescription]) -> AVAudioSessionPortDescription? {
        guard !uid.isEmpty else { return nil }
        return inputs.first { $0.uid == uid }
    }

    /// The saved choice is still a connected input; if not, the picker shows "Automatic" instead of a stale name.
    static func isConnected(uid: String, among choices: [MicrophoneChoice]) -> Bool {
        uid.isEmpty || choices.contains { $0.uid == uid }
    }
}
