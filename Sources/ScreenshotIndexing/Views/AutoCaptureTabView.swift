import AppKit
import SwiftUI

struct AutoCaptureTabView: View {
    @Environment(AppViewModel.self) private var viewModel

    private enum FocusField: Hashable {
        case saveFolder
        case regionX, regionY, regionW, regionH
        case interval, maxShots
    }

    @State private var sidebarWidth: CGFloat = 395
    @FocusState private var focusedField: FocusField?

    // Numeric field string drafts synced with config
    @State private var regXText = ""
    @State private var regYText = ""
    @State private var regWText = ""
    @State private var regHText = ""
    @State private var intervalText = ""
    @State private var maxShotsText = ""

    // Interactive key/hotkey recorder state
    @State private var isListeningOverlayShortcut = false
    @State private var isListeningPageTurnKey = false
    @State private var recorderMonitor: Any?

    // Canvas drag state
    @State private var dragStartLogical: (x: Int, y: Int)?
    @State private var regionBeforeDrag: CaptureRegion?

    var body: some View {
        GlassEffectContainer(spacing: GlassMetrics.containerSpacing) {
            ResizableHorizontalSplit(
                sidebarWidth: $sidebarWidth,
                minSidebarWidth: 360,
                maxSidebarWidth: 500,
                minDetailWidth: 460
            ) {
                leftControlsColumn
            } detail: {
                rightPreviewPanel
            }
        }
        .onAppear {
            syncDraftsFromConfig()
        }
        .onChange(of: viewModel.config) { _, _ in
            syncDraftsFromConfig()
        }
        .onChange(of: focusedField) { oldField, _ in
            commitFieldOnBlur(oldField)
        }
        .onDisappear {
            stopAnyKeyRecorder()
        }
    }

    // MARK: - Left Controls Column

    private var leftControlsColumn: some View {
        ScrollView {
            VStack(spacing: 14) {
                saveFolderCard
                captureRegionCard
                timerAndShutterCard
                autoPageTurnCard
                captureControlAndPermissionsCard
            }
            .padding(.bottom, 6)
        }
        .scrollIndicators(.automatic)
    }

    private var saveFolderCard: some View {
        @Bindable var vm = viewModel

        return GlassCard {
            VStack(alignment: .leading, spacing: 11) {
                GlassSectionHeader(
                    title: viewModel.t(.captureSaveFolder),
                    systemImage: "folder.badge.gearshape"
                )

                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 12.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField(viewModel.t(.captureFolderPlaceholder), text: $vm.config.saveFolder)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5))
                        .focused($focusedField, equals: .saveFolder)
                        .onSubmit {
                            viewModel.saveConfig(showToastOnSave: true)
                        }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8.5)
                .glassInputSurface(isFocused: focusedField == .saveFolder)

                HStack {
                    GlassPillButton(
                        viewModel.t(.browse),
                        systemImage: "folder.badge.plus",
                        variant: .standard,
                        compact: true
                    ) {
                        viewModel.browseCaptureSaveFolder()
                    }
                    Spacer()
                }
            }
        }
    }

    private var captureRegionCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(
                    title: viewModel.t(.captureRegion),
                    systemImage: "viewfinder"
                )

                HStack(spacing: 8) {
                    regionCoordField(label: "X", text: $regXText, field: .regionX)
                    regionCoordField(label: "Y", text: $regYText, field: .regionY)
                    regionCoordField(label: "W", text: $regWText, field: .regionW)
                    regionCoordField(label: "H", text: $regHText, field: .regionH)
                }

                HStack(spacing: 8) {
                    GlassPillButton(
                        viewModel.t(.btnTestShotNow),
                        systemImage: "camera",
                        variant: .standard,
                        compact: true,
                        isLoading: viewModel.isCapturingPreview,
                        isDisabled: !viewModel.permissions.screenRecording
                    ) {
                        viewModel.takeScreenPreview(delaySec: 0.2)
                    }

                    GlassPillButton(
                        viewModel.t(.btnTestShot2s),
                        systemImage: "clock",
                        variant: .standard,
                        compact: true,
                        isLoading: viewModel.isCapturingPreview,
                        isDisabled: !viewModel.permissions.screenRecording
                    ) {
                        viewModel.takeScreenPreview(delaySec: 2.0)
                    }
                }

                GlassPillButton(
                    viewModel.t(.btnPickRegionOverlay),
                    systemImage: "macwindow.and.cursorarrow",
                    variant: .accentCyan,
                    isLoading: viewModel.isPickingOverlay
                ) {
                    Task { await viewModel.pickRegionWithOverlay() }
                }

                // Region Picker Hotkey Recorder
                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.t(.overlayShortcutLabel))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    recorderButton(
                        displayText: isListeningOverlayShortcut
                            ? viewModel.t(.overlayShortcutListening)
                            : viewModel.config.overlayShortcut.displayString,
                        isListening: isListeningOverlayShortcut,
                        systemImage: "command",
                        tooltip: viewModel.t(.overlayShortcutTitle)
                    ) {
                        toggleOverlayShortcutRecorder()
                    }
                }
            }
        }
    }

    private func regionCoordField(label: String, text: Binding<String>, field: FocusField) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .monospacedDigit()
                .focused($focusedField, equals: field)
                .onChange(of: text.wrappedValue) { _, _ in
                    applyRegionDraftLive()
                }
                .onSubmit {
                    commitRegionDraft()
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 7)
                .glassInputSurface(isFocused: focusedField == field)
        }
        .frame(maxWidth: .infinity)
    }

    private var timerAndShutterCard: some View {
        let intervalSliderBinding = Binding<Double>(
            get: { Double(viewModel.config.intervalSec) },
            set: { newVal in
                let clamped = max(1, min(10, Int(newVal.rounded())))
                viewModel.config.intervalSec = clamped
                intervalText = "\(clamped)"
            }
        )

        let countdownBinding = Binding<Int>(
            get: { viewModel.config.countdownSec },
            set: { newVal in
                let clamped = max(0, min(10, newVal))
                viewModel.updateConfig { $0.countdownSec = clamped }
            }
        )

        let soundBinding = Binding<Bool>(
            get: { viewModel.config.soundEnabled },
            set: { newVal in
                viewModel.updateConfig { $0.soundEnabled = newVal }
            }
        )

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(
                    title: viewModel.t(.captureTimerSound),
                    systemImage: "timer"
                )

                // Interval Slider + Numeric Field
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(viewModel.t(.captureInterval))
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        HStack(spacing: 4) {
                            TextField("3", text: $intervalText)
                                .textFieldStyle(.plain)
                                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .frame(width: 32)
                                .focused($focusedField, equals: .interval)
                                .onSubmit { commitIntervalDraft() }
                            Text("s")
                                .font(.system(size: 11.5, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .glassInputSurface(isFocused: focusedField == .interval, cornerRadius: 10)
                    }

                    Slider(value: intervalSliderBinding, in: 1...10, step: 1) { editing in
                        if !editing {
                            viewModel.saveConfig(showToastOnSave: false)
                        }
                    }
                }

                // Shot Limit
                HStack {
                    Text(viewModel.t(.captureMaxShots))
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    TextField(viewModel.t(.captureMaxShotsPlaceholder), text: $maxShotsText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12.5, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .multilineTextAlignment(.trailing)
                        .frame(width: 72)
                        .focused($focusedField, equals: .maxShots)
                        .onSubmit { commitMaxShotsDraft() }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .glassInputSurface(isFocused: focusedField == .maxShots, cornerRadius: 10)
                }

                // Countdown Stepper
                HStack {
                    Text(viewModel.t(.captureCountdown))
                        .font(.system(size: 12.5, weight: .medium))
                    Spacer()
                    GlassBadge(
                        text: "\(viewModel.config.countdownSec)s",
                        foreground: .primary
                    )
                    Stepper("", value: countdownBinding, in: 0...10)
                        .labelsHidden()
                }

                // Shutter Sound Toggle
                Toggle(isOn: soundBinding) {
                    Text(viewModel.t(.captureSoundLabel))
                        .font(.system(size: 12.5, weight: .medium))
                }
                .toggleStyle(.switch)
            }
        }
    }

    private var autoPageTurnCard: some View {
        let enabledBinding = Binding<Bool>(
            get: { viewModel.config.pageTurn.enabled },
            set: { newVal in
                if !newVal && isListeningPageTurnKey {
                    stopAnyKeyRecorder()
                }
                viewModel.updateConfig { $0.pageTurn.enabled = newVal }
            }
        )

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(
                    title: viewModel.t(.pageTurnTitle),
                    systemImage: "book.pages"
                )

                Toggle(isOn: enabledBinding) {
                    Text(viewModel.t(.pageTurnEnable))
                        .font(.system(size: 12.5, weight: .medium))
                }
                .toggleStyle(.switch)

                VStack(alignment: .leading, spacing: 5) {
                    Text(viewModel.t(.ptKeyRecorderLabel))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(.secondary)

                    recorderButton(
                        displayText: isListeningPageTurnKey
                            ? viewModel.t(.ptKeyListening)
                            : InputSimulationService.displayName(for: viewModel.config.pageTurn.keyName),
                        isListening: isListeningPageTurnKey,
                        systemImage: "keyboard",
                        tooltip: viewModel.t(.ptKeyRecorderTitle)
                    ) {
                        togglePageTurnKeyRecorder()
                    }
                    .disabled(!viewModel.config.pageTurn.enabled)
                }
                .opacity(viewModel.config.pageTurn.enabled ? 1.0 : 0.45)
            }
        }
    }

    private var captureControlAndPermissionsCard: some View {
        let snapshot = viewModel.captureController.status
        let counterText = snapshot.maxShots > 0
            ? "\(snapshot.capturedCount) / \(snapshot.maxShots)"
            : "\(snapshot.capturedCount) / ∞"

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(
                    title: viewModel.t(.captureControls),
                    systemImage: "play.circle"
                )

                HStack(spacing: 10) {
                    GlassPillButton(
                        viewModel.t(.btnCaptureStart),
                        systemImage: "play.fill",
                        variant: .primary,
                        isDisabled: snapshot.running
                    ) {
                        viewModel.startAutoCapture()
                    }

                    GlassPillButton(
                        viewModel.t(.btnCaptureStop),
                        systemImage: "stop.fill",
                        variant: .destructive,
                        isDisabled: !snapshot.running
                    ) {
                        viewModel.stopAutoCapture()
                    }

                    Spacer(minLength: 0)
                }

                // Live Status Box
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        PulsingStatusDot(state: viewModel.captureStatusDotState, size: 7.5)
                        Text(viewModel.phaseDisplayText(snapshot))
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(.primary)
                        Spacer()
                        GlassBadge(text: counterText, foreground: .primary)
                    }

                    if let lastError = snapshot.lastError, !lastError.isEmpty {
                        Text(lastError)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .glassInputSurface()

                Divider().opacity(0.45)

                // macOS TCC Permissions
                VStack(spacing: 8) {
                    permissionRow(
                        title: viewModel.t(.permScreenRecording),
                        granted: viewModel.permissions.screenRecording
                    ) {
                        viewModel.openScreenRecordingSettings()
                    }

                    permissionRow(
                        title: viewModel.t(.permAccessibility),
                        granted: viewModel.permissions.accessibility
                    ) {
                        viewModel.openAccessibilitySettings()
                    }

                    HStack {
                        GlassPillButton(
                            viewModel.t(.btnCheckPermissions),
                            systemImage: "checkmark.shield",
                            variant: .standard,
                            compact: true
                        ) {
                            viewModel.refreshPermissions(prompt: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func permissionRow(title: String, granted: Bool, openAction: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)

            Spacer()

            GlassBadge(
                text: granted ? viewModel.t(.permGranted) : viewModel.t(.permMissing),
                tint: granted ? .green.opacity(0.24) : .orange.opacity(0.24),
                foreground: granted ? .green : .orange
            )

            GlassPillButton(
                viewModel.t(.btnOpenSettings),
                variant: .standard,
                compact: true,
                action: openAction
            )
        }
    }

    private func recorderButton(
        displayText: String,
        isListening: Bool,
        systemImage: String,
        tooltip: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isListening ? Color.accentColor : Color.secondary)

                Text(displayText)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(isListening ? Color.accentColor : Color.primary)

                Spacer()

                if isListening {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8.5)
            .glassInputSurface(isFocused: isListening, isHighlighted: isListening)
            .contentShape(RoundedRectangle(cornerRadius: GlassMetrics.inputCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(tooltip)
    }

    // MARK: - Right Panel: Interactive Screen Preview Canvas

    private var rightPreviewPanel: some View {
        let reg = viewModel.config.region
        let scaleBadgeText: String = {
            guard let preview = viewModel.previewResult else { return "—" }
            let scale = preview.scaleFactor
            let scaleText = abs(scale.rounded() - scale) < 0.05
                ? "\(Int(scale.rounded()))x"
                : String(format: "%.1fx", scale)
            return "\(preview.screenWidth)×\(preview.screenHeight) pt • \(scaleText)"
        }()

        return GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    GlassSectionHeader(
                        title: viewModel.t(.viewCanvas),
                        systemImage: "macwindow"
                    )
                    Spacer()
                    GlassBadge(text: scaleBadgeText, foreground: .secondary)
                }

                previewStage
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .glassInputSurface(cornerRadius: 16)

                HStack(spacing: 10) {
                    GlassBadge(
                        text: viewModel.t(.canvasCoordSummary, [
                            "x": "\(reg.x)",
                            "y": "\(reg.y)",
                            "w": "\(reg.width)",
                            "h": "\(reg.height)",
                        ]),
                        tint: .accentColor.opacity(0.16),
                        foreground: .primary
                    )

                    Spacer()

                    Text(viewModel.t(.canvasDragHint))
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var previewStage: some View {
        if !viewModel.permissions.screenRecording {
            VStack(spacing: 14) {
                Image(systemName: "lock.display")
                    .font(.system(size: 32, weight: .light))
                    .foregroundStyle(.orange)

                Text(viewModel.t(.canvasPermRequired))
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)

                HStack(spacing: 10) {
                    GlassPillButton(
                        viewModel.t(.btnOpenScreenPerm),
                        systemImage: "gearshape",
                        variant: .primary,
                        compact: true
                    ) {
                        viewModel.openScreenRecordingSettings()
                    }

                    GlassPillButton(
                        viewModel.t(.btnCheckPermissions),
                        systemImage: "checkmark.shield",
                        variant: .standard,
                        compact: true
                    ) {
                        viewModel.refreshPermissions(prompt: true)
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let preview = viewModel.previewResult {
            GeometryReader { geo in
                let imageRect = aspectFitRect(
                    imageWidth: CGFloat(max(1, preview.imageWidth)),
                    imageHeight: CGFloat(max(1, preview.imageHeight)),
                    in: geo.size,
                    padding: 14
                )
                let overlayRect = regionViewRect(
                    region: viewModel.config.region,
                    preview: preview,
                    imageRect: imageRect
                )

                ZStack(alignment: .topLeading) {
                    Color.clear

                    Image(nsImage: preview.image)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: imageRect.width, height: imageRect.height)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .shadow(color: .black.opacity(0.22), radius: 14, y: 4)
                        .position(x: imageRect.midX, y: imageRect.midY)

                    // Interactive Capture Region Overlay
                    regionOverlayBox(rect: overlayRect, region: viewModel.config.region, boundsRect: imageRect)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 1, coordinateSpace: .local)
                        .onChanged { value in
                            handleCanvasDragChanged(value: value, preview: preview, imageRect: imageRect)
                        }
                        .onEnded { value in
                            handleCanvasDragEnded(value: value, preview: preview, imageRect: imageRect)
                        }
                )
            }
        } else {
            VStack(spacing: 14) {
                Image(systemName: "display")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.secondary)

                VStack(spacing: 6) {
                    Text(viewModel.t(.canvasEmptyTitle))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(viewModel.t(.canvasEmptyDesc))
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 340)
                }

                GlassPillButton(
                    viewModel.t(.btnTestShotNow),
                    systemImage: "camera",
                    variant: .primary,
                    compact: true,
                    isLoading: viewModel.isCapturingPreview
                ) {
                    viewModel.takeScreenPreview(delaySec: 0.2)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func regionOverlayBox(rect: CGRect, region: CaptureRegion, boundsRect: CGRect) -> some View {
        let clamped = rect.intersection(boundsRect)
        let drawRect = clamped.isNull ? rect : clamped
        let handleSize: CGFloat = 8

        let badgeAbove = drawRect.minY - 26 >= boundsRect.minY + 4
        let badgeY = badgeAbove ? (drawRect.minY - 14) : (drawRect.minY + 14)
        let badgeX = min(max(boundsRect.minX + 44, drawRect.minX + 42), boundsRect.maxX - 44)

        return ZStack {
            Rectangle()
                .fill(Color.accentColor.opacity(0.16))
                .frame(width: max(2, drawRect.width), height: max(2, drawRect.height))
                .overlay {
                    Rectangle()
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                }
                .position(x: drawRect.midX, y: drawRect.midY)

            // Corner handles
            ForEach(0..<4, id: \.self) { corner in
                let pt: CGPoint = switch corner {
                case 0: CGPoint(x: drawRect.minX, y: drawRect.minY)
                case 1: CGPoint(x: drawRect.maxX, y: drawRect.minY)
                case 2: CGPoint(x: drawRect.minX, y: drawRect.maxY)
                default: CGPoint(x: drawRect.maxX, y: drawRect.maxY)
                }

                Rectangle()
                    .fill(Color.white)
                    .frame(width: handleSize, height: handleSize)
                    .overlay {
                        Rectangle()
                            .strokeBorder(Color.accentColor, lineWidth: 1.8)
                    }
                    .position(pt)
            }

            // Dimension pill badge
            Text("\(region.width)×\(region.height) pt")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.accentColor))
                .shadow(color: .black.opacity(0.2), radius: 4, y: 1)
                .position(x: badgeX, y: badgeY)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Coordinate Math

    private func aspectFitRect(
        imageWidth: CGFloat,
        imageHeight: CGFloat,
        in containerSize: CGSize,
        padding: CGFloat
    ) -> CGRect {
        let availW = max(40, containerSize.width - padding * 2)
        let availH = max(40, containerSize.height - padding * 2)
        let scale = min(availW / imageWidth, availH / imageHeight)
        let drawW = max(20, imageWidth * scale)
        let drawH = max(20, imageHeight * scale)
        let x = (containerSize.width - drawW) / 2
        let y = (containerSize.height - drawH) / 2
        return CGRect(x: x, y: y, width: drawW, height: drawH)
    }

    private func regionViewRect(
        region: CaptureRegion,
        preview: ScreenPreviewResult,
        imageRect: CGRect
    ) -> CGRect {
        let imgW = CGFloat(max(1, preview.imageWidth))
        let imgH = CGFloat(max(1, preview.imageHeight))
        let scale = CGFloat(preview.scaleFactor)

        let pxX = CGFloat(region.x - preview.originX) * scale
        let pxY = CGFloat(region.y - preview.originY) * scale
        let pxW = CGFloat(region.width) * scale
        let pxH = CGFloat(region.height) * scale

        let vx = imageRect.minX + (pxX / imgW) * imageRect.width
        let vy = imageRect.minY + (pxY / imgH) * imageRect.height
        let vw = (pxW / imgW) * imageRect.width
        let vh = (pxH / imgH) * imageRect.height
        return CGRect(x: vx, y: vy, width: vw, height: vh)
    }

    private func viewPointToLogical(
        _ point: CGPoint,
        preview: ScreenPreviewResult,
        imageRect: CGRect
    ) -> (x: Int, y: Int) {
        let clampedX = min(max(point.x, imageRect.minX), imageRect.maxX)
        let clampedY = min(max(point.y, imageRect.minY), imageRect.maxY)

        let u = (clampedX - imageRect.minX) / max(1, imageRect.width)
        let v = (clampedY - imageRect.minY) / max(1, imageRect.height)

        let pxX = u * CGFloat(preview.imageWidth)
        let pxY = v * CGFloat(preview.imageHeight)
        let safeScale = max(0.5, preview.scaleFactor)

        let logicalX = Int((Double(preview.originX) + Double(pxX) / safeScale).rounded())
        let logicalY = Int((Double(preview.originY) + Double(pxY) / safeScale).rounded())

        let minX = preview.originX
        let maxX = preview.originX + preview.screenWidth
        let minY = preview.originY
        let maxY = preview.originY + preview.screenHeight

        return (
            x: min(max(logicalX, minX), maxX),
            y: min(max(logicalY, minY), maxY)
        )
    }

    private func handleCanvasDragChanged(
        value: DragGesture.Value,
        preview: ScreenPreviewResult,
        imageRect: CGRect
    ) {
        if dragStartLogical == nil {
            regionBeforeDrag = viewModel.config.region
            dragStartLogical = viewPointToLogical(value.startLocation, preview: preview, imageRect: imageRect)
        }
        guard let start = dragStartLogical else { return }
        let current = viewPointToLogical(value.location, preview: preview, imageRect: imageRect)

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = max(10, abs(current.x - start.x))
        let h = max(10, abs(current.y - start.y))
        viewModel.config.region = CaptureRegion(x: x, y: y, width: w, height: h)
    }

    private func handleCanvasDragEnded(
        value: DragGesture.Value,
        preview: ScreenPreviewResult,
        imageRect: CGRect
    ) {
        defer {
            dragStartLogical = nil
            regionBeforeDrag = nil
        }

        guard let start = dragStartLogical else { return }
        let end = viewPointToLogical(value.location, preview: preview, imageRect: imageRect)
        let dx = abs(end.x - start.x)
        let dy = abs(end.y - start.y)

        if dx < 5 || dy < 5 {
            if let previous = regionBeforeDrag {
                viewModel.config.region = previous
            }
            return
        }

        let newRegion = CaptureRegion(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: max(10, dx),
            height: max(10, dy)
        ).normalized()

        viewModel.updateConfig { $0.region = newRegion }
        viewModel.showToast(
            viewModel.t(.toastRegionUpdated, [
                "x": "\(newRegion.x)",
                "y": "\(newRegion.y)",
                "w": "\(newRegion.width)",
                "h": "\(newRegion.height)",
            ]),
            type: .success,
            duration: 2.2
        )
    }

    // MARK: - Field Draft Sync

    private func syncDraftsFromConfig() {
        let reg = viewModel.config.region
        if focusedField != .regionX { regXText = "\(reg.x)" }
        if focusedField != .regionY { regYText = "\(reg.y)" }
        if focusedField != .regionW { regWText = "\(reg.width)" }
        if focusedField != .regionH { regHText = "\(reg.height)" }
        if focusedField != .interval { intervalText = "\(viewModel.config.intervalSec)" }
        if focusedField != .maxShots {
            maxShotsText = viewModel.config.maxShots > 0 ? "\(viewModel.config.maxShots)" : ""
        }
    }

    private func applyRegionDraftLive() {
        var region = viewModel.config.region
        if let x = Int(regXText.trimmingCharacters(in: .whitespaces)) { region.x = x }
        if let y = Int(regYText.trimmingCharacters(in: .whitespaces)) { region.y = y }
        if let w = Int(regWText.trimmingCharacters(in: .whitespaces)) { region.width = max(1, w) }
        if let h = Int(regHText.trimmingCharacters(in: .whitespaces)) { region.height = max(1, h) }
        viewModel.config.region = region
    }

    private func commitRegionDraft() {
        applyRegionDraftLive()
        let normalized = viewModel.config.region.normalized()
        viewModel.updateConfig { $0.region = normalized }
        regXText = "\(normalized.x)"
        regYText = "\(normalized.y)"
        regWText = "\(normalized.width)"
        regHText = "\(normalized.height)"
    }

    private func commitIntervalDraft() {
        let raw = Int(intervalText.trimmingCharacters(in: .whitespaces)) ?? viewModel.config.intervalSec
        let clamped = max(1, min(10, raw))
        viewModel.updateConfig { $0.intervalSec = clamped }
        intervalText = "\(clamped)"
    }

    private func commitMaxShotsDraft() {
        let trimmed = maxShotsText.trimmingCharacters(in: .whitespaces)
        let value = trimmed.isEmpty ? 0 : max(0, Int(trimmed) ?? viewModel.config.maxShots)
        viewModel.updateConfig { $0.maxShots = value }
        maxShotsText = value > 0 ? "\(value)" : ""
    }

    private func commitFieldOnBlur(_ oldField: FocusField?) {
        switch oldField {
        case .saveFolder:
            viewModel.saveConfig(showToastOnSave: true)
        case .regionX, .regionY, .regionW, .regionH:
            commitRegionDraft()
        case .interval:
            commitIntervalDraft()
        case .maxShots:
            commitMaxShotsDraft()
        case nil:
            break
        }
    }

    // MARK: - Key & Shortcut Recorders

    private func toggleOverlayShortcutRecorder() {
        if isListeningOverlayShortcut {
            stopAnyKeyRecorder()
            return
        }
        stopAnyKeyRecorder()
        isListeningOverlayShortcut = true
        viewModel.setRecordingOverlayShortcut(true)

        recorderMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape cancels recording
                stopAnyKeyRecorder()
                return nil
            }
            guard let shortcut = InputSimulationService.shortcutMetadata(from: event) else {
                return nil
            }
            stopAnyKeyRecorder()
            viewModel.updateOverlayShortcut(shortcut)
            return nil
        }
    }

    private func togglePageTurnKeyRecorder() {
        guard viewModel.config.pageTurn.enabled else { return }
        if isListeningPageTurnKey {
            stopAnyKeyRecorder()
            return
        }
        stopAnyKeyRecorder()
        isListeningPageTurnKey = true

        recorderMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let meta = InputSimulationService.keyMetadata(from: event)
            stopAnyKeyRecorder()
            viewModel.updatePageTurnKey(keyName: meta.keyName, keyCode: meta.keyCode, display: meta.display)
            return nil
        }
    }

    private func stopAnyKeyRecorder() {
        if let monitor = recorderMonitor {
            NSEvent.removeMonitor(monitor)
            recorderMonitor = nil
        }
        if isListeningOverlayShortcut {
            isListeningOverlayShortcut = false
            viewModel.setRecordingOverlayShortcut(false)
        }
        isListeningPageTurnKey = false
    }
}
