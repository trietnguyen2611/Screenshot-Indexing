import Foundation

public enum AppLanguage: String, Codable, CaseIterable, Sendable {
    case en = "en"
    case vi = "vi"

    public var shortLabel: String {
        switch self {
        case .en: return "EN"
        case .vi: return "VI"
        }
    }

    public var displayName: String {
        switch self {
        case .en: return "English"
        case .vi: return "Tiếng Việt"
        }
    }
}

public enum L10nKey: String, CaseIterable, Sendable {
    // App / Tabs / Header
    case appTitle = "app_title"
    case desc
    case tabIndexing = "tab_indexing"
    case tabAutoCapture = "tab_auto_capture"
    case tabSettings = "tab_settings"
    case resizerTitle = "resizer_title"
    case themeToggle = "theme_toggle"

    // Folder & Indexing
    case folder
    case folderPlaceholder = "folder_placeholder"
    case browse
    case refresh
    case range
    case from
    case to
    case preview
    case rename
    case notes
    case notesPlaceholder = "notes_placeholder"
    case fileList = "file_list"
    case originalName = "original_name"
    case newName = "new_name"
    case emptyTitle = "empty_title"
    case emptyDesc = "empty_desc"
    case dropFolderHint = "drop_folder_hint"
    case dropFolderActive = "drop_folder_active"

    // Folder Modal & Confirm Modal
    case modalSelectFolder = "modal_select_folder"
    case modalNoSubfolder = "modal_no_subfolder"
    case back
    case cancel
    case selectThisFolder = "select_this_folder"
    case confirmRename = "confirm_rename"
    case confirmMessage = "confirm_message"
    case confirmRenameCount = "confirm_rename_count"
    case firstFile = "first_file"
    case lastFile = "last_file"
    case cancelBtn = "cancel_btn"
    case agreeRename = "agree_rename"
    case btnRename = "btn_rename"
    case btnRenaming = "btn_renaming"

    // Image Preview
    case previewImage = "preview_image"
    case prevImage = "prev_image"
    case nextImage = "next_image"
    case clickToPreview = "click_to_preview"
    case aiSummaryTitle = "ai_summary_title"
    case btnCopy = "btn_copy"
    case btnClose = "btn_close"

    // Auto Capture UI
    case captureSaveFolder = "capture_save_folder"
    case captureFolderPlaceholder = "capture_folder_placeholder"
    case captureRegion = "capture_region"
    case btnTestShotNow = "btn_test_shot_now"
    case btnTestShot2s = "btn_test_shot_2s"
    case btnPickRegionOverlay = "btn_pick_region_overlay"
    case captureTimerSound = "capture_timer_sound"
    case captureInterval = "capture_interval"
    case captureMaxShots = "capture_max_shots"
    case captureMaxShotsPlaceholder = "capture_max_shots_placeholder"
    case captureCountdown = "capture_countdown"
    case captureSoundLabel = "capture_sound_label"
    case pageTurnTitle = "page_turn_title"
    case pageTurnEnable = "page_turn_enable"
    case ptKeyRecorderLabel = "pt_key_recorder_label"
    case ptKeyRecorderPlaceholder = "pt_key_recorder_placeholder"
    case ptKeyRecorderTitle = "pt_key_recorder_title"
    case ptKeyListening = "pt_key_listening"
    case overlayShortcutLabel = "overlay_shortcut_label"
    case overlayShortcutPlaceholder = "overlay_shortcut_placeholder"
    case overlayShortcutTitle = "overlay_shortcut_title"
    case overlayShortcutListening = "overlay_shortcut_listening"
    case captureControls = "capture_controls"
    case btnCaptureStart = "btn_capture_start"
    case btnCaptureStop = "btn_capture_stop"
    case phaseIdle = "phase_idle"
    case phaseCountdown = "phase_countdown"
    case phaseCapturing = "phase_capturing"
    case phaseCompleted = "phase_completed"
    case phaseStopped = "phase_stopped"
    case phaseError = "phase_error"

    // Permissions & Preview Canvas
    case permScreenRecording = "perm_screen_recording"
    case permAccessibility = "perm_accessibility"
    case permGranted = "perm_granted"
    case permMissing = "perm_missing"
    case permUnknown = "perm_unknown"
    case btnCheckPermissions = "btn_check_permissions"
    case btnOpenSettings = "btn_open_settings"
    case viewCanvas = "view_canvas"
    case canvasEmptyTitle = "canvas_empty_title"
    case canvasEmptyDesc = "canvas_empty_desc"
    case canvasDragHint = "canvas_drag_hint"
    case canvasCoordSummary = "canvas_coord_summary"
    case canvasPermRequired = "canvas_perm_required"
    case btnOpenScreenPerm = "btn_open_screen_perm"
    case overlayPickerHint = "overlay_picker_hint"
    case overlayPickerClickHint = "overlay_picker_click_hint"

    // AFM & Settings
    case afmSummarize = "afm_summarize"
    case afmSummarizing = "afm_summarizing"
    case afmSummarizeTitle = "afm_summarize_title"
    case afmSummarizeOne = "afm_summarize_one"
    case afmSummarizeOneTitle = "afm_summarize_one_title"
    case settingsAfmSection = "settings_afm_section"
    case settingsAfmStatusTitle = "settings_afm_status_title"
    case settingsAfmStatusDesc = "settings_afm_status_desc"
    case afmStatusChecking = "afm_status_checking"
    case afmStatusAvailable = "afm_status_available"
    case afmStatusUnavailable = "afm_status_unavailable"
    case settingsFeaturesSection = "settings_features_section"
    case featAfmTitle = "feat_afm_title"
    case featAfmDesc = "feat_afm_desc"
    case featNotesTitle = "feat_notes_title"
    case featNotesDesc = "feat_notes_desc"
    case featCaptureTitle = "feat_capture_title"
    case featCaptureDesc = "feat_capture_desc"
    case featSoundTitle = "feat_sound_title"
    case featSoundDesc = "feat_sound_desc"
    case settingsAppearanceSection = "settings_appearance_section"
    case settingsLanguageLabel = "settings_language_label"
    case settingsThemeLabel = "settings_theme_label"
    case themeDark = "theme_dark"
    case themeLight = "theme_light"
    case themeSystem = "theme_system"
    case langEn = "lang_en"
    case langVi = "lang_vi"

    // Statuses, Toasts & Errors (merged app.py + app.js)
    case pathNotExist = "path_not_exist"
    case noPermission = "no_permission"
    case folderNotExist = "folder_not_exist"
    case noFiles = "no_files"
    case errorPrefix = "error_prefix"
    case renameSuccess = "rename_success"
    case settingsSaved = "settings_saved"
    case settingsSaveFailed = "settings_save_failed"
    case captureFolderRequired = "capture_folder_required"
    case captureInvalidRegion = "capture_invalid_region"
    case captureStarted = "capture_started"
    case captureAlreadyRunning = "capture_already_running"
    case captureStartFailed = "capture_start_failed"
    case captureStopped = "capture_stopped"
    case previewFailed = "preview_failed"
    case overlayCancelled = "overlay_cancelled"
    case overlayFailed = "overlay_failed"
    case permissionDeniedCapture = "permission_denied_capture"
    case accessibilityWarning = "accessibility_warning"
    case fileNotFound = "file_not_found"
    case afmSummarizeSuccess = "afm_summarize_success"
    case afmUnavailable = "afm_unavailable"
    case afmFailed = "afm_failed"

    case toastEnterFolder = "toast_enter_folder"
    case toastNoSubfolder = "toast_no_subfolder"
    case toastErrorBrowse = "toast_error_browse"
    case toastNoFolderSelected = "toast_no_folder_selected"
    case statusScanning = "status_scanning"
    case statusFileCount = "status_file_count"
    case toastScanError = "toast_scan_error"
    case statusConnError = "status_conn_error"
    case toastRefresh = "toast_refresh"
    case toastNoPreview = "toast_no_preview"
    case toastInvalidNum = "toast_invalid_num"
    case toastStartGtEnd = "toast_start_gt_end"
    case statusPreview = "status_preview"
    case toastNoRename = "toast_no_rename"
    case toastRenameError = "toast_rename_error"
    case toastThemeChange = "toast_theme_change"
    case toastSettingsSaved = "toast_settings_saved"
    case toastSettingsError = "toast_settings_error"
    case toastPreviewDelay = "toast_preview_delay"
    case toastPreviewReady = "toast_preview_ready"
    case toastPreviewFailed = "toast_preview_failed"
    case toastOverlayRegionSet = "toast_overlay_region_set"
    case toastOverlayCancelled = "toast_overlay_cancelled"
    case toastOverlayError = "toast_overlay_error"
    case toastCaptureFolderRequired = "toast_capture_folder_required"
    case toastCaptureInvalidRegion = "toast_capture_invalid_region"
    case toastCaptureStarted = "toast_capture_started"
    case toastCaptureStopped = "toast_capture_stopped"
    case toastCaptureCompleted = "toast_capture_completed"
    case toastCaptureError = "toast_capture_error"
    case toastPermissionsUpdated = "toast_permissions_updated"
    case toastPermissionsError = "toast_permissions_error"
    case toastAccessibilityNeeded = "toast_accessibility_needed"
    case toastKeyRecorded = "toast_key_recorded"
    case toastRegionUpdated = "toast_region_updated"
    case toastAfmNoFiles = "toast_afm_no_files"
    case toastAfmError = "toast_afm_error"
    case toastOverlayShortcutSet = "toast_overlay_shortcut_set"
    case toastOpenPermSettings = "toast_open_perm_settings"
    case toastCopied = "toast_copied"
    case toastScreenPermRequired = "toast_screen_perm_required"
}

public enum L10n {
    public static func t(_ key: L10nKey, _ lang: AppLanguage, _ args: [String: String] = [:]) -> String {
        let pair = localizedPair(for: key)
        var template = lang == .vi ? pair.vi : pair.en
        if !args.isEmpty {
            for (placeholder, value) in args {
                template = template.replacingOccurrences(of: "{\(placeholder)}", with: value)
            }
        }
        return template
    }

    private static func localizedPair(for key: L10nKey) -> (en: String, vi: String) {
        switch key {
        case .appTitle:
            return ("Screenshot Indexing", "Screenshot Indexing")
        case .desc:
            return ("Batch rename screenshot files chronologically", "Đổi tên đồng loạt file screenshot theo thứ tự thời gian")
        case .tabIndexing:
            return ("Screenshot Indexing", "Screenshot Indexing")
        case .tabAutoCapture:
            return ("Auto Capture", "Chụp tự động")
        case .tabSettings:
            return ("Settings", "Cài đặt")
        case .resizerTitle:
            return ("Drag to resize", "Kéo để điều chỉnh kích thước")
        case .themeToggle:
            return ("Toggle Light / Dark theme", "Đổi chế độ Sáng / Tối")

        case .folder:
            return ("Folder", "Thư mục")
        case .folderPlaceholder:
            return ("Enter folder path...", "Nhập đường dẫn thư mục...")
        case .browse:
            return ("Browse", "Duyệt")
        case .refresh:
            return ("Refresh", "Làm mới")
        case .range:
            return ("Numbering Range", "Phạm vi đánh số")
        case .from:
            return ("From", "Từ")
        case .to:
            return ("To", "Đến")
        case .preview:
            return ("Preview", "Xem trước")
        case .rename:
            return ("Rename", "Đổi tên")
        case .notes:
            return ("Notes", "Ghi chú")
        case .notesPlaceholder:
            return ("Enter notes here...", "Nhập ghi chú tại đây...")
        case .fileList:
            return ("Screenshot File List", "Danh sách file screenshot")
        case .originalName:
            return ("Original Name", "Tên gốc")
        case .newName:
            return ("New Name", "Tên mới")
        case .emptyTitle:
            return ("No files yet", "Chưa có file nào")
        case .emptyDesc:
            return ("Select a folder containing screenshot files to start", "Chọn thư mục chứa các file screenshot để bắt đầu")
        case .dropFolderHint:
            return ("Drop a folder here to scan screenshots", "Thả thư mục vào đây để quét ảnh screenshot")
        case .dropFolderActive:
            return ("Release to open folder", "Thả ra để mở thư mục")

        case .modalSelectFolder:
            return ("Select Folder", "Chọn thư mục")
        case .modalNoSubfolder:
            return ("No subfolders", "Không có thư mục con")
        case .back:
            return ("Back", "Trở về")
        case .cancel:
            return ("Cancel", "Huỷ")
        case .selectThisFolder:
            return ("Select this folder", "Chọn thư mục này")
        case .confirmRename:
            return ("Confirm Rename", "Xác nhận đổi tên")
        case .confirmMessage:
            return ("Are you sure you want to rename?", "Bạn có chắc chắn muốn đổi tên?")
        case .confirmRenameCount:
            return ("Are you sure you want to rename {count} files?", "Bạn có chắc chắn muốn đổi tên {count} file?")
        case .firstFile:
            return ("First file:", "File đầu tiên:")
        case .lastFile:
            return ("Last file:", "File cuối cùng:")
        case .cancelBtn:
            return ("Cancel", "Huỷ bỏ")
        case .agreeRename:
            return ("Confirm Rename", "Đồng ý đổi tên")
        case .btnRename:
            return ("Rename", "Đổi tên")
        case .btnRenaming:
            return ("Renaming...", "Đang đổi tên...")

        case .previewImage:
            return ("Preview Image", "Xem trước ảnh")
        case .prevImage:
            return ("Previous Image (Left Arrow / Up)", "Ảnh trước (Mũi tên Trái / Up)")
        case .nextImage:
            return ("Next Image (Right Arrow / Down)", "Ảnh tiếp theo (Mũi tên Phải / Down)")
        case .clickToPreview:
            return ("Click to preview image", "Click để xem trước ảnh")
        case .aiSummaryTitle:
            return ("AI Summary", "Tóm tắt AI")
        case .btnCopy:
            return ("Copy", "Sao chép")
        case .btnClose:
            return ("Close", "Đóng")

        case .captureSaveFolder:
            return ("Save Folder", "Thư mục lưu ảnh")
        case .captureFolderPlaceholder:
            return ("Enter save folder path...", "Nhập đường dẫn lưu ảnh chụp...")
        case .captureRegion:
            return ("Capture Region", "Vùng chụp cố định")
        case .btnTestShotNow:
            return ("Test Shot Now", "Chụp thử ngay")
        case .btnTestShot2s:
            return ("Test Shot in 2s", "Chụp thử sau 2s")
        case .btnPickRegionOverlay:
            return ("Screen Overlay Picker", "Chọn vùng trên màn hình")
        case .captureTimerSound:
            return ("Timer & Shutter", "Hẹn giờ & Âm thanh")
        case .captureInterval:
            return ("Interval (1–10s)", "Chu kỳ chụp (1–10s)")
        case .captureMaxShots:
            return ("Shot Limit", "Giới hạn số ảnh")
        case .captureMaxShotsPlaceholder:
            return ("0 = ∞", "0 = ∞")
        case .captureCountdown:
            return ("Countdown (0–10s)", "Đếm ngược (0–10s)")
        case .captureSoundLabel:
            return ("macOS Shutter Sound", "Âm thanh chụp macOS")
        case .pageTurnTitle:
            return ("Auto Page-Turn", "Tự động lật trang")
        case .pageTurnEnable:
            return ("Enable auto page-turn", "Bật tự động lật trang")
        case .ptKeyRecorderLabel:
            return ("Sample Key (click & press any key)", "Phím mẫu (click & nhấn phím bất kỳ)")
        case .ptKeyRecorderPlaceholder:
            return ("Click & press key...", "Click & nhấn phím...")
        case .ptKeyRecorderTitle:
            return ("Click here and press any key to record", "Click vào đây và nhấn phím bất kỳ để ghi")
        case .ptKeyListening:
            return ("Press any key...", "Đang chờ nhấn phím...")
        case .overlayShortcutLabel:
            return ("Region Picker Shortcut (click & press)", "Phím tắt chọn vùng (nhấn để đặt)")
        case .overlayShortcutPlaceholder:
            return ("Click & press shortcut...", "Nhấn vào đây và bấm tổ hợp phím...")
        case .overlayShortcutTitle:
            return ("Click here and press a key combination to trigger region picker", "Nhấn vào đây và bấm tổ hợp phím để mở chọn vùng màn hình")
        case .overlayShortcutListening:
            return ("Press shortcut...", "Hãy bấm tổ hợp phím...")
        case .captureControls:
            return ("Capture Control", "Điều khiển chụp")
        case .btnCaptureStart:
            return ("Start Capture", "Bắt đầu chụp")
        case .btnCaptureStop:
            return ("Stop", "Dừng")
        case .phaseIdle:
            return ("Ready", "Sẵn sàng")
        case .phaseCountdown:
            return ("Starting in {sec}s...", "Bắt đầu sau {sec}s...")
        case .phaseCapturing:
            return ("Capturing...", "Đang chụp...")
        case .phaseCompleted:
            return ("Completed", "Hoàn thành")
        case .phaseStopped:
            return ("Stopped", "Đã dừng")
        case .phaseError:
            return ("Error", "Lỗi")

        case .permScreenRecording:
            return ("Screen Recording", "Ghi màn hình")
        case .permAccessibility:
            return ("Accessibility", "Trợ năng (Accessibility)")
        case .permGranted:
            return ("Granted", "Đã cấp")
        case .permMissing:
            return ("Not Granted", "Chưa cấp")
        case .permUnknown:
            return ("Unknown", "Chưa rõ")
        case .btnCheckPermissions:
            return ("Check / Request Permissions", "Kiểm tra / Xin quyền macOS")
        case .btnOpenSettings:
            return ("Open", "Mở")
        case .viewCanvas:
            return ("Screen Preview", "Xem trước màn hình")
        case .canvasEmptyTitle:
            return ("No screen preview yet", "Chưa có ảnh chụp màn hình")
        case .canvasEmptyDesc:
            return ("Take a test shot to preview your screen and draw the capture region", "Nhấn Chụp thử để xem toàn màn hình và kéo chọn vùng chụp")
        case .canvasDragHint:
            return ("Drag on the preview to set capture region", "Kéo trên ảnh xem trước để chọn vùng chụp")
        case .canvasCoordSummary:
            return ("Region: ({x}, {y}) {w}×{h}", "Vùng: ({x}, {y}) {w}×{h}")
        case .canvasPermRequired:
            return ("Screen Recording permission is required to display Screen Preview.", "Cần cấp quyền Ghi màn hình (Screen Recording) để hiển thị Screen Preview.")
        case .btnOpenScreenPerm:
            return ("Open Screen Recording Settings", "Mở cài đặt Ghi màn hình")
        case .overlayPickerHint:
            return ("Drag to select capture region • Esc or right-click to cancel", "Kéo để chọn vùng chụp • Esc hoặc chuột phải để huỷ")
        case .overlayPickerClickHint:
            return ("Click to set page-turn point • Esc or right-click to cancel", "Click để chọn điểm lật trang • Esc hoặc chuột phải để huỷ")

        case .afmSummarize:
            return ("AI Summarize", "Tóm tắt AI")
        case .afmSummarizing:
            return ("Summarizing...", "Đang tóm tắt...")
        case .afmSummarizeTitle:
            return ("Summarize screenshots into notes using on-device AI", "Tóm tắt ảnh vào ghi chú bằng AI trên máy")
        case .afmSummarizeOne:
            return ("AI Summarize Image", "Tóm tắt ảnh (AI)")
        case .afmSummarizeOneTitle:
            return ("Summarize this image into Notes using AI", "Tóm tắt ảnh này vào Ghi chú bằng AI")
        case .settingsAfmSection:
            return ("On-Device AI Engine (Apple Silicon AFM)", "Bộ xử lý AI trên máy (Apple Silicon AFM)")
        case .settingsAfmStatusTitle:
            return ("Apple Foundation Model Status", "Trạng thái Apple Foundation Model")
        case .settingsAfmStatusDesc:
            return ("Runs locally via Vision OCR + FoundationModels.framework without cloud API keys.", "Chạy cục bộ qua Vision OCR + FoundationModels.framework, không cần API key hay cloud.")
        case .afmStatusChecking:
            return ("Checking...", "Đang kiểm tra...")
        case .afmStatusAvailable:
            return ("Available (On-Device)", "Sẵn sàng (Trên máy)")
        case .afmStatusUnavailable:
            return ("Unavailable ({reason})", "Chưa sẵn sàng ({reason})")
        case .settingsFeaturesSection:
            return ("Feature Toggles", "Bật / Tắt tính năng")
        case .featAfmTitle:
            return ("AI Note Summarization", "Tóm tắt ghi chú (AI)")
        case .featAfmDesc:
            return ("Show on-device AI Summarize actions in Notes and Image Preview.", "Hiện nút Tóm tắt AI trong khung Ghi chú và cửa sổ xem trước ảnh.")
        case .featNotesTitle:
            return ("Notes Panel", "Khung Ghi chú (Notes)")
        case .featNotesDesc:
            return ("Display the Markdown/text Notes workspace in Screenshot Indexing.", "Hiển thị khung ghi chú Markdown/văn bản ở tab Screenshot Indexing.")
        case .featCaptureTitle:
            return ("Auto Capture Tab", "Tab Chụp tự động")
        case .featCaptureDesc:
            return ("Enable timed screen region capture and auto page-turn controls.", "Bật tab chụp vùng màn hình theo hẹn giờ và tự động lật trang.")
        case .featSoundTitle:
            return ("macOS Shutter Sound", "Âm thanh chụp macOS")
        case .featSoundDesc:
            return ("Play native camera shutter sound on each captured screenshot.", "Phát âm thanh màn trập gốc mỗi khi chụp màn hình.")
        case .settingsAppearanceSection:
            return ("Appearance & Language", "Giao diện & Ngôn ngữ")
        case .settingsLanguageLabel:
            return ("Language", "Ngôn ngữ")
        case .settingsThemeLabel:
            return ("Theme", "Giao diện")
        case .themeDark:
            return ("Dark", "Tối")
        case .themeLight:
            return ("Light", "Sáng")
        case .themeSystem:
            return ("System", "Hệ thống")
        case .langEn:
            return ("English", "Tiếng Anh")
        case .langVi:
            return ("Tiếng Việt", "Tiếng Việt")

        case .pathNotExist:
            return ("Path does not exist", "Đường dẫn không tồn tại")
        case .noPermission:
            return ("Permission denied", "Không có quyền truy cập")
        case .folderNotExist:
            return ("Folder does not exist", "Thư mục không tồn tại")
        case .noFiles:
            return ("No files to rename", "Không có file để đổi tên")
        case .errorPrefix:
            return ("Error", "Lỗi")
        case .renameSuccess:
            return ("Successfully renamed {success_count}/{count} files!", "Đã đổi tên {success_count}/{count} file thành công!")
        case .settingsSaved:
            return ("Settings saved successfully", "Đã lưu cài đặt thành công")
        case .settingsSaveFailed:
            return ("Failed to save settings", "Không thể lưu cài đặt")
        case .captureFolderRequired:
            return ("Please select a save folder for screenshots", "Vui lòng chọn thư mục lưu ảnh chụp")
        case .captureInvalidRegion:
            return ("Invalid capture region (minimum width and height of 10 px)", "Vùng chụp không hợp lệ (chiều rộng và chiều cao tối thiểu 10 px)")
        case .captureStarted:
            return ("Auto capture started", "Đã bắt đầu tự động chụp màn hình")
        case .captureAlreadyRunning:
            return ("Auto capture is already running", "Tiến trình tự động chụp đang chạy")
        case .captureStartFailed:
            return ("Failed to start auto capture", "Không thể bắt đầu tự động chụp")
        case .captureStopped:
            return ("Auto capture stopped", "Đã dừng tự động chụp màn hình")
        case .previewFailed:
            return ("Failed to capture full-screen preview", "Không thể chụp ảnh xem trước toàn màn hình")
        case .overlayCancelled:
            return ("Screen selection cancelled", "Đã hủy chọn trên màn hình")
        case .overlayFailed:
            return ("Failed to launch screen overlay picker", "Không thể mở lớp phủ chọn trên màn hình")
        case .permissionDeniedCapture:
            return ("Screen Recording permission is required on macOS", "Thiếu quyền Ghi màn hình (Screen Recording) trên macOS")
        case .accessibilityWarning:
            return ("Please grant Accessibility permission in System Settings for Auto Page-Turn to work", "Vui lòng cấp quyền Trợ năng (Accessibility) trong Cài đặt hệ thống để tự động lật trang hoạt động")
        case .fileNotFound:
            return ("Image file not found", "Không tìm thấy tệp ảnh")
        case .afmSummarizeSuccess:
            return ("Summarized {count} screenshots into Notes with Apple Foundation Model", "Đã tóm tắt {count} ảnh vào Ghi chú bằng Apple Foundation Model")
        case .afmUnavailable:
            return ("Apple Foundation Model is not available on this Mac", "Apple Foundation Model chưa sẵn sàng trên máy này")
        case .afmFailed:
            return ("AFM summarization failed", "Tóm tắt AFM thất bại")

        case .toastEnterFolder:
            return ("Please enter folder path", "Vui lòng nhập đường dẫn thư mục")
        case .toastNoSubfolder:
            return ("No subfolders", "Không có thư mục con")
        case .toastErrorBrowse:
            return ("Error browsing folder", "Lỗi khi duyệt thư mục")
        case .toastNoFolderSelected:
            return ("No folder selected", "Chưa chọn thư mục")
        case .statusScanning:
            return ("Scanning...", "Đang quét...")
        case .statusFileCount:
            return ("{count} screenshot files", "{count} file screenshot")
        case .toastScanError:
            return ("Error scanning files", "Lỗi khi quét file")
        case .statusConnError:
            return ("Connection error", "Lỗi kết nối")
        case .toastRefresh:
            return ("List refreshed", "Đã làm mới danh sách")
        case .toastNoPreview:
            return ("No files to preview", "Chưa có file để xem trước")
        case .toastInvalidNum:
            return ("Please enter a valid number", "Vui lòng nhập số hợp lệ")
        case .toastStartGtEnd:
            return ("Start number must be smaller than end number", "Số đầu phải nhỏ hơn số cuối")
        case .statusPreview:
            return ("Preview: {count} files will be renamed", "Xem trước: {count} file sẽ được đổi tên")
        case .toastNoRename:
            return ("No files to rename", "Chưa có file để đổi tên")
        case .toastRenameError:
            return ("Error renaming files", "Lỗi khi đổi tên")
        case .toastThemeChange:
            return ("Switched to {theme} theme", "Đã chuyển sang Giao diện {theme}")
        case .toastSettingsSaved:
            return ("Settings saved", "Đã lưu cài đặt")
        case .toastSettingsError:
            return ("Error saving settings", "Lỗi khi lưu cài đặt")
        case .toastPreviewDelay:
            return ("Switch to target window — capturing in {sec}s...", "Hãy chuyển sang cửa sổ cần chụp — sẽ chụp sau {sec}s...")
        case .toastPreviewReady:
            return ("Screen preview ready", "Đã chụp ảnh xem trước màn hình")
        case .toastPreviewFailed:
            return ("Failed to capture screen preview", "Không thể chụp ảnh xem trước")
        case .toastOverlayRegionSet:
            return ("Region updated from screen overlay", "Đã cập nhật vùng chụp từ màn hình")
        case .toastOverlayCancelled:
            return ("Overlay selection cancelled", "Đã huỷ chọn trên màn hình")
        case .toastOverlayError:
            return ("Error running screen overlay", "Lỗi khi mở lớp chọn màn hình")
        case .toastCaptureFolderRequired:
            return ("Please choose a save folder first", "Vui lòng chọn thư mục lưu ảnh trước")
        case .toastCaptureInvalidRegion:
            return ("Capture region width and height must be at least 10", "Chiều rộng và chiều cao vùng chụp phải tối thiểu 10")
        case .toastCaptureStarted:
            return ("Auto capture started", "Đã bắt đầu chụp tự động")
        case .toastCaptureStopped:
            return ("Auto capture stopped", "Đã dừng chụp tự động")
        case .toastCaptureCompleted:
            return ("Completed {count} captured shots", "Đã chụp xong {count} ảnh")
        case .toastCaptureError:
            return ("Auto capture error", "Lỗi khi chụp tự động")
        case .toastPermissionsUpdated:
            return ("Permission status updated", "Đã cập nhật trạng thái quyền")
        case .toastPermissionsError:
            return ("Could not check permissions", "Không thể kiểm tra quyền macOS")
        case .toastAccessibilityNeeded:
            return ("Grant Accessibility permission in System Settings so Auto Page-Turn can press keys", "Hãy cấp quyền Trợ năng (Accessibility) trong Cài đặt hệ thống để phím lật trang hoạt động")
        case .toastKeyRecorded:
            return ("Page-turn key set to {key}", "Đã đặt phím lật trang: {key}")
        case .toastRegionUpdated:
            return ("Region updated: {w}×{h} at ({x}, {y})", "Đã cập nhật vùng: {w}×{h} tại ({x}, {y})")
        case .toastAfmNoFiles:
            return ("Scan a folder with screenshots first", "Hãy quét một thư mục có ảnh chụp màn hình trước")
        case .toastAfmError:
            return ("AFM summarization failed", "Tóm tắt AFM thất bại")
        case .toastOverlayShortcutSet:
            return ("Region picker shortcut set to {shortcut}", "Đã đặt phím tắt chọn vùng: {shortcut}")
        case .toastOpenPermSettings:
            return ("Opening System Settings...", "Đang mở Cài đặt hệ thống...")
        case .toastCopied:
            return ("Copied to clipboard", "Đã sao chép")
        case .toastScreenPermRequired:
            return ("Grant Screen Recording permission in System Settings to show Screen Preview", "Hãy cấp quyền Ghi màn hình trong Cài đặt hệ thống để xem Screen Preview")
        }
    }
}
