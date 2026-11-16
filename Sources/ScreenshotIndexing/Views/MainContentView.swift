import AppKit
import SwiftUI

struct MainContentView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Namespace private var tabNamespace
    @Namespace private var langNamespace

    var body: some View {
        ZStack {
            LiquidGlassBackdrop()

            VStack(spacing: 14) {
                floatingToolbar
                    .padding(.top, 10)
                    .padding(.horizontal, 16)

                tabContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }

            ToastOverlayView(
                toast: viewModel.toast,
                onDismiss: { viewModel.dismissToast() }
            )
        }
        .onChange(of: viewModel.captureController.status) { oldValue, newValue in
            viewModel.handleCaptureStatusChange(oldValue: oldValue, newValue: newValue)
        }
    }

    // MARK: - Top Floating Liquid Glass Toolbar

    private var floatingToolbar: some View {
        ZStack {
            WindowDragRegion()
                .frame(height: 44)

            HStack(spacing: 12) {
                // Leading clearance for macOS traffic lights under .hiddenTitleBar
                Spacer()
                    .frame(width: 66)

                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        tabPillSwitcher

                        GlassBadge(
                            text: "v\(viewModel.appVersionString)",
                            foreground: .secondary
                        )
                    }
                }

                Spacer(minLength: 16)

                GlassEffectContainer(spacing: 10) {
                    HStack(spacing: 10) {
                        languageSegmentedPill
                        themeToggleButton
                    }
                }
            }
            .frame(height: 44)
        }
    }

    private var tabPillSwitcher: some View {
        HStack(spacing: 4) {
            ForEach(viewModel.visibleTabs) { tab in
                let isSelected = viewModel.activeTab == tab
                Button {
                    viewModel.selectTab(tab)
                } label: {
                    HStack(spacing: 6) {
                        if tab == .capture {
                            PulsingStatusDot(state: viewModel.captureHeaderDotState, size: 6.5)
                        } else {
                            Image(systemName: tab.systemImage)
                                .font(.system(size: 12, weight: .semibold))
                        }

                        Text(viewModel.tabTitle(tab))
                            .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.clear)
                            .glassEffect(
                                .regular.tint(.accentColor.opacity(0.24)).interactive(),
                                in: .capsule
                            )
                            .glassEffectID("activeTabIndicator", in: tabNamespace)
                    }
                }
            }
        }
        .padding(4)
        .background {
            Capsule()
                .fill(Color.primary.opacity(0.055))
                .overlay {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
    }

    private var languageSegmentedPill: some View {
        HStack(spacing: 2) {
            Image(systemName: "globe")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
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
                        .font(.system(size: 11.5, weight: isSelected ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isSelected ? .primary : .secondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.clear)
                            .glassEffect(.regular.interactive(), in: .capsule)
                            .glassEffectID("activeLangIndicator", in: langNamespace)
                    }
                }
            }
        }
        .padding(3)
        .background {
            Capsule()
                .fill(Color.primary.opacity(0.055))
                .overlay {
                    Capsule()
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                }
        }
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
            HStack(spacing: 5) {
                Image(systemName: iconName)
                    .font(.system(size: 13, weight: .semibold))
                Text(labelText)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .help(viewModel.t(.themeToggle))
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
    func makeNSView(context: Context) -> NSView {
        DraggableHeaderView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DraggableHeaderView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
    }
}
