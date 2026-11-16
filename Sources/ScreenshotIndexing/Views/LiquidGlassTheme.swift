import AppKit
import SwiftUI

// MARK: - App Navigation Tab

enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case indexing
    case capture
    case settings

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .indexing: return "photo.stack"
        case .capture: return "viewfinder.rectangular"
        case .settings: return "gearshape"
        }
    }
}

// MARK: - Concentric Design Tokens

enum GlassMetrics {
    static let outerPanelCornerRadius: CGFloat = 24
    static let cardCornerRadius: CGFloat = 18
    static let inputCornerRadius: CGFloat = 12
    static let containerSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 16
    static let springAnimation: Animation = .spring(response: 0.36, dampingFraction: 0.84)
}

// MARK: - Ambient Backdrop

struct LiquidGlassBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if colorScheme == .dark {
                darkBackdrop
            } else {
                lightBackdrop
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var darkBackdrop: some View {
        ZStack {
            Color(red: 0.045, green: 0.058, blue: 0.105)

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                    SIMD2(0.0, 0.52), SIMD2(0.54, 0.46), SIMD2(1.0, 0.5),
                    SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0),
                ],
                colors: [
                    Color(red: 0.075, green: 0.105, blue: 0.235),
                    Color(red: 0.055, green: 0.145, blue: 0.285),
                    Color(red: 0.065, green: 0.215, blue: 0.305),

                    Color(red: 0.095, green: 0.085, blue: 0.220),
                    Color(red: 0.065, green: 0.155, blue: 0.275),
                    Color(red: 0.050, green: 0.130, blue: 0.235),

                    Color(red: 0.045, green: 0.065, blue: 0.135),
                    Color(red: 0.055, green: 0.095, blue: 0.185),
                    Color(red: 0.075, green: 0.075, blue: 0.185),
                ]
            )
            .opacity(0.92)

            Circle()
                .fill(Color.cyan.opacity(0.14))
                .frame(width: 560, height: 560)
                .blur(radius: 130)
                .offset(x: 340, y: -220)

            Circle()
                .fill(Color.indigo.opacity(0.18))
                .frame(width: 620, height: 620)
                .blur(radius: 150)
                .offset(x: -360, y: 240)
        }
    }

    private var lightBackdrop: some View {
        ZStack {
            Color(red: 0.935, green: 0.955, blue: 0.985)

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                    SIMD2(0.0, 0.48), SIMD2(0.48, 0.52), SIMD2(1.0, 0.5),
                    SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0),
                ],
                colors: [
                    Color(red: 0.875, green: 0.925, blue: 0.995),
                    Color(red: 0.925, green: 0.960, blue: 1.000),
                    Color(red: 0.840, green: 0.945, blue: 0.985),

                    Color(red: 0.905, green: 0.915, blue: 0.995),
                    Color(red: 0.960, green: 0.975, blue: 1.000),
                    Color(red: 0.880, green: 0.945, blue: 0.990),

                    Color(red: 0.935, green: 0.955, blue: 0.990),
                    Color(red: 0.895, green: 0.935, blue: 0.985),
                    Color(red: 0.920, green: 0.915, blue: 0.990),
                ]
            )
            .opacity(0.95)

            Circle()
                .fill(Color.cyan.opacity(0.16))
                .frame(width: 540, height: 540)
                .blur(radius: 130)
                .offset(x: 360, y: -200)

            Circle()
                .fill(Color.blue.opacity(0.12))
                .frame(width: 600, height: 600)
                .blur(radius: 140)
                .offset(x: -360, y: 240)
        }
    }
}

// MARK: - Glass Surface Containers

struct GlassPanel<Content: View>: View {
    private let padding: CGFloat
    private let content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .glassEffect(
                .regular,
                in: .rect(cornerRadius: GlassMetrics.outerPanelCornerRadius, style: .continuous)
            )
    }
}

struct GlassCard<Content: View>: View {
    private let padding: CGFloat
    private let tint: Color?
    private let content: Content

    init(padding: CGFloat = GlassMetrics.cardPadding, tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        let glass: Glass = tint.map { .regular.tint($0) } ?? .regular
        content
            .padding(padding)
            .glassEffect(
                glass,
                in: .rect(cornerRadius: GlassMetrics.cardCornerRadius, style: .continuous)
            )
    }
}

struct GlassSectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }
}

// MARK: - Concentric Inner Input Surface

struct GlassInputSurface: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    var isFocused: Bool = false
    var isHighlighted: Bool = false
    var cornerRadius: CGFloat = GlassMetrics.inputCornerRadius

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape.fill(
                    colorScheme == .dark
                        ? Color.white.opacity(isHighlighted ? 0.12 : 0.065)
                        : Color.white.opacity(isHighlighted ? 0.72 : 0.56)
                )
            }
            .overlay {
                shape.strokeBorder(
                    isFocused || isHighlighted
                        ? Color.accentColor.opacity(0.65)
                        : Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.09),
                    lineWidth: isFocused || isHighlighted ? 1.5 : 1
                )
            }
    }
}

extension View {
    func glassInputSurface(
        isFocused: Bool = false,
        isHighlighted: Bool = false,
        cornerRadius: CGFloat = GlassMetrics.inputCornerRadius
    ) -> some View {
        modifier(GlassInputSurface(isFocused: isFocused, isHighlighted: isHighlighted, cornerRadius: cornerRadius))
    }
}

// MARK: - Glass Pill Button & Badge

enum GlassPillVariant {
    case standard
    case primary
    case destructive
    case accentCyan
}

struct GlassPillButton: View {
    let title: String
    let systemImage: String?
    let variant: GlassPillVariant
    let compact: Bool
    let isLoading: Bool
    let isDisabled: Bool
    let action: () -> Void

    init(
        _ title: String,
        systemImage: String? = nil,
        variant: GlassPillVariant = .standard,
        compact: Bool = false,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.systemImage = systemImage
        self.variant = variant
        self.compact = compact
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }

    private var glassStyle: Glass {
        let interactive = !isDisabled && !isLoading
        switch variant {
        case .standard:
            return .regular.interactive(interactive)
        case .primary:
            return .regular.tint(.accentColor.opacity(0.32)).interactive(interactive)
        case .destructive:
            return .regular.tint(.red.opacity(0.32)).interactive(interactive)
        case .accentCyan:
            return .regular.tint(.cyan.opacity(0.28)).interactive(interactive)
        }
    }

    private var foregroundColor: Color {
        switch variant {
        case .standard:
            return .primary
        case .primary:
            return .primary
        case .destructive:
            return .red
        case .accentCyan:
            return .primary
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: compact ? 5 : 6) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: compact ? 11 : 12, weight: .semibold))
                }
                if !title.isEmpty {
                    Text(title)
                        .font(.system(size: compact ? 12 : 13, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, compact ? 11 : 14)
            .padding(.vertical, compact ? 6 : 8)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(glassStyle, in: .capsule)
        .opacity(isDisabled ? 0.45 : 1.0)
        .disabled(isDisabled || isLoading)
    }
}

struct GlassBadge: View {
    let text: String
    var tint: Color? = nil
    var foreground: Color = .secondary

    var body: some View {
        let glass: Glass = tint.map { .regular.tint($0) } ?? .regular
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .glassEffect(glass, in: .capsule)
    }
}

// MARK: - Pulsing Status Dot

struct PulsingStatusDot: View {
    enum StateKind: Equatable {
        case idle
        case active
        case countdown
        case completed
        case error
    }

    let state: StateKind
    var size: CGFloat = 8
    @State private var isPulsing = false

    private var dotColor: Color {
        switch state {
        case .idle: return .secondary.opacity(0.45)
        case .active: return .green
        case .countdown: return .orange
        case .completed: return .blue
        case .error: return .red
        }
    }

    private var shouldPulse: Bool {
        state == .active || state == .countdown
    }

    var body: some View {
        ZStack {
            if shouldPulse {
                Circle()
                    .fill(dotColor.opacity(0.4))
                    .frame(width: size * 2.1, height: size * 2.1)
                    .scaleEffect(isPulsing ? 1.15 : 0.75)
                    .opacity(isPulsing ? 0.15 : 0.7)
                    .animation(
                        .easeInOut(duration: 1.05).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
            }

            Circle()
                .fill(dotColor)
                .frame(width: size, height: size)
        }
        .frame(width: size * 2.2, height: size * 2.2)
        .onAppear { isPulsing = shouldPulse }
        .onChange(of: state) { _, newValue in
            isPulsing = (newValue == .active || newValue == .countdown)
        }
    }
}

// MARK: - Animated Streaming Shimmer Indicator

struct AIStreamingIndicator: View {
    let label: String
    @State private var phase: CGFloat = -0.6

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.cyan)
                .symbolEffect(.pulse, isActive: true)

            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)

            Spacer()

            Capsule()
                .fill(Color.primary.opacity(0.08))
                .frame(width: 72, height: 4)
                .overlay(alignment: .leading) {
                    GeometryReader { geo in
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .cyan, .accentColor, .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geo.size.width * 0.55)
                            .offset(x: phase * geo.size.width)
                            .onAppear {
                                withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                                    phase = 1.1
                                }
                            }
                    }
                    .clipShape(Capsule())
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassInputSurface(isHighlighted: true, cornerRadius: 10)
    }
}

// MARK: - Resizable Horizontal Split

struct ResizableHorizontalSplit<Sidebar: View, Detail: View>: View {
    @Binding var sidebarWidth: CGFloat
    let minSidebarWidth: CGFloat
    let maxSidebarWidth: CGFloat
    let minDetailWidth: CGFloat
    private let sidebar: Sidebar
    private let detail: Detail

    @State private var dragStartWidth: CGFloat?
    @State private var isHoveringDivider = false

    init(
        sidebarWidth: Binding<CGFloat>,
        minSidebarWidth: CGFloat = 360,
        maxSidebarWidth: CGFloat = 520,
        minDetailWidth: CGFloat = 440,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder detail: () -> Detail
    ) {
        self._sidebarWidth = sidebarWidth
        self.minSidebarWidth = minSidebarWidth
        self.maxSidebarWidth = maxSidebarWidth
        self.minDetailWidth = minDetailWidth
        self.sidebar = sidebar()
        self.detail = detail()
    }

    var body: some View {
        GeometryReader { geo in
            let dividerWidth: CGFloat = 14
            let effectiveMax = max(
                minSidebarWidth,
                min(maxSidebarWidth, geo.size.width - minDetailWidth - dividerWidth)
            )
            let clampedWidth = min(max(sidebarWidth, minSidebarWidth), effectiveMax)

            HStack(spacing: 0) {
                sidebar
                    .frame(width: clampedWidth)
                    .frame(maxHeight: .infinity)

                dividerHandle(effectiveMax: effectiveMax, currentWidth: clampedWidth)
                    .frame(width: dividerWidth)
                    .frame(maxHeight: .infinity)

                detail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func dividerHandle(effectiveMax: CGFloat, currentWidth: CGFloat) -> some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())

            Capsule()
                .fill(
                    (isHoveringDivider || dragStartWidth != nil)
                        ? Color.accentColor.opacity(0.75)
                        : Color.primary.opacity(0.16)
                )
                .frame(width: (isHoveringDivider || dragStartWidth != nil) ? 4 : 3, height: 48)
                .animation(.easeOut(duration: 0.15), value: isHoveringDivider)
        }
        .onHover { hovering in
            if hovering && !isHoveringDivider {
                isHoveringDivider = true
                NSCursor.resizeLeftRight.push()
            } else if !hovering && isHoveringDivider {
                isHoveringDivider = false
                NSCursor.pop()
            }
        }
        .onDisappear {
            if isHoveringDivider {
                isHoveringDivider = false
                NSCursor.pop()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = currentWidth
                    }
                    let start = dragStartWidth ?? currentWidth
                    let proposed = start + value.translation.width
                    sidebarWidth = min(max(proposed, minSidebarWidth), effectiveMax)
                }
                .onEnded { _ in
                    dragStartWidth = nil
                }
        )
    }
}

// MARK: - Toast Notification Model & View

enum ToastType: Equatable, Sendable {
    case info
    case success
    case warning
    case error

    var systemImage: String {
        switch self {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        }
    }

    var tintColor: Color {
        switch self {
        case .info: return .blue
        case .success: return .green
        case .warning: return .orange
        case .error: return .red
        }
    }
}

struct ToastMessage: Identifiable, Equatable, Sendable {
    let id = UUID()
    let text: String
    let type: ToastType
}

struct ToastOverlayView: View {
    let toast: ToastMessage?
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            Spacer()
            if let toast {
                HStack(spacing: 10) {
                    Image(systemName: toast.type.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(toast.type.tintColor)

                    Text(toast.text)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular.tint(toast.type.tintColor.opacity(0.14)), in: .capsule)
                .shadow(color: .black.opacity(0.16), radius: 16, y: 6)
                .onTapGesture(perform: onDismiss)
                .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.94)))
                .padding(.bottom, 18)
            }
        }
        .animation(GlassMetrics.springAnimation, value: toast)
        .allowsHitTesting(toast != nil)
    }
}

// MARK: - App ViewModel

@MainActor
@Observable
final class AppViewModel {
    // Persisted App Configuration
    var config: AppConfig

    // Navigation & Toast
    var activeTab: AppTab = .indexing
    var toast: ToastMessage?
    private var toastTask: Task<Void, Never>?

    // Indexing Tab State
    var indexingFolder: String = ""
    var files: [ScreenshotItem] = []
    var rangeStartText: String = ""
    var rangeEndText: String = ""
    var isScanning: Bool = false
    var isRenaming: Bool = false
    var indexingStatusText: String = ""
    var indexingStatusIsError: Bool = false

    // Confirm Rename Sheet State
    var showConfirmRenameSheet: Bool = false
    var pendingRenameRange: (start: Int, end: Int, count: Int)?
    var pendingFirstOld: String = ""
    var pendingFirstNew: String = ""
    var pendingLastOld: String = ""
    var pendingLastNew: String = ""

    // Image Preview Sheet State
    var previewImageIndex: Int?
    var isSummarizingNotes: Bool = false
    var isSummarizingSingleImage: Bool = false
    var singleImageSummaryText: String = ""
    var showSingleImageSummaryPopover: Bool = false

    // Auto Capture & Settings State
    let captureController = CaptureController.shared
    var permissions: PermissionStatus
    var previewResult: ScreenPreviewResult?
    var isCapturingPreview: Bool = false
    var isPickingOverlay: Bool = false
    var isRecordingOverlayShortcut: Bool = false
    var afmStatus: AFMAvailabilityStatus

    // Background Tasks
    private var didLaunchSetup = false
    private var notesSaveTask: Task<Void, Never>?
    private var afmNotesTask: Task<Void, Never>?
    private var afmSingleImageTask: Task<Void, Never>?

    init() {
        let loaded = ConfigStore.shared.load()
        self.config = loaded
        self.permissions = PermissionsService.checkPermissions(prompt: false)
        self.afmStatus = AFMSummarizerService.shared.checkAvailability()
        if !loaded.saveFolder.isEmpty {
            self.indexingFolder = loaded.saveFolder
        }
    }

    // MARK: - Computed Helpers

    var preferredColorScheme: ColorScheme? {
        switch config.themeMode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var visibleTabs: [AppTab] {
        config.autoCaptureEnabled ? [.indexing, .capture, .settings] : [.indexing, .settings]
    }

    var appVersionString: String {
        let raw = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return (raw?.isEmpty == false) ? raw! : "2.0.0"
    }

    var captureHeaderDotState: PulsingStatusDot.StateKind {
        let status = captureController.status
        if status.running {
            return status.phase == .countdown ? .countdown : .active
        }
        if status.phase == .error {
            return .error
        }
        return .idle
    }

    var captureStatusDotState: PulsingStatusDot.StateKind {
        switch captureController.status.phase {
        case .idle, .stopped: return .idle
        case .countdown: return .countdown
        case .capturing: return .active
        case .completed: return .completed
        case .error: return .error
        }
    }

    func t(_ key: L10nKey, _ args: [String: String] = [:]) -> String {
        L10n.t(key, config.language, args)
    }

    func tabTitle(_ tab: AppTab) -> String {
        switch tab {
        case .indexing: return t(.tabIndexing)
        case .capture: return t(.tabAutoCapture)
        case .settings: return t(.tabSettings)
        }
    }

    func phaseDisplayText(_ snapshot: CaptureStatusSnapshot) -> String {
        switch snapshot.phase {
        case .idle:
            return t(.phaseIdle)
        case .countdown:
            return t(.phaseCountdown, ["sec": "\(snapshot.countdownRemaining)"])
        case .capturing:
            return t(.phaseCapturing)
        case .completed:
            return t(.phaseCompleted)
        case .stopped:
            return t(.phaseStopped)
        case .error:
            return t(.phaseError)
        }
    }

    // MARK: - Lifecycle & Navigation

    func onAppLaunch() {
        guard !didLaunchSetup else { return }
        didLaunchSetup = true

        refreshPermissions(prompt: false, showToastOnResult: false)
        refreshAFMStatus()
        armGlobalOverlayHotkey()

        if !indexingFolder.isEmpty {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: indexingFolder, isDirectory: &isDir), isDir.boolValue {
                scanFolder(showToastOnSuccess: false)
            }
        }
    }

    func selectTab(_ target: AppTab) {
        let resolvedTab: AppTab = (target == .capture && !config.autoCaptureEnabled) ? .indexing : target
        let previousTab = activeTab

        withAnimation(GlassMetrics.springAnimation) {
            activeTab = resolvedTab
        }

        if resolvedTab == .indexing && previousTab == .capture {
            let capFolder = config.saveFolder.trimmingCharacters(in: .whitespacesAndNewlines)
            if !capFolder.isEmpty {
                indexingFolder = capFolder
                scanFolder(showToastOnSuccess: false)
            }
        } else if resolvedTab == .capture {
            refreshPermissions(prompt: false, showToastOnResult: false)
        } else if resolvedTab == .settings {
            refreshAFMStatus()
        }
    }

    // MARK: - Toast

    func showToast(_ message: String, type: ToastType = .info, duration: Double = 3.0) {
        toastTask?.cancel()
        withAnimation(GlassMetrics.springAnimation) {
            toast = ToastMessage(text: message, type: type)
        }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(GlassMetrics.springAnimation) {
                    self?.toast = nil
                }
            }
        }
    }

    func dismissToast() {
        toastTask?.cancel()
        withAnimation(GlassMetrics.springAnimation) {
            toast = nil
        }
    }

    // MARK: - Config Persistence, Language & Theme

    func saveConfig(showToastOnSave: Bool = false) {
        do {
            config = try ConfigStore.shared.save(config)
            if showToastOnSave {
                showToast(t(.toastSettingsSaved), type: .success)
            }
        } catch {
            showToast(t(.toastSettingsError), type: .error)
        }
    }

    func updateConfig(showToastOnSave: Bool = false, _ mutate: (inout AppConfig) -> Void) {
        mutate(&config)
        saveConfig(showToastOnSave: showToastOnSave)
        if !config.autoCaptureEnabled && activeTab == .capture {
            withAnimation(GlassMetrics.springAnimation) {
                activeTab = .indexing
            }
        }
    }

    func setLanguage(_ lang: AppLanguage) {
        guard config.language != lang else { return }
        updateConfig { $0.language = lang }
    }

    func setThemeMode(_ mode: AppThemeMode, showToastMessage: Bool = true) {
        updateConfig { $0.themeMode = mode }
        if showToastMessage {
            let label: String
            switch mode {
            case .system: label = t(.themeSystem)
            case .light: label = t(.themeLight)
            case .dark: label = t(.themeDark)
            }
            showToast(t(.toastThemeChange, ["theme": label]), type: .info, duration: 2.2)
        }
    }

    func cycleThemeMode() {
        let next: AppThemeMode
        switch config.themeMode {
        case .system: next = .light
        case .light: next = .dark
        case .dark: next = .system
        }
        setThemeMode(next)
    }

    func updateNotes(_ text: String) {
        config.notesText = text
        notesSaveTask?.cancel()
        notesSaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled, let self else { return }
            _ = try? ConfigStore.shared.update { $0.notesText = self.config.notesText }
        }
    }

    // MARK: - Folder Picker Shared Helper

    func pickFolderWithPanel(initialPath: String) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = t(.selectThisFolder)
        panel.title = t(.modalSelectFolder)

        let expanded = (initialPath.trimmingCharacters(in: .whitespacesAndNewlines) as NSString).expandingTildeInPath
        if !expanded.isEmpty {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: expanded, isDirectory: &isDir), isDir.boolValue {
                panel.directoryURL = URL(fileURLWithPath: expanded, isDirectory: true)
            }
        }

        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        return url.path
    }

    // MARK: - Tab 1: Indexing Actions

    func browseIndexingFolder() {
        guard let selected = pickFolderWithPanel(initialPath: indexingFolder) else { return }
        indexingFolder = selected
        scanFolder(showToastOnSuccess: false)
    }

    func scanFolder(showToastOnSuccess: Bool = false) {
        let trimmed = indexingFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showToast(t(.toastEnterFolder), type: .warning)
            return
        }

        isScanning = true
        indexingStatusIsError = false
        indexingStatusText = t(.statusScanning)
        defer { isScanning = false }

        do {
            var scanned = try FileIndexingService.scanFolder(at: trimmed)
            let expanded = (trimmed as NSString).expandingTildeInPath
            indexingFolder = expanded

            if !scanned.isEmpty,
               rangeStartText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               rangeEndText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                rangeStartText = "1"
                rangeEndText = "\(scanned.count)"
            }

            if let start = Int(rangeStartText.trimmingCharacters(in: .whitespacesAndNewlines)),
               let end = Int(rangeEndText.trimmingCharacters(in: .whitespacesAndNewlines)),
               start >= 0, end >= start, !scanned.isEmpty {
                scanned = (try? FileIndexingService.applyPreviewNames(to: scanned, start: start, end: end)) ?? scanned
            }

            files = scanned
            indexingStatusIsError = false
            indexingStatusText = t(.statusFileCount, ["count": "\(scanned.count)"])

            if showToastOnSuccess {
                showToast(t(.toastRefresh), type: .info, duration: 2.0)
            }
        } catch let error as FileIndexingError {
            files = []
            indexingStatusIsError = true
            switch error {
            case .folderNotExist:
                indexingStatusText = t(.folderNotExist)
                showToast(t(.folderNotExist), type: .error)
            case .noFiles:
                indexingStatusText = t(.noFiles)
            case .invalidRange:
                indexingStatusText = t(.toastInvalidNum)
            case .renameFailed(let msg):
                indexingStatusText = msg
                showToast(msg, type: .error)
            }
        } catch {
            files = []
            indexingStatusIsError = true
            indexingStatusText = t(.toastScanError)
            showToast(t(.toastScanError), type: .error)
        }
    }

    func refreshIndexingFiles() {
        let trimmed = indexingFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showToast(t(.toastNoFolderSelected), type: .warning)
            return
        }
        scanFolder(showToastOnSuccess: true)
    }

    func handleDroppedURLs(_ urls: [URL]) -> Bool {
        guard let first = urls.first else { return false }
        var isDir: ObjCBool = false
        let path: String
        if FileManager.default.fileExists(atPath: first.path, isDirectory: &isDir), isDir.boolValue {
            path = first.path
        } else {
            path = first.deletingLastPathComponent().path
        }
        indexingFolder = path
        rangeStartText = ""
        rangeEndText = ""
        scanFolder(showToastOnSuccess: false)
        return true
    }

    private func validatedRange(emptyToast: L10nKey) -> (start: Int, end: Int, count: Int)? {
        guard !files.isEmpty else {
            showToast(t(emptyToast), type: .warning)
            return nil
        }
        guard let start = Int(rangeStartText.trimmingCharacters(in: .whitespacesAndNewlines)),
              let end = Int(rangeEndText.trimmingCharacters(in: .whitespacesAndNewlines)),
              start >= 0, end >= 0 else {
            showToast(t(.toastInvalidNum), type: .warning)
            return nil
        }
        guard start <= end else {
            showToast(t(.toastStartGtEnd), type: .warning)
            return nil
        }
        let count = min(files.count, end - start + 1)
        return (start: start, end: end, count: count)
    }

    func previewRename() {
        guard let range = validatedRange(emptyToast: .toastNoPreview) else { return }
        do {
            files = try FileIndexingService.applyPreviewNames(to: files, start: range.start, end: range.end)
            indexingStatusIsError = false
            indexingStatusText = t(.statusPreview, ["count": "\(range.count)"])
        } catch {
            showToast(t(.toastInvalidNum), type: .error)
        }
    }

    func requestRename() {
        guard let range = validatedRange(emptyToast: .toastNoRename), range.count > 0 else { return }
        pendingRenameRange = range
        pendingFirstOld = files[0].name
        pendingFirstNew = "\(range.start).png"
        pendingLastOld = files[range.count - 1].name
        pendingLastNew = "\(range.start + range.count - 1).png"
        showConfirmRenameSheet = true
    }

    func cancelRename() {
        showConfirmRenameSheet = false
        pendingRenameRange = nil
    }

    func executeRename() {
        guard let range = pendingRenameRange else { return }
        showConfirmRenameSheet = false
        pendingRenameRange = nil

        isRenaming = true
        defer { isRenaming = false }

        do {
            let result = try FileIndexingService.renameFiles(
                in: indexingFolder,
                items: files,
                start: range.start,
                end: range.end
            )
            let msg = t(.renameSuccess, [
                "success_count": "\(result.successCount)",
                "count": "\(result.totalCount)",
            ])
            showToast(msg, type: .success)
            indexingStatusIsError = false
            indexingStatusText = msg
            previewImageIndex = nil
            files = (try? FileIndexingService.scanFolder(at: indexingFolder)) ?? []
        } catch let error as FileIndexingError {
            let msg: String
            switch error {
            case .folderNotExist: msg = t(.folderNotExist)
            case .noFiles: msg = t(.noFiles)
            case .invalidRange: msg = t(.toastInvalidNum)
            case .renameFailed(let detail): msg = detail
            }
            indexingStatusIsError = true
            indexingStatusText = msg
            showToast(msg, type: .error)
        } catch {
            indexingStatusIsError = true
            indexingStatusText = t(.toastRenameError)
            showToast(t(.toastRenameError), type: .error)
        }
    }

    // MARK: - Image Preview & On-Device AFM

    func openPreview(at index: Int) {
        guard files.indices.contains(index) else { return }
        closeSingleImageSummaryPopover()
        previewImageIndex = index
    }

    func closePreview() {
        closeSingleImageSummaryPopover()
        previewImageIndex = nil
    }

    func navigatePreview(by step: Int) {
        guard !files.isEmpty, let current = previewImageIndex else { return }
        closeSingleImageSummaryPopover()
        let count = files.count
        previewImageIndex = ((current + step) % count + count) % count
    }

    func closeSingleImageSummaryPopover() {
        afmSingleImageTask?.cancel()
        afmSingleImageTask = nil
        isSummarizingSingleImage = false
        showSingleImageSummaryPopover = false
    }

    func summarizeAllNotesWithAFM() {
        guard !files.isEmpty else {
            showToast(t(.toastAfmNoFiles), type: .warning)
            return
        }

        afmNotesTask?.cancel()
        notesSaveTask?.cancel()

        if !config.notesEnabled {
            updateConfig { $0.notesEnabled = true }
        }

        let existing = config.notesText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = existing.isEmpty ? "" : "\(existing)\n\n"
        let urls = files.map(\.url)
        let lang = config.language

        isSummarizingNotes = true
        afmNotesTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isSummarizingNotes = false
                self.afmNotesTask = nil
            }
            do {
                let result = try await AFMSummarizerService.shared.streamSummary(
                    imageURLs: urls,
                    lang: lang
                ) { [weak self] partial in
                    self?.config.notesText = prefix + partial
                }
                self.config.notesText = prefix + result.summary
                self.saveConfig(showToastOnSave: false)
                self.showToast(
                    self.t(.afmSummarizeSuccess, ["count": "\(result.processedCount)"]),
                    type: .success
                )
            } catch is CancellationError {
                // Cancelled cleanly
            } catch let error as AFMSummarizerError {
                self.handleAFMError(error)
            } catch {
                self.showToast(self.t(.toastAfmError), type: .error)
            }
        }
    }

    func summarizeCurrentImageWithAFM() {
        guard let idx = previewImageIndex, files.indices.contains(idx) else {
            showToast(t(.toastAfmNoFiles), type: .warning)
            return
        }

        afmSingleImageTask?.cancel()
        let targetURL = files[idx].url
        let lang = config.language

        singleImageSummaryText = ""
        showSingleImageSummaryPopover = true
        isSummarizingSingleImage = true

        afmSingleImageTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isSummarizingSingleImage = false
                self.afmSingleImageTask = nil
            }
            do {
                let result = try await AFMSummarizerService.shared.streamSummary(
                    imageURLs: [targetURL],
                    lang: lang
                ) { [weak self] partial in
                    self?.singleImageSummaryText = partial
                }
                self.singleImageSummaryText = result.summary
            } catch is CancellationError {
                // Cancelled cleanly
            } catch let error as AFMSummarizerError {
                self.showSingleImageSummaryPopover = false
                self.handleAFMError(error)
            } catch {
                self.showSingleImageSummaryPopover = false
                self.showToast(self.t(.toastAfmError), type: .error)
            }
        }
    }

    private func handleAFMError(_ error: AFMSummarizerError) {
        switch error {
        case .unavailable:
            refreshAFMStatus()
            showToast(t(.afmUnavailable), type: .warning, duration: 4.0)
        case .noValidImages:
            showToast(t(.toastAfmNoFiles), type: .warning)
        case .generationFailed(let message):
            showToast(message.isEmpty ? t(.toastAfmError) : message, type: .error)
        }
    }

    func copySingleImageSummary() {
        let text = singleImageSummaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showToast(t(.toastCopied), type: .success, duration: 1.8)
    }

    func refreshAFMStatus() {
        afmStatus = AFMSummarizerService.shared.checkAvailability()
    }

    // MARK: - Tab 2: Auto Capture & Permissions

    func browseCaptureSaveFolder() {
        let initial = config.saveFolder.isEmpty ? indexingFolder : config.saveFolder
        guard let selected = pickFolderWithPanel(initialPath: initial) else { return }
        updateConfig(showToastOnSave: true) { $0.saveFolder = selected }
    }

    func refreshPermissions(prompt: Bool, showToastOnResult: Bool = true) {
        permissions = PermissionsService.checkPermissions(prompt: prompt)
        if showToastOnResult {
            showToast(t(.toastPermissionsUpdated), type: .info)
        }
    }

    func openScreenRecordingSettings() {
        PermissionsService.openScreenRecordingSettings()
        showToast(t(.toastOpenPermSettings), type: .info, duration: 2.0)
    }

    func openAccessibilitySettings() {
        PermissionsService.openAccessibilitySettings()
        showToast(t(.toastOpenPermSettings), type: .info, duration: 2.0)
    }

    func takeScreenPreview(delaySec: Double) {
        refreshPermissions(prompt: false, showToastOnResult: false)
        guard permissions.screenRecording else {
            showToast(t(.toastScreenPermRequired), type: .warning, duration: 4.5)
            return
        }
        guard !isCapturingPreview else { return }

        isCapturingPreview = true
        if delaySec >= 1.5 {
            showToast(t(.toastPreviewDelay, ["sec": "\(Int(delaySec.rounded()))"]), type: .info, duration: 2.2)
        }

        Task { [weak self] in
            guard let self else { return }
            defer { self.isCapturingPreview = false }
            do {
                let result = try await ScreenCaptureHelper.captureFullscreenPreview(delaySec: delaySec)
                self.previewResult = result
                self.showToast(self.t(.toastPreviewReady), type: .success, duration: 2.2)
            } catch {
                self.refreshPermissions(prompt: false, showToastOnResult: false)
                self.showToast(self.t(.toastPreviewFailed), type: .error)
            }
        }
    }

    func pickRegionWithOverlay() async {
        guard !isPickingOverlay else { return }
        isPickingOverlay = true
        defer { isPickingOverlay = false }

        let result = await ScreenOverlayPickerController.shared.pick(target: .region)
        switch result {
        case .selectedRegion(let region):
            updateConfig { $0.region = region.normalized() }
            showToast(t(.toastOverlayRegionSet), type: .success)
            if permissions.screenRecording {
                takeScreenPreview(delaySec: 0.1)
            }
        case .selectedClick(let x, let y):
            updateConfig {
                $0.pageTurn.mode = .click
                $0.pageTurn.clickX = x
                $0.pageTurn.clickY = y
            }
            showToast(t(.toastOverlayRegionSet), type: .success)
        case .cancelled:
            showToast(t(.toastOverlayCancelled), type: .info, duration: 2.0)
        }
    }

    func armGlobalOverlayHotkey() {
        GlobalHotkeyService.shared.start(shortcut: config.overlayShortcut) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                await self.pickRegionWithOverlay()
            }
        }
    }

    func setRecordingOverlayShortcut(_ recording: Bool) {
        isRecordingOverlayShortcut = recording
        if recording {
            GlobalHotkeyService.shared.stop()
        } else {
            armGlobalOverlayHotkey()
        }
    }

    func updateOverlayShortcut(_ shortcut: HotkeyShortcut) {
        updateConfig { $0.overlayShortcut = shortcut }
        isRecordingOverlayShortcut = false
        armGlobalOverlayHotkey()
        showToast(t(.toastOverlayShortcutSet, ["shortcut": config.overlayShortcut.displayString]), type: .success)
    }

    func updatePageTurnKey(keyName: String, keyCode: Int, display: String) {
        updateConfig {
            $0.pageTurn.mode = .keyboard
            $0.pageTurn.keyName = keyName
            $0.pageTurn.keyCode = keyCode
        }
        showToast(t(.toastKeyRecorded, ["key": display]), type: .success)
    }

    func startAutoCapture() {
        let trimmedFolder = config.saveFolder.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFolder.isEmpty else {
            showToast(t(.toastCaptureFolderRequired), type: .warning)
            return
        }
        guard config.region.width >= 10, config.region.height >= 10 else {
            showToast(t(.toastCaptureInvalidRegion), type: .warning)
            return
        }

        refreshPermissions(prompt: false, showToastOnResult: false)
        saveConfig(showToastOnSave: false)

        let result = captureController.start(config: config) { [weak self] folder, _ in
            guard let self else { return }
            let expandedCurrent = (self.indexingFolder as NSString).expandingTildeInPath
            if !expandedCurrent.isEmpty && expandedCurrent == folder {
                self.scanFolder(showToastOnSuccess: false)
            }
        }

        switch result {
        case .success:
            if config.pageTurn.enabled && !permissions.accessibility {
                showToast(t(.toastAccessibilityNeeded), type: .warning, duration: 5.0)
            } else {
                showToast(t(.toastCaptureStarted), type: .success)
            }
        case .failure(let error):
            showToast(error.localizedDescription, type: .error)
        }
    }

    func stopAutoCapture() {
        captureController.stop()
        showToast(t(.toastCaptureStopped), type: .info)
    }

    func handleCaptureStatusChange(oldValue: CaptureStatusSnapshot, newValue: CaptureStatusSnapshot) {
        if oldValue.running && !newValue.running {
            if newValue.phase == .completed {
                showToast(t(.toastCaptureCompleted, ["count": "\(newValue.capturedCount)"]), type: .success)
            } else if newValue.phase == .error {
                showToast(newValue.lastError ?? t(.toastCaptureError), type: .error)
            }
        }
    }
}

