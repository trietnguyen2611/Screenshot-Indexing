import AppKit
import SwiftUI

// MARK: - Application Lifecycle Delegate

@MainActor
final class AppLifecycleDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        configureTransparentTitlebarWindows()
        DispatchQueue.main.async { [weak self] in
            self?.configureTransparentTitlebarWindows()
        }
    }

    private func configureTransparentTitlebarWindows() {
        for window in NSApp.windows {
            window.titlebarAppearsTransparent = true
            if !window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.insert(.fullSizeContentView)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationWillTerminate(_ notification: Notification) {
        performTeardown()
    }

    func performTeardown() {
        CaptureController.shared.stop()
        ScreenCaptureHelper.cleanupPreviewFile()
        GlobalHotkeyService.shared.stop()
    }
}

// MARK: - App Entry Point

@main
struct ScreenshotIndexingApp: App {
    @NSApplicationDelegateAdaptor(AppLifecycleDelegate.self) private var appDelegate
    @State private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup("Screenshot Indexing") {
            MainContentView()
                .environment(viewModel)
                .preferredColorScheme(viewModel.preferredColorScheme)
                .frame(minWidth: 1020, minHeight: 680)
                .onAppear {
                    viewModel.onAppLaunch()
                }
                .onDisappear {
                    appDelegate.performTeardown()
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1220, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
