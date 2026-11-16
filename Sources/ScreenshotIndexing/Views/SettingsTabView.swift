import SwiftUI

struct SettingsTabView: View {
    @Environment(AppViewModel.self) private var viewModel

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: GlassMetrics.containerSpacing) {
                VStack(spacing: 18) {
                    afmEngineCard
                    featureTogglesCard
                    appearanceAndLanguageCard
                }
                .frame(maxWidth: 760)
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.automatic)
    }

    // MARK: - On-Device AI Engine Card

    private var afmEngineCard: some View {
        let isAvailable = viewModel.afmStatus.isAvailable
        let statusText: String = switch viewModel.afmStatus {
        case .available:
            viewModel.t(.afmStatusAvailable)
        case .unavailable(let reason):
            viewModel.t(.afmStatusUnavailable, ["reason": reason])
        }

        return GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionHeader(
                    title: viewModel.t(.settingsAfmSection),
                    systemImage: "cpu"
                )

                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.t(.settingsAfmStatusTitle))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.primary)

                        Text(viewModel.t(.settingsAfmStatusDesc))
                            .font(.system(size: 12.5))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    GlassBadge(
                        text: statusText,
                        tint: isAvailable ? .green.opacity(0.24) : .orange.opacity(0.24),
                        foreground: isAvailable ? .green : .orange
                    )

                    GlassPillButton(
                        viewModel.t(.refresh),
                        systemImage: "arrow.clockwise",
                        variant: .standard,
                        compact: true
                    ) {
                        viewModel.refreshAFMStatus()
                    }
                }
            }
        }
    }

    // MARK: - Feature Toggles Card

    private var featureTogglesCard: some View {
        let afmBinding = Binding<Bool>(
            get: { viewModel.config.afmEnabled },
            set: { val in viewModel.updateConfig { $0.afmEnabled = val } }
        )
        let notesBinding = Binding<Bool>(
            get: { viewModel.config.notesEnabled },
            set: { val in viewModel.updateConfig { $0.notesEnabled = val } }
        )
        let captureBinding = Binding<Bool>(
            get: { viewModel.config.autoCaptureEnabled },
            set: { val in viewModel.updateConfig { $0.autoCaptureEnabled = val } }
        )
        let soundBinding = Binding<Bool>(
            get: { viewModel.config.soundEnabled },
            set: { val in viewModel.updateConfig { $0.soundEnabled = val } }
        )

        return GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionHeader(
                    title: viewModel.t(.settingsFeaturesSection),
                    systemImage: "slider.horizontal.3"
                )

                VStack(spacing: 12) {
                    featureToggleRow(
                        title: viewModel.t(.featAfmTitle),
                        description: viewModel.t(.featAfmDesc),
                        isOn: afmBinding
                    )

                    Divider().opacity(0.45)

                    featureToggleRow(
                        title: viewModel.t(.featNotesTitle),
                        description: viewModel.t(.featNotesDesc),
                        isOn: notesBinding
                    )

                    Divider().opacity(0.45)

                    featureToggleRow(
                        title: viewModel.t(.featCaptureTitle),
                        description: viewModel.t(.featCaptureDesc),
                        isOn: captureBinding
                    )

                    Divider().opacity(0.45)

                    featureToggleRow(
                        title: viewModel.t(.featSoundTitle),
                        description: viewModel.t(.featSoundDesc),
                        isOn: soundBinding
                    )
                }
            }
        }
    }

    private func featureToggleRow(
        title: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(.primary)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Toggle("", isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    // MARK: - Appearance & Language Card

    private var appearanceAndLanguageCard: some View {
        let languageBinding = Binding<AppLanguage>(
            get: { viewModel.config.language },
            set: { viewModel.setLanguage($0) }
        )
        let themeBinding = Binding<AppThemeMode>(
            get: { viewModel.config.themeMode },
            set: { viewModel.setThemeMode($0, showToastMessage: true) }
        )

        return GlassCard(padding: 18) {
            VStack(alignment: .leading, spacing: 14) {
                GlassSectionHeader(
                    title: viewModel.t(.settingsAppearanceSection),
                    systemImage: "paintbrush"
                )

                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Text(viewModel.t(.settingsLanguageLabel))
                            .font(.system(size: 13.5, weight: .semibold))
                        Spacer()
                        Picker("", selection: languageBinding) {
                            Text("EN — \(viewModel.t(.langEn))").tag(AppLanguage.en)
                            Text("VI — \(viewModel.t(.langVi))").tag(AppLanguage.vi)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 260)
                    }

                    Divider().opacity(0.45)

                    HStack(spacing: 16) {
                        Text(viewModel.t(.settingsThemeLabel))
                            .font(.system(size: 13.5, weight: .semibold))
                        Spacer()
                        Picker("", selection: themeBinding) {
                            Text(viewModel.t(.themeSystem)).tag(AppThemeMode.system)
                            Text(viewModel.t(.themeLight)).tag(AppThemeMode.light)
                            Text(viewModel.t(.themeDark)).tag(AppThemeMode.dark)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 260)
                    }
                }
            }
        }
    }
}
