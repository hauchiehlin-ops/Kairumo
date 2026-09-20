import AVFoundation

let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
let dir = docs.appendingPathComponent("Kairumo Record", isDirectory: true)
if !FileManager.default.fileExists(atPath: dir.path) {
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
}
let fileUrl = dir.appendingPathComponent("test.m4a")

let settings: [String: Any] = [
    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
    AVSampleRateKey: 44100.0,
    AVNumberOfChannelsKey: 1,
    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
]

do {
    let recorder = try AVAudioRecorder(url: fileUrl, settings: settings)
    print("Prepared: \(recorder.prepareToRecord())")
    print("Record: \(recorder.record())")
} catch {
    print("Error: \(error)")
}
