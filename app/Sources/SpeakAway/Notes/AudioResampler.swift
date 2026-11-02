import AVFoundation

/// Turns any capture format (48 kHz stereo, 44.1 kHz mono, ...) into the 16 kHz mono floats Whisper wants.
/// One instance per capture thread: it keeps converter state between buffers.
final class AudioResampler {
    static let sampleRate = 16_000

    private let outFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: Double(AudioResampler.sampleRate), channels: 1, interleaved: false)!
    private var converter: AVAudioConverter?
    private var inFormat: AVAudioFormat?

    func convert(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard buffer.frameLength > 0 else { return [] }
        if converter == nil || inFormat != buffer.format {
            converter = AVAudioConverter(from: buffer.format, to: outFormat)
            inFormat = buffer.format
        }
        guard let converter else { return [] }
        let ratio = outFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 64
        guard let out = AVAudioPCMBuffer(pcmFormat: outFormat, frameCapacity: capacity) else { return [] }
        var fed = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if fed { status.pointee = .noDataNow; return nil }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, let channel = out.floatChannelData?[0], out.frameLength > 0 else { return [] }
        return Array(UnsafeBufferPointer(start: channel, count: Int(out.frameLength)))
    }
}
