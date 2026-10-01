import AppKit
import CoreGraphics

@main struct VerifyInstalledApplication {
    @MainActor static func main() async throws {
        guard CommandLine.arguments.count == 2 else { throw NSError(domain: "InstallerTest", code: 1, userInfo: [NSLocalizedDescriptionKey: "Pass the installed application path."]) }
        let url = URL(fileURLWithPath: CommandLine.arguments[1]).standardizedFileURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        configuration.activates = true
        // The argument domain forces an in-memory demo, without changing saved defaults.
        configuration.arguments = ["-journal.started", "NO"]
        let application: NSRunningApplication = try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { application, error in
                if let error { continuation.resume(throwing: error) }
                else if let application { continuation.resume(returning: application) }
                else { continuation.resume(throwing: NSError(domain: "InstallerTest", code: 2)) }
            }
        }
        guard application.bundleURL?.standardizedFileURL == url else { throw NSError(domain: "InstallerTest", code: 3, userInfo: [NSLocalizedDescriptionKey: "LaunchServices opened a different application."]) }
        defer { application.terminate() }
        print("Checking launched app PID \(application.processIdentifier)")
        for _ in 0..<60 {
            if application.isTerminated { throw NSError(domain: "InstallerTest", code: 4, userInfo: [NSLocalizedDescriptionKey: "The installed app exited during launch."]) }
            let windows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
            let visible = windows.contains { window in
                guard (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == application.processIdentifier,
                      let bounds = window[kCGWindowBounds as String] as? [String: Any],
                      let width = (bounds["Width"] as? NSNumber)?.doubleValue, let height = (bounds["Height"] as? NSNumber)?.doubleValue else { return false }
                return width >= 1060 && height >= 720
            }
            if application.isFinishedLaunching && visible {
                try await Task.sleep(nanoseconds: 2_000_000_000)
                guard !application.isTerminated else { throw NSError(domain: "InstallerTest", code: 5) }
                print("PASS: installed app launched with its full-size window in isolated demo mode: \(url.path)")
                return
            }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        throw NSError(domain: "InstallerTest", code: 6, userInfo: [NSLocalizedDescriptionKey: "The installed app did not create its main window within 30 seconds."])
    }
}
