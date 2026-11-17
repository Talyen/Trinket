import ScreenCaptureKit
import SwiftUI

/// This target is installed only on the capture phone, independently of Trinket.
@main
struct TrailerRecorder: App {
    @StateObject private var recorder = Recorder()

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 24) {
                Text(recorder.status)
                if recorder.status == "Ready" {
                    Button("Choose screen", action: recorder.choose)
                }
                if recorder.status == "Recording" {
                    Button("Finish take") { Task { await recorder.stop() } }
                }
            }
        }
    }
}

@MainActor
private final class Recorder: NSObject, ObservableObject, SCContentSharingPickerObserver, SCRecordingOutputDelegate, SCStreamDelegate {
    @Published var status = "Ready"
    private let picker = SCContentSharingPicker.shared
    private var stream: SCStream?
    private var output: SCRecordingOutput?
    private var directory: URL?
    private var started: Double?
    private var watchdog: Task<Void, Never>?

    func choose() {
        guard let argument = UserDefaults.standard.string(forKey: "take"),
              let id = UUID(uuidString: argument) else {
            status = "Missing take identifier"
            return
        }
        do {
            let url = URL.documentsDirectory.appending(path: id.uuidString)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            directory = url
            picker.defaultConfiguration = SCContentSharingPickerConfiguration()
            picker.add(self)
            picker.isActive = true
            status = "Waiting for screen permission"
            picker.present()
        } catch {
            status = error.localizedDescription
        }
    }

    nonisolated func contentSharingPicker(_: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for _: SCStream?) {
        Task { @MainActor in
            guard self.stream == nil, let directory else { return }
            let config = SCStreamConfiguration()
            config.capturesAudio = false
            let capture = SCStream(filter: filter, configuration: config, delegate: self)
            let file = SCRecordingOutputConfiguration()
            file.outputURL = directory.appending(path: "continuous.mp4")
            let writer = SCRecordingOutput(configuration: file, delegate: self)
            self.stream = capture
            output = writer
            do {
                try capture.addRecordingOutput(writer)
                try await capture.startCapture()
            } catch {
                status = error.localizedDescription
                try? await capture.stopCapture()
            }
        }
    }

    nonisolated func contentSharingPicker(_: SCContentSharingPicker, didCancelFor _: SCStream?) {
        Task { @MainActor in status = "Permission canceled" }
    }

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: Error) {
        Task { @MainActor in status = error.localizedDescription }
    }

    nonisolated func recordingOutputDidStartRecording(_: SCRecordingOutput) {
        let time = ProcessInfo.processInfo.systemUptime
        Task { @MainActor in
            started = time
            status = "Recording"
            watchdog = Task {
                try? await Task.sleep(for: .seconds(360))
                if !Task.isCancelled {
                    await stop()
                }
            }
        }
    }

    func stop() async {
        guard let stream, status == "Recording" else { return }
        status = "Finishing"
        watchdog?.cancel()
        do {
            try await stream.stopCapture()
        } catch {
            status = error.localizedDescription
        }
    }

    nonisolated func recordingOutputDidFinishRecording(_ recordingOutput: SCRecordingOutput) {
        let duration = recordingOutput.recordedDuration.seconds
        Task { @MainActor in
            guard let started, let directory else { return }
            do {
                let data = try JSONEncoder().encode(["start": started, "duration": duration])
                try data.write(to: directory.appending(path: "clock.json"), options: .atomic)
                status = "Saved"
            } catch {
                status = error.localizedDescription
            }
            watchdog?.cancel()
            output = nil
            stream = nil
            picker.remove(self)
            picker.isActive = false
        }
    }

    nonisolated func recordingOutput(_: SCRecordingOutput, didFailWithError error: Error) {
        Task { @MainActor in
            try? await stream?.stopCapture()
            status = error.localizedDescription
        }
    }

    nonisolated func stream(_: SCStream, didStopWithError error: Error) {
        Task { @MainActor in status = error.localizedDescription }
    }
}
