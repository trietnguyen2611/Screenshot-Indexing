import AppKit
import SwiftUI

struct MainContentView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var tabNamespace
    @Namespace private var langNamespace
    @State private var isTabBarHovered = false
    @State private var isRightControlsHovered = false
    @State private var trafficLightsCenterY: CGFloat = 14
    @State private var trafficLightsTrailingX: CGFloat = 68

    private let compactBarHeight: CGFloat = 23

    private var toolbarTopPadding: CGFloat {
        max(5, trafficLightsCenterY - compactBarHeight / 2)
    }

    var body: some View {
        ZStack {
            LiquidGlassBackdrop()

            VStack(spacing: 14) {
                floatingToolbar
                    .frame(height: compactBarHeight, alignment: .top)
                    .padding(.top, toolbarTopPadding)
                    .padding(.horizontal, 16)
                    .zIndex(20)

                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .ignoresSafeArea(.container, edges: .top)

            ToastOverlayView(
                toast: viewModel.toast,
                topPadding: toolbarTopPadding,
                onDismiss: { viewModel.dismissToast() }
            )
            .zIndex(40)

            if viewModel.showConfirmRenameSheet {
                Color.black.opacity(0.45)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.cancelRename()
                    }
                    .transition(.opacity)
                    .zIndex(30)

                ConfirmRenameSheetView()
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
                    .zIndex(31)
            }
        }
        .animation(GlassMetrics.springAnimation, value: viewModel.showConfirmRenameSheet)
        .onChange(of: viewModel.captureController.status) { oldValue, newValue in
            viewModel.handleCaptureStatusChange(oldValue: oldValue, newValue: newValue)
        }
    }

    // MARK: - Top Floating Liquid Glass Toolbar

    private var floatingToolbar: some View {
        ZStack(alignment: .top) {
            WindowDragRegion(
                trafficLightsCenterY: $trafficLightsCenterY,
                trafficLightsTrailingX: $trafficLightsTrailingX
            )
            .frame(height: compactBarHeight)

            HStack(alignment: .top, spacing: 0) {
                // Keep tabPillSwitcher 10pt to the right of the green zoom button
                Spacer()
                    .frame(width: max(52, trafficLightsTrailingX + 10 - 16))

                tabPillSwitcher
                    .frame(height: compactBarHeight, alignment: .topLeading)

                Spacer(minLength: 16)

                HStack(spacing: 6) {
                    languageSegmentedPill
                    themeToggleButton
                }
                .scaleEffect(isRightControlsHovered ? 1.18 : 1.0, anchor: .topTrailing)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                        isRightControlsHovered = hovering
                    }
                }
                .frame(height: compactBarHeight, alignment: .topTrailing)
            }
            .frame(height: compactBarHeight, alignment: .top)
        }
    }

    private var selectedPillLensBackground: some View {
        ZStack {
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.24 : 0.92),
                            Color.white.opacity(colorScheme == .dark ? 0.11 : 0.75),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.28 : 0.65),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.55 : 0.95),
                            Color.white.opacity(0.12),
                            Color.white.opacity(colorScheme == .dark ? 0.28 : 0.5),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.0
                )
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.42 : 0.10), radius: 5, y: 2)
        .allowsHitTesting(false)
    }

    private func pillForegroundColor(isSelected: Bool) -> Color {
        if colorScheme == .dark {
            return isSelected ? .white : .white.opacity(0.66)
        }
        return isSelected ? .primary : .secondary
    }

    private var tabPillSwitcher: some View {
        HStack(spacing: isTabBarHovered ? 6 : 2) {
            ForEach(viewModel.visibleTabs) { tab in
                let isSelected = viewModel.activeTab == tab
                Button {
                    viewModel.selectTab(tab)
                } label: {
                    HStack(spacing: isTabBarHovered ? 7.5 : 5) {
                        if tab == .capture {
                            PulsingStatusDot(
                                state: viewModel.captureHeaderDotState,
                                size: isTabBarHovered ? 7.5 : 5
                            )
                        } else {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: isTabBarHovered ? 13.5 : 10, weight: .semibold))
                        }

                        Text(viewModel.tabTitle(tab))
                            .font(.system(size: isTabBarHovered ? 14.5 : 11, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(pillForegroundColor(isSelected: isSelected))
                    .padding(.horizontal, isTabBarHovered ? 18 : 9)
                    .padding(.vertical, isTabBarHovered ? 9 : 3)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background {
                    if isSelected {
                        selectedPillLensBackground
                            .matchedGeometryEffect(id: "activeTabIndicator", in: tabNamespace)
                    }
                }
            }
        }
        .padding(isTabBarHovered ? 5 : 2.5)
        .glassEffect(.regular, in: .capsule)
        .scaleEffect(isTabBarHovered ? 1.12 : 1.0, anchor: .topLeading)
        .onHover { hovering in
            withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) {
                isTabBarHovered = hovering
            }
        }
        .animation(GlassMetrics.springAnimation, value: viewModel.activeTab)
    }

    private var languageSegmentedPill: some View {
        HStack(spacing: 2) {
            Image(systemName: "globe")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(pillForegroundColor(isSelected: false))
                .padding(.leading, 8)
                .padding(.trailing, 2)

            ForEach(AppLanguage.allCases, id: \.self) { lang in
                let isSelected = viewModel.config.language == lang
                Button {
                    withAnimation(GlassMetrics.springAnimation) {
                        viewModel.setLanguage(lang)
                    }
                } label: {
                    Text(lang.shortLabel)
                        .font(.system(size: 11, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(pillForegroundColor(isSelected: isSelected))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background {
                    if isSelected {
                        selectedPillLensBackground
                            .matchedGeometryEffect(id: "activeLangIndicator", in: langNamespace)
                    }
                }
            }
        }
        .padding(2.5)
        .glassEffect(.regular, in: .capsule)
        .animation(GlassMetrics.springAnimation, value: viewModel.config.language)
        .accessibilityLabel(viewModel.t(.settingsLanguageLabel))
    }

    private var themeToggleButton: some View {
        let iconName: String = switch viewModel.config.themeMode {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max.fill"
        case .dark: "moon.stars.fill"
        }

        let labelText: String = switch viewModel.config.themeMode {
        case .system: viewModel.t(.themeSystem)
        case .light: viewModel.t(.themeLight)
        case .dark: viewModel.t(.themeDark)
        }

        return Button {
            viewModel.cycleThemeMode()
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 23, height: 23)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .help("\(viewModel.t(.themeToggle)) (\(labelText))")
        .accessibilityLabel("\(viewModel.t(.themeToggle)): \(labelText)")
    }

    // MARK: - Tab Router

    @ViewBuilder
    private var tabContent: some View {
        ZStack {
            switch viewModel.activeTab {
            case .indexing:
                IndexingTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.992)))
            case .capture:
                AutoCaptureTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.992)))
            case .settings:
                SettingsTabView()
                    .transition(.opacity.combined(with: .scale(scale: 0.992)))
            }
        }
        .animation(GlassMetrics.springAnimation, value: viewModel.activeTab)
    }
}

// MARK: - Native Window Drag Support

private struct WindowDragRegion: NSViewRepresentable {
    @Binding var trafficLightsCenterY: CGFloat
    @Binding var trafficLightsTrailingX: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> DraggableHeaderView {
        let view = DraggableHeaderView()
        view.onTrafficLightsLayout = { centerY, trailingX in
            context.coordinator.updateTrafficLightMetrics(centerY: centerY, trailingX: trailingX)
        }
        return view
    }

    func updateNSView(_ nsView: DraggableHeaderView, context: Context) {
        context.coordinator.parent = self
        nsView.onTrafficLightsLayout = { centerY, trailingX in
            context.coordinator.updateTrafficLightMetrics(centerY: centerY, trailingX: trailingX)
        }
    }

    @MainActor
    final class Coordinator {
        var parent: WindowDragRegion

        init(parent: WindowDragRegion) {
            self.parent = parent
        }

        func updateTrafficLightMetrics(centerY: CGFloat, trailingX: CGFloat) {
            let currentY = parent.trafficLightsCenterY
            let currentX = parent.trafficLightsTrailingX
            guard abs(centerY - currentY) > 0.5 || abs(trailingX - currentX) > 0.5 else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if abs(centerY - self.parent.trafficLightsCenterY) > 0.5 {
                    self.parent.trafficLightsCenterY = centerY
                }
                if abs(trailingX - self.parent.trafficLightsTrailingX) > 0.5 {
                    self.parent.trafficLightsTrailingX = trailingX
                }
            }
        }
    }

    final class DraggableHeaderView: NSView {
        var onTrafficLightsLayout: ((CGFloat, CGFloat) -> Void)?

        override var mouseDownCanMoveWindow: Bool { true }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let window else { return }
            window.titlebarAppearsTransparent = true
            if !window.styleMask.contains(.fullSizeContentView) {
                window.styleMask.insert(.fullSizeContentView)
            }
            DispatchQueue.main.async { [weak self] in
                self?.measureTrafficLights()
            }
        }

        override func layout() {
            super.layout()
            measureTrafficLights()
        }

        private func measureTrafficLights() {
            guard let window,
                  window.contentView != nil,
                  window.frame.height > 0,
                  let zoomButton = window.standardWindowButton(.zoomButton),
                  zoomButton.window === window,
                  !zoomButton.isHidden,
                  !zoomButton.bounds.isEmpty else {
                return
            }

            let winRect = zoomButton.convert(zoomButton.bounds, to: nil)
            let centerYFromTop = max(10, min(28, window.frame.height - winRect.midY))
            let trailingX = max(54, min(90, winRect.maxX))
            onTrafficLightsLayout?(centerYFromTop, trailingX)
        }
    }
}
