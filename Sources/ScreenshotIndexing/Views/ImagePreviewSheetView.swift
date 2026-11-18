import AppKit
import SwiftUI

// MARK: - Full-Size Image Preview Sheet

struct ImagePreviewSheetView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var loadedImage: NSImage?
    @State private var keyMonitor: Any?

    private var currentIndex: Int {
        guard let idx = viewModel.previewImageIndex, viewModel.files.indices.contains(idx) else {
            return 0
        }
        return idx
    }

    private var currentFile: ScreenshotItem? {
        guard let idx = viewModel.previewImageIndex, viewModel.files.indices.contains(idx) else {
            return nil
        }
        return viewModel.files[idx]
    }

    var body: some View {
        VStack(spacing: 14) {
            headerBar
            imageStage
        }
        .padding(18)
        .frame(minWidth: 820, minHeight: 580)
        .frame(idealWidth: 980, idealHeight: 700)
        .background {
            LiquidGlassBackdrop()
        }
        .preferredColorScheme(viewModel.preferredColorScheme)
        .task(id: currentFile?.url) {
            await loadImageForCurrentFile()
        }
        .onAppear {
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "photo")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(currentFile?.name ?? viewModel.t(.previewImage))
                .font(.system(size: 15, weight: .semibold))
                .lineLimit(1)
                .truncationMode(.middle)

            if !viewModel.files.isEmpty {
                GlassBadge(
                    text: "\(currentIndex + 1) / \(viewModel.files.count)",
                    tint: .accentColor.opacity(0.22),
                    foreground: .primary
                )
            }

            Spacer(minLength: 12)

            if viewModel.config.afmEnabled {
                GlassPillButton(
                    viewModel.isSummarizingSingleImage
                        ? viewModel.t(.afmSummarizing)
                        : viewModel.t(.afmSummarizeOne),
                    systemImage: "sparkles",
                    variant: .accentCyan,
                    compact: true,
                    isLoading: viewModel.isSummarizingSingleImage,
                    isDisabled: currentFile == nil
                ) {
                    viewModel.summarizeCurrentImageWithAFM()
                }
                .help(viewModel.t(.afmSummarizeOneTitle))
            }

            Button {
                viewModel.closePreview()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .capsule)
            .help(viewModel.t(.btnClose))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Stage

    private var imageStage: some View {
        GlassPanel(padding: 14) {
            ZStack {
                if let loadedImage {
                    Image(nsImage: loadedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: .black.opacity(0.22), radius: 18, y: 6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .onTapGesture {
                            if viewModel.showSingleImageSummaryPopover {
                                viewModel.closeSingleImageSummaryPopover()
                            }
                        }
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Navigation controls
                if viewModel.files.count > 1 {
                    HStack {
                        navigationButton(systemImage: "chevron.left", tooltip: viewModel.t(.prevImage)) {
                            viewModel.navigatePreview(by: -1)
                        }

                        Spacer()

                        navigationButton(systemImage: "chevron.right", tooltip: viewModel.t(.nextImage)) {
                            viewModel.navigatePreview(by: 1)
                        }
                    }
                    .padding(.horizontal, 8)
                }

                // Floating Liquid Glass AI Summary Popover
                if viewModel.showSingleImageSummaryPopover {
                    summaryPopoverOverlay
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topTrailing)))
                }
            }
        }
        .animation(GlassMetrics.springAnimation, value: viewModel.showSingleImageSummaryPopover)
    }

    private func navigationButton(systemImage: String, tooltip: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
        .help(tooltip)
    }

    private var summaryPopoverOverlay: some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)

        return VStack {
            HStack {
                Spacer()
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.cyan)
                        Text(viewModel.t(.aiSummaryTitle))
                            .font(.system(size: 13.5, weight: .semibold))

                        Spacer()

                        GlassPillButton(
                            viewModel.t(.btnCopy),
                            systemImage: "doc.on.doc",
                            variant: .standard,
                            compact: true,
                            isDisabled: viewModel.singleImageSummaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ) {
                            viewModel.copySingleImageSummary()
                        }

                        Button {
                            viewModel.closeSingleImageSummaryPopover()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 24, height: 24)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular.interactive(), in: .capsule)
                        .help(viewModel.t(.btnClose))
                    }

                    ScrollView {
                        Text(
                            viewModel.singleImageSummaryText.isEmpty && viewModel.isSummarizingSingleImage
                                ? " "
                                : viewModel.singleImageSummaryText
                        )
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .contentTransition(.interpolate)
                        .animation(.easeOut(duration: 0.18), value: viewModel.singleImageSummaryText)
                    }
                    .scrollIndicators(.hidden)
                    .scrollTopFade(height: 24)
                    .frame(maxHeight: 280)
                }
                .animation(GlassMetrics.springAnimation, value: viewModel.isSummarizingSingleImage)
                .padding(14)
                .frame(width: 380)
                .background {
                    ZStack {
                        shape.fill(.ultraThickMaterial)
                        shape.fill(
                            colorScheme == .dark
                                ? Color(red: 0.07, green: 0.075, blue: 0.09).opacity(0.92)
                                : Color(red: 0.97, green: 0.975, blue: 0.985).opacity(0.94)
                        )
                    }
                }
                .overlay {
                    shape.strokeBorder(
                        Color.white.opacity(colorScheme == .dark ? 0.18 : 0.75),
                        lineWidth: 1
                    )
                }
                .appleIntelligenceGlowBorder(
                    isActive: viewModel.isSummarizingSingleImage,
                    cornerRadius: 18
                )
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.55 : 0.22),
                    radius: 24,
                    y: 10
                )
            }
            Spacer()
        }
        .padding(12)
    }

    // MARK: - Image Loading & Keyboard Monitoring

    private func loadImageForCurrentFile() async {
        guard let url = currentFile?.url else {
            loadedImage = nil
            return
        }
        let img = await Task.detached(priority: .userInitiated) {
            if let data = try? Data(contentsOf: url) {
                return NSImage(data: data)
            }
            return NSImage(contentsOf: url)
        }.value

        if !Task.isCancelled {
            loadedImage = img
        }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let noNavModifiers = event.modifierFlags.intersection([.command, .option, .control]).isEmpty
            switch event.keyCode {
            case 123, 126: // Left Arrow, Up Arrow
                guard noNavModifiers else { return event }
                viewModel.navigatePreview(by: -1)
                return nil
            case 124, 125: // Right Arrow, Down Arrow
                guard noNavModifiers else { return event }
                viewModel.navigatePreview(by: 1)
                return nil
            case 53: // Escape
                if viewModel.showSingleImageSummaryPopover {
                    viewModel.closeSingleImageSummaryPopover()
                } else {
                    viewModel.closePreview()
                }
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }
}

// MARK: - Rename Confirmation Modal

struct ConfirmRenameSheetView: View {
    @Environment(AppViewModel.self) private var viewModel
    @Environment(\.colorScheme) private var colorScheme

    @State private var keyMonitor: Any?

    private var count: Int {
        viewModel.pendingRenameRange?.count ?? 0
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        let previewShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        VStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.18))
                        .frame(width: 38, height: 38)
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.t(.confirmRename))
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(viewModel.t(.confirmRenameCount, ["count": "\(count)"]))
                        .font(.system(size: 12.5))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    viewModel.cancelRename()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 26, height: 26)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)
                .help(viewModel.t(.btnClose))
            }

            VStack(spacing: 10) {
                renamePreviewRow(
                    label: viewModel.t(.firstFile),
                    oldName: viewModel.pendingFirstOld,
                    newName: viewModel.pendingFirstNew
                )

                Divider()
                    .opacity(colorScheme == .dark ? 0.35 : 0.55)

                renamePreviewRow(
                    label: viewModel.t(.lastFile),
                    oldName: viewModel.pendingLastOld,
                    newName: viewModel.pendingLastNew
                )
            }
            .padding(14)
            .background {
                previewShape.fill(
                    colorScheme == .dark
                        ? Color.white.opacity(0.055)
                        : Color.black.opacity(0.035)
                )
            }
            .overlay {
                previewShape.strokeBorder(
                    colorScheme == .dark
                        ? Color.white.opacity(0.10)
                        : Color.black.opacity(0.08),
                    lineWidth: 1
                )
            }

            HStack(spacing: 10) {
                Spacer()

                GlassPillButton(
                    viewModel.t(.cancelBtn),
                    variant: .standard
                ) {
                    viewModel.cancelRename()
                }

                GlassPillButton(
                    viewModel.t(.agreeRename),
                    systemImage: "checkmark",
                    variant: .primary
                ) {
                    viewModel.executeRename()
                }
            }
        }
        .padding(20)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .background {
            ZStack {
                shape.fill(.ultraThickMaterial)
                shape.fill(
                    colorScheme == .dark
                        ? Color(red: 0.08, green: 0.085, blue: 0.10).opacity(0.95)
                        : Color(red: 0.97, green: 0.975, blue: 0.985).opacity(0.96)
                )
            }
            .contentShape(shape)
            .onTapGesture {}
        }
        .overlay {
            shape.strokeBorder(
                Color.white.opacity(colorScheme == .dark ? 0.18 : 0.75),
                lineWidth: 1
            )
        }
        .shadow(
            color: .black.opacity(colorScheme == .dark ? 0.55 : 0.22),
            radius: 26,
            y: 12
        )
        .onAppear {
            installKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch event.keyCode {
            case 53: // Escape
                viewModel.cancelRename()
                return nil
            case 36, 76: // Return, Numpad Enter
                guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
                      !viewModel.isRenaming else {
                    return event
                }
                viewModel.executeRename()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func renamePreviewRow(label: String, oldName: String, newName: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Text(oldName)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                    .layoutPriority(1)

                Text(newName)
                    .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                    .layoutPriority(1)

                Spacer(minLength: 0)
            }
        }
    }
}
