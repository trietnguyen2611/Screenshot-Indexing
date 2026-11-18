import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

/// Snapshot of macOS TCC permission grants required by auto-capture and page-turn automation.
struct PermissionStatus: Equatable, Sendable {
    var screenRecording: Bool
    var accessibility: Bool
}

/// Checks and requests macOS Screen Recording and Accessibility permissions and opens System Settings.
enum PermissionsService {
    private static let screenRecordingSettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )
    private static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )

    /// Check macOS Screen Recording and Accessibility TCC permission status, optionally prompting.
    static func checkPermissions(prompt: Bool = false) -> PermissionStatus {
        PermissionStatus(
            screenRecording: checkScreenRecording(prompt: prompt),
            accessibility: checkAccessibility(prompt: prompt)
        )
    }

    /// Open System Settings to Privacy & Security -> Screen Recording.
    static func openScreenRecordingSettings() {
        guard let url = screenRecordingSettingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    /// Open System Settings to Privacy & Security -> Accessibility.
    static func openAccessibilitySettings() {
        guard let url = accessibilitySettingsURL else { return }
        NSWorkspace.shared.open(url)
    }

    private static func checkScreenRecording(prompt: Bool) -> Bool {
        var granted = CGPreflightScreenCaptureAccess()
        if prompt && !granted {
            let requested = CGRequestScreenCaptureAccess()
            granted = requested || CGPreflightScreenCaptureAccess()
        }
        return granted
    }

    private static func checkAccessibility(prompt: Bool) -> Bool {
        var granted = AXIsProcessTrusted()
        if prompt && !granted {
            // Use the literal string value of kAXTrustedCheckOptionPrompt so it remains Swift 6 concurrency-safe.
            let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
            granted = AXIsProcessTrustedWithOptions(options)
        }
        return granted
    }
}
