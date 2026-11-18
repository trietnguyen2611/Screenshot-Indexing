import AppKit
import ApplicationServices
import CoreGraphics
import Foundation
import ScreenCaptureKit

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

    /// Check macOS Screen Recording and Accessibility permissions using a live ScreenCaptureKit
    /// probe when `CGPreflightScreenCaptureAccess()` returns `false`, so newly-granted permissions
    /// are detected without requiring an app restart.
    static func checkPermissionsLive(prompt: Bool = false) async -> PermissionStatus {
        let screenRecording = await checkScreenRecordingLive(prompt: prompt)
        let accessibility = checkAccessibility(prompt: prompt)
        return PermissionStatus(
            screenRecording: screenRecording,
            accessibility: accessibility
        )
    }

    /// Open System Settings for the first missing permission in `status`.
    /// Returns `true` if a System Settings pane was opened.
    @discardableResult
    static func openFirstMissingSettings(for status: PermissionStatus) -> Bool {
        if !status.screenRecording {
            openScreenRecordingSettings()
            return true
        }
        if !status.accessibility {
            openAccessibilitySettings()
            return true
        }
        return false
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

    private static func checkScreenRecordingLive(prompt: Bool) async -> Bool {
        if CGPreflightScreenCaptureAccess() {
            return true
        }

        if await probeScreenCaptureKitAccess() {
            return true
        }

        guard prompt else {
            return false
        }

        let requested = CGRequestScreenCaptureAccess()
        if requested || CGPreflightScreenCaptureAccess() {
            return true
        }

        return await probeScreenCaptureKitAccess()
    }

    private static func probeScreenCaptureKitAccess() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
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
