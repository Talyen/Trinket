import AVFoundation

enum AudioSessionCoordinator {
    static func configureForGameMusic() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            #if DEBUG
            print("Unable to configure audio session: \(error.localizedDescription)")
            #endif
        }
    }
}
