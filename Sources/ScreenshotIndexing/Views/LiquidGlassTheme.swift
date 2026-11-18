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
            Color(red: 0.02, green: 0.02, blue: 0.025)

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    SIMD2(0.0, 0.0), SIMD2(0.5, 0.0), SIMD2(1.0, 0.0),
                    SIMD2(0.0, 0.52), SIMD2(0.54, 0.46), SIMD2(1.0, 0.5),
                    SIMD2(0.0, 1.0), SIMD2(0.5, 1.0), SIMD2(1.0, 1.0),
                ],
                colors: [
                    Color(red: 0.028, green: 0.028, blue: 0.030),
                    Color(red: 0.044, green: 0.044, blue: 0.047),
                    Color(red: 0.066, green: 0.066, blue: 0.070),

                    Color(red: 0.036, green: 0.036, blue: 0.038),
                    Color(red: 0.072, green: 0.072, blue: 0.075),
                    Color(red: 0.048, green: 0.048, blue: 0.051),

                    Color(red: 0.025, green: 0.025, blue: 0.027),
                    Color(red: 0.038, green: 0.038, blue: 0.040),
                    Color(red: 0.056, green: 0.056, blue: 0.059),
                ]
            )
            .opacity(0.92)

            Circle()
                .fill(Color.white.opacity(0.035))
                .frame(width: 560, height: 560)
                .blur(radius: 130)
                .offset(x: 340, y: -220)

            Circle()
                .fill(Color.white.opacity(0.025))
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
    @Environment(\.colorScheme) private var colorScheme
    private let padding: CGFloat
    private let tint: Color?
    private let content: Content

    init(padding: CGFloat = GlassMetrics.cardPadding, tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: GlassMetrics.cardCornerRadius, style: .continuous)
        content
            .padding(padding)
            .background {
                ZStack {
                    shape.fill(
                        colorScheme == .dark
                            ? Color.white.opacity(0.055)
                            : Color.white.opacity(0.68)
                    )
                    if let tint {
                        shape.fill(tint.opacity(0.10))
                    }
                }
            }
            .overlay {
                shape.strokeBorder(
                    Color.white.opacity(colorScheme == .dark ? 0.12 : 0.65),
                    lineWidth: 1
                )
            }
            .shadow(
                color: .black.opacity(colorScheme == .dark ? 0.28 : 0.06),
                radius: 10,
                y: 4
            )
    }
}

// MARK: - Top & Bottom Scroll Fade Mask

struct ScrollTopFadeModifier: ViewModifier {
    let height: CGFloat
    @State private var scrollEdgeOffsets: CGPoint = .zero

    func body(content: Content) -> some View {
        let topOpacity = scrollEdgeOffsets.x <= 1 ? 1.0 : max(0, 1 - Double(scrollEdgeOffsets.x) / 22.0)
        let bottomOpacity = scrollEdgeOffsets.y <= 1 ? 1.0 : max(0, 1 - Double(scrollEdgeOffsets.y) / 22.0)

        content
            .onScrollGeometryChange(for: CGPoint.self) { geo in
                let top = max(0, geo.contentOffset.y + geo.contentInsets.top)
                let bottom = max(0, geo.contentSize.height - (geo.contentOffset.y + geo.containerSize.height))
                return CGPoint(x: min(top, 28), y: min(bottom, 28))
            } action: { _, newVal in
                if scrollEdgeOffsets != newVal {
                    scrollEdgeOffsets = newVal
                }
            }
            .mask {
                GeometryReader { geo in
                    let totalHeight = max(1, geo.size.height)
                    let fadeStop = min(0.45, max(0.001, height / totalHeight))
                    LinearGradient(
                        stops: [
                            .init(color: .black.opacity(topOpacity), location: 0),
                            .init(color: .black, location: fadeStop),
                            .init(color: .black, location: max(fadeStop, 1 - fadeStop)),
                            .init(color: .black.opacity(bottomOpacity), location: 1),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
            }
    }
}

extension View {
    func scrollTopFade(height: CGFloat = 36) -> some View {
        modifier(ScrollTopFadeModifier(height: height))
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

// MARK: - Apple Intelligence Palette, Streaming Indicator & Glow Border

private enum AppleIntelligencePalette {
    static let indigo = Color(red: 0x5e / 255.0, green: 0x5c / 255.0, blue: 0xe6 / 255.0) // #5e5ce6
    static let purple = Color(red: 0xbf / 255.0, green: 0x5a / 255.0, blue: 0xf2 / 255.0) // #bf5af2
    static let pink   = Color(red: 0xff / 255.0, green: 0x37 / 255.0, blue: 0x5f / 255.0) // #ff375f
    static let orange = Color(red: 0xff / 255.0, green: 0x9f / 255.0, blue: 0x0a / 255.0) // #ff9f0a
    static let green  = Color(red: 0x30 / 255.0, green: 0xd1 / 255.0, blue: 0x58 / 255.0) // #30d158
    static let cyan   = Color(red: 0x64 / 255.0, green: 0xd2 / 255.0, blue: 0xff / 255.0) // #64d2ff

    static let shimmerColors: [Color] = [
        .clear, indigo, purple, cyan, .clear
    ]

    static let glowColors: [Color] = [
        indigo, purple, pink, orange, green, cyan, indigo
    ]
}

struct AIStreamingIndicator: View {
    let label: String

    var body: some View {
        TimelineView(.animation) { timeline in
            let progress = (timeline.date.timeIntervalSinceReferenceDate / 1.1)
                .truncatingRemainder(dividingBy: 1.0)
            let iconOpacity = 0.65 + 0.35 * (0.5 + 0.5 * sin(progress * .pi * 2))

            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                AppleIntelligencePalette.indigo,
                                AppleIntelligencePalette.purple,
                                AppleIntelligencePalette.cyan,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .opacity(iconOpacity)

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
                                        colors: AppleIntelligencePalette.shimmerColors,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * 0.55)
                                .offset(x: (progress * 1.7 - 0.6) * geo.size.width)
                        }
                        .clipShape(Capsule())
                    }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassInputSurface(isHighlighted: true, cornerRadius: 10)
    }
}

struct AppleIntelligenceGlowBorderModifier: ViewModifier {
    let isActive: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .overlay {
                Group {
                    if isActive {
                        TimelineView(.animation) { timeline in
                            let t = timeline.date.timeIntervalSinceReferenceDate
                            let gradient = AngularGradient(
                                gradient: Gradient(colors: AppleIntelligencePalette.glowColors),
                                center: .center,
                                angle: .degrees((t * 110).truncatingRemainder(dividingBy: 360))
                            )

                            ZStack {
                                shape
                                    .stroke(gradient, lineWidth: 5)
                                    .blur(radius: 6)
                                    .opacity(0.45)

                                shape
                                    .strokeBorder(gradient, lineWidth: 2)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                .allowsHitTesting(false)
                .animation(.easeInOut(duration: 0.25), value: isActive)
            }
    }
}

extension View {
    func appleIntelligenceGlowBorder(isActive: Bool, cornerRadius: CGFloat) -> some View {
        modifier(AppleIntelligenceGlowBorderModifier(isActive: isActive, cornerRadius: cornerRadius))
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
    @State private var isResizeCursorPushed = false

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
            isHoveringDivider = hovering
            updateResizeCursor()
        }
        .onDisappear {
            isHoveringDivider = false
            dragStartWidth = nil
            updateResizeCursor()
        }
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartWidth == nil {
                        dragStartWidth = currentWidth
                    }
                    updateResizeCursor()
                    let start = dragStartWidth ?? currentWidth
                    let proposed = start + value.translation.width
                    sidebarWidth = min(max(proposed, minSidebarWidth), effectiveMax)
                }
                .onEnded { _ in
                    dragStartWidth = nil
                    updateResizeCursor()
                }
        )
    }

    private func updateResizeCursor() {
        let wantsCursor = isHoveringDivider || dragStartWidth != nil
        if wantsCursor && !isResizeCursorPushed {
            NSCursor.resizeLeftRight.push()
            isResizeCursorPushed = true
        } else if !wantsCursor && isResizeCursorPushed {
            NSCursor.pop()
            isResizeCursorPushed = false
        }
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
    @Environment(\.colorScheme) private var colorScheme
    let toast: ToastMessage?
    var topPadding: CGFloat = 6
    let onDismiss: () -> Void

    var body: some View {
        VStack {
            if let toast {
                HStack(spacing: 8) {
                    Image(systemName: toast.type.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(toast.type.tintColor)

                    Text(toast.text)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 7.5)
                .background {
                    Capsule()
                        .fill(colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.88))
                        .overlay {
                            Capsule()
                                .strokeBorder(toast.type.tintColor.opacity(0.35), lineWidth: 1)
                        }
                }
                .glassEffect(.regular.tint(toast.type.tintColor.opacity(0.14)).interactive(), in: .capsule)
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.38 : 0.12), radius: 14, y: 5)
                .onTapGesture(perform: onDismiss)
                .frame(maxWidth: 420)
                .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.92, anchor: .top)))
                .padding(.top, topPadding)
            }
            Spacer(minLength: 0)
        }
        .ignoresSafeArea(.container, edges: .top)
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

        if resolvedTab != previousTab {
            cancelRename()
            closePreview()
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
        let wasAutoCaptureEnabled = config.autoCaptureEnabled
        mutate(&config)
        saveConfig(showToastOnSave: showToastOnSave)
        if !config.autoCaptureEnabled {
            GlobalHotkeyService.shared.stop()
            if captureController.status.running {
                captureController.stop()
            }
            if activeTab == .capture {
                withAnimation(GlassMetrics.springAnimation) {
                    activeTab = .indexing
                }
            }
        } else if !wasAutoCaptureEnabled && !isRecordingOverlayShortcut {
            armGlobalOverlayHotkey()
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

    func clearIndexingFolder() {
        indexingFolder = ""
        files = []
        rangeStartText = ""
        rangeEndText = ""
        indexingStatusText = ""
        indexingStatusIsError = false
        cancelRename()
        closePreview()
    }

    private func closePreviewIfOutOfBounds() {
        if let idx = previewImageIndex, !files.indices.contains(idx) {
            closePreview()
        }
    }

    func scanFolder(showToastOnSuccess: Bool = false) {
        cancelRename()

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
            closePreviewIfOutOfBounds()
            indexingStatusIsError = false
            indexingStatusText = t(.statusFileCount, ["count": "\(scanned.count)"])

            if showToastOnSuccess {
                showToast(t(.toastRefresh), type: .info, duration: 2.0)
            }
        } catch let error as FileIndexingError {
            files = []
            closePreviewIfOutOfBounds()
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
            closePreviewIfOutOfBounds()
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

    func syncLivePreviewRange() {
        guard !files.isEmpty else { return }
        let startTrimmed = rangeStartText.trimmingCharacters(in: .whitespacesAndNewlines)
        let endTrimmed = rangeEndText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = Int(startTrimmed),
           let end = Int(endTrimmed),
           start >= 0,
           start <= end,
           let updated = try? FileIndexingService.applyPreviewNames(to: files, start: start, end: end) {
            files = updated
        } else {
            files = files.map { item in
                var copy = item
                copy.previewNewName = nil
                return copy
            }
        }
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
            if !files.isEmpty {
                rangeStartText = "1"
                rangeEndText = "\(files.count)"
                files = (try? FileIndexingService.applyPreviewNames(to: files, start: 1, end: files.count)) ?? files
            } else {
                rangeStartText = ""
                rangeEndText = ""
            }
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
            indexingStatusIsError = true
            indexingStatusText = t(.toastAfmNoFiles)
            return
        }

        afmNotesTask?.cancel()
        notesSaveTask?.cancel()

        if indexingStatusIsError {
            indexingStatusIsError = false
            indexingStatusText = ""
        }

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
                self.indexingStatusIsError = false
            } catch is CancellationError {
                // Cancelled cleanly
            } catch let error as AFMSummarizerError {
                self.handleAFMError(error)
            } catch {
                self.indexingStatusIsError = true
                self.indexingStatusText = self.t(.toastAfmError)
            }
        }
    }

    func summarizeCurrentImageWithAFM() {
        guard let idx = previewImageIndex, files.indices.contains(idx) else {
            indexingStatusIsError = true
            indexingStatusText = t(.toastAfmNoFiles)
            return
        }

        afmSingleImageTask?.cancel()
        if indexingStatusIsError {
            indexingStatusIsError = false
            indexingStatusText = ""
        }

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
                self.indexingStatusIsError = false
            } catch is CancellationError {
                // Cancelled cleanly
            } catch let error as AFMSummarizerError {
                self.showSingleImageSummaryPopover = false
                self.handleAFMError(error)
            } catch {
                self.showSingleImageSummaryPopover = false
                self.indexingStatusIsError = true
                self.indexingStatusText = self.t(.toastAfmError)
            }
        }
    }

    private func handleAFMError(_ error: AFMSummarizerError) {
        indexingStatusIsError = true
        switch error {
        case .unavailable:
            refreshAFMStatus()
            indexingStatusText = t(.afmUnavailable)
        case .noValidImages:
            indexingStatusText = t(.toastAfmNoFiles)
        case .generationFailed(let message):
            indexingStatusText = message.isEmpty ? t(.toastAfmError) : message
        }
    }

    func copySingleImageSummary() {
        let text = singleImageSummaryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
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
        guard config.autoCaptureEnabled else {
            GlobalHotkeyService.shared.stop()
            return
        }
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

