import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct IndexingTabView: View {
    @Environment(AppViewModel.self) private var viewModel

    @State private var sidebarWidth: CGFloat = 410
    @State private var isFolderDropTargeted = false
    @State private var isListDropTargeted = false
    @State private var hoveredRowID: String?

    var body: some View {
        let previewPresented = Binding<Bool>(
            get: { viewModel.previewImageIndex != nil },
            set: { if !$0 { viewModel.closePreview() } }
        )

        ResizableHorizontalSplit(
            sidebarWidth: $sidebarWidth,
            minSidebarWidth: 360,
            maxSidebarWidth: 520,
            minDetailWidth: 440
        ) {
            sidebarColumn
        } detail: {
            fileListPanel
        }
        .sheet(isPresented: previewPresented) {
            ImagePreviewSheetView()
                .environment(viewModel)
        }
    }

    // MARK: - Left Sidebar

    private var sidebarColumn: some View {
        VStack(spacing: 14) {
            folderCard
            rangeCard

            if viewModel.config.notesEnabled {
                notesCard
            } else {
                Spacer(minLength: 0)
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private var folderCard: some View {
        @Bindable var vm = viewModel

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    GlassSectionHeader(title: viewModel.t(.folder), systemImage: "folder.fill")
                    Spacer()
                    if isFolderDropTargeted {
                        GlassBadge(
                            text: viewModel.t(.dropFolderActive),
                            tint: .accentColor.opacity(0.28),
                            foreground: .primary
                        )
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField(viewModel.t(.folderPlaceholder), text: $vm.indexingFolder)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .onSubmit {
                            viewModel.scanFolder(showToastOnSuccess: false)
                        }

                    if !viewModel.indexingFolder.isEmpty {
                        Button {
                            viewModel.clearIndexingFolder()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .glassInputSurface(isHighlighted: isFolderDropTargeted)

                HStack(spacing: 10) {
                    GlassPillButton(
                        viewModel.t(.browse),
                        systemImage: "folder.badge.plus",
                        variant: .standard
                    ) {
                        viewModel.browseIndexingFolder()
                    }

                    GlassPillButton(
                        viewModel.t(.refresh),
                        systemImage: "arrow.clockwise",
                        variant: .standard,
                        isLoading: viewModel.isScanning
                    ) {
                        viewModel.refreshIndexingFiles()
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isFolderDropTargeted) { providers in
            handleDroppedProviders(providers)
        }
    }

    private var rangeCard: some View {
        @Bindable var vm = viewModel

        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                GlassSectionHeader(title: viewModel.t(.range), systemImage: "number.square.fill")

                HStack(spacing: 10) {
                    rangeNumericField(label: viewModel.t(.from), text: $vm.rangeStartText)
                    Text("—")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)
                    rangeNumericField(label: viewModel.t(.to), text: $vm.rangeEndText)
                }
                .onChange(of: vm.rangeStartText) { _, _ in
                    viewModel.syncLivePreviewRange()
                }
                .onChange(of: vm.rangeEndText) { _, _ in
                    viewModel.syncLivePreviewRange()
                }

                HStack(spacing: 10) {
                    GlassPillButton(
                        viewModel.t(.preview),
                        systemImage: "eye",
                        variant: .standard,
                        isDisabled: viewModel.files.isEmpty
                    ) {
                        viewModel.previewRename()
                    }

                    GlassPillButton(
                        viewModel.t(.rename),
                        systemImage: "pencil.and.outline",
                        variant: .primary,
                        isLoading: viewModel.isRenaming,
                        isDisabled: viewModel.files.isEmpty
                    ) {
                        viewModel.requestRename()
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func rangeNumericField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("1", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5, weight: .medium, design: .rounded))
                .monospacedDigit()
                .onSubmit {
                    viewModel.previewRename()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassInputSurface()
        }
        .frame(maxWidth: .infinity)
    }

    private var notesCard: some View {
        let notesBinding = Binding<String>(
            get: { viewModel.config.notesText },
            set: { viewModel.updateNotes($0) }
        )

        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    GlassSectionHeader(title: viewModel.t(.notes), systemImage: "note.text")
                    Spacer()
                    if viewModel.config.afmEnabled {
                        GlassPillButton(
                            viewModel.isSummarizingNotes
                                ? viewModel.t(.afmSummarizing)
                                : viewModel.t(.afmSummarize),
                            systemImage: "sparkles",
                            variant: .accentCyan,
                            compact: true,
                            isLoading: viewModel.isSummarizingNotes,
                            isDisabled: viewModel.files.isEmpty
                        ) {
                            viewModel.summarizeAllNotesWithAFM()
                        }
                        .help(viewModel.t(.afmSummarizeTitle))
                    }
                }

                ZStack(alignment: .topLeading) {
                    TextEditor(text: notesBinding)
                        .font(.system(size: 13))
                        .scrollContentBackground(.hidden)
                        .scrollIndicators(.hidden)
                        .padding(8)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .animation(.easeOut(duration: 0.18), value: viewModel.config.notesText)

                    if viewModel.config.notesText.isEmpty {
                        Text(viewModel.t(.notesPlaceholder))
                            .font(.system(size: 13))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 13)
                            .padding(.vertical, 10)
                            .allowsHitTesting(false)
                    }
                }
                .frame(minHeight: 150, maxHeight: .infinity)
                .glassInputSurface(isHighlighted: viewModel.isSummarizingNotes)
                .appleIntelligenceGlowBorder(
                    isActive: viewModel.isSummarizingNotes,
                    cornerRadius: GlassMetrics.inputCornerRadius
                )
            }
        }
        .frame(maxHeight: .infinity)
        .animation(GlassMetrics.springAnimation, value: viewModel.isSummarizingNotes)
    }

    // MARK: - Right Panel: File List

    private var fileListPanel: some View {
        GlassPanel {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    GlassSectionHeader(title: viewModel.t(.fileList), systemImage: "photo.stack")

                    if !viewModel.files.isEmpty {
                        GlassBadge(
                            text: "\(viewModel.files.count)",
                            tint: .accentColor.opacity(0.24),
                            foreground: .primary
                        )
                    }

                    Spacer()

                    if viewModel.indexingStatusIsError, !viewModel.indexingStatusText.isEmpty {
                        GlassBadge(
                            text: viewModel.indexingStatusText,
                            tint: .red.opacity(0.22),
                            foreground: .red
                        )
                    }
                }

                if viewModel.files.isEmpty {
                    emptyStateView
                } else {
                    fileTableContent
                }
            }
        }
        .overlay {
            if isListDropTargeted {
                RoundedRectangle(cornerRadius: GlassMetrics.outerPanelCornerRadius, style: .continuous)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    .padding(2)
                    .allowsHitTesting(false)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isListDropTargeted) { providers in
            handleDroppedProviders(providers)
        }
    }

    private var emptyStateView: some View {
        let isDropActive = isListDropTargeted || isFolderDropTargeted

        return VStack(spacing: 14) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(isDropActive ? 0.18 : 0.09))
                    .frame(width: 72, height: 72)

                Image(systemName: isDropActive ? "folder.badge.plus" : "photo.on.rectangle.angled")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(isDropActive ? Color.accentColor : Color.secondary)
            }

            Text(viewModel.t(.emptyTitle))
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            if isDropActive {
                GlassBadge(
                    text: viewModel.t(.dropFolderActive),
                    tint: .accentColor.opacity(0.24),
                    foreground: .primary
                )
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var fileTableContent: some View {
        VStack(spacing: 8) {
            // Header row
            HStack(spacing: 12) {
                Text("#")
                    .frame(width: 44, alignment: .leading)
                Text(viewModel.t(.originalName))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(viewModel.t(.newName))
                    .frame(width: 150, alignment: .trailing)
            }
            .font(.system(size: 11.5, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(viewModel.files.enumerated()), id: \.element.id) { index, item in
                        fileRow(item: item, index: index)
                    }
                }
                .padding(.bottom, 4)
            }
            .scrollIndicators(.hidden)
            .scrollTopFade(height: 32)
        }
    }

    private func fileRow(item: ScreenshotItem, index: Int) -> some View {
        let isHovered = hoveredRowID == item.id
        let isActivePreview = viewModel.previewImageIndex == index

        return Button {
            viewModel.openPreview(at: index)
        } label: {
            HStack(spacing: 12) {
                Text("\(item.index)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 44, alignment: .leading)

                HStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isActivePreview ? Color.accentColor : Color.secondary)

                    Text(item.name)
                        .font(.system(size: 13, weight: isActivePreview ? .semibold : .regular))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if let newName = item.previewNewName {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                            Text(newName)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                        }
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                    } else {
                        Text("—")
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 150, alignment: .trailing)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassInputSurface(isHighlighted: isHovered || isActivePreview, cornerRadius: 12)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredRowID = hovering ? item.id : (hoveredRowID == item.id ? nil : hoveredRowID)
        }
        .help(viewModel.t(.clickToPreview))
    }

    // MARK: - Shared Drag & Drop Helper

    private func handleDroppedProviders(_ providers: [NSItemProvider]) -> Bool {
        let matching = providers.filter { $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) }
        guard !matching.isEmpty else { return false }

        for provider in matching {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                let resolvedURL: URL?
                if let data = item as? Data {
                    resolvedURL = URL(dataRepresentation: data, relativeTo: nil)
                } else if let url = item as? URL {
                    resolvedURL = url
                } else if let nsURL = item as? NSURL {
                    resolvedURL = nsURL as URL
                } else {
                    resolvedURL = nil
                }

                guard let url = resolvedURL else { return }
                Task { @MainActor in
                    _ = viewModel.handleDroppedURLs([url])
                }
            }
        }
        return true
    }
}
