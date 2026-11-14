// ── Screenshot Indexing — Frontend Logic ────────────────────────────

const API = {
    browse: (path) => fetch('/api/browse', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ path, lang: currentLang })
    }).then(r => r.json()),
    scanFiles: (folder) => fetch('/api/scan', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ folder, lang: currentLang })
    }).then(r => r.json()),
    renameFiles: (start, end) => fetch('/api/rename', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ start, end, lang: currentLang })
    }).then(r => r.json()),
    getSettings: () => fetch('/api/settings').then(r => r.json()),
    saveSettings: (payload) => fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...payload, lang: currentLang })
    }).then(r => r.json()),
    checkPermissions: (prompt = false) => fetch('/api/capture/permissions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt, lang: currentLang })
    }).then(r => r.json()),
    previewScreen: (delaySec = 0.2) => fetch('/api/capture/preview-screen', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ delay_sec: delaySec, lang: currentLang })
    }).then(r => r.json()),
    pickOverlay: (target = 'region') => fetch('/api/capture/pick-overlay', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ target, lang: currentLang })
    }).then(r => r.json()),
    startCapture: (payload) => fetch('/api/capture/start', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ...payload, lang: currentLang })
    }).then(r => r.json()),
    stopCapture: () => fetch('/api/capture/stop', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ lang: currentLang })
    }).then(r => r.json()),
    getCaptureStatus: () => fetch('/api/capture/status').then(r => r.json()),
};

// ── i18n ────────────────────────────────────────────────────────────
const translations = {
    en: {
        desc: "Batch rename screenshot files chronologically",
        tab_indexing: "Screenshot Indexing",
        tab_auto_capture: "Auto Capture",
        resizer_title: "Drag to resize",
        folder: "Folder",
        folder_placeholder: "Enter folder path...",
        browse: "Browse",
        refresh: "Refresh",
        range: "Numbering Range",
        from: "From",
        to: "To",
        preview: "Preview",
        rename: "Rename",
        notes: "Notes",
        notes_placeholder: "Enter notes here...",
        theme_toggle: "Toggle Light / Dark theme",
        file_list: "Screenshot File List",
        original_name: "Original Name",
        new_name: "New Name",
        empty_title: "No files yet",
        empty_desc: "Select a folder containing screenshot files to start",
        modal_select_folder: "Select Folder",
        modal_no_subfolder: "No subfolders",
        back: "Back",
        cancel: "Cancel",
        select_this_folder: "Select this folder",
        confirm_rename: "Confirm Rename",
        confirm_message: "Are you sure you want to rename?",
        first_file: "First file:",
        last_file: "Last file:",
        cancel_btn: "Cancel",
        agree_rename: "Confirm Rename",
        preview_image: "Preview Image",
        prev_image: "Previous Image (Left Arrow / Up)",
        next_image: "Next Image (Right Arrow / Down)",
        click_to_preview: "Click to preview image",
        // Auto Capture UI
        capture_save_folder: "Save Folder",
        capture_folder_placeholder: "Enter save folder path...",
        capture_region: "Capture Region",
        btn_test_shot_now: "Test Shot Now",
        btn_test_shot_2s: "Test Shot in 2s",
        btn_pick_region_overlay: "Screen Overlay Picker",
        capture_timer_sound: "Timer & Shutter",
        capture_interval: "Interval (1–10s)",
        capture_max_shots: "Shot Limit",
        capture_max_shots_placeholder: "0 = ∞",
        capture_sound_label: "macOS Shutter Sound",
        page_turn_title: "Auto Page-Turn",
        page_turn_enable: "Enable auto page-turn",
        pt_key_recorder_label: "Sample Key (click & press any key)",
        pt_key_recorder_placeholder: "Click & press key...",
        pt_key_recorder_title: "Click here and press any key to record",
        pt_key_listening: "Press any key...",
        capture_controls: "Capture Control",
        btn_capture_start: "Start Capture",
        btn_capture_stop: "Stop",
        phase_idle: "Ready",
        phase_countdown: "Starting in {sec}s...",
        phase_capturing: "Capturing...",
        phase_completed: "Completed",
        phase_stopped: "Stopped",
        phase_error: "Error",
        perm_screen_recording: "Screen Recording",
        perm_accessibility: "Accessibility",
        perm_granted: "Granted",
        perm_missing: "Not Granted",
        perm_unknown: "Unknown",
        btn_check_permissions: "Check / Request Permissions",
        view_canvas: "Screen Preview",
        canvas_empty_title: "No screen preview yet",
        canvas_empty_desc: "Take a test shot to preview your screen and draw the capture region",
        canvas_drag_hint: "Drag on the preview to set capture region",
        canvas_coord_summary: "Region: ({x}, {y}) {w}×{h}",
        // JS strings
        toast_enter_folder: "Please enter folder path",
        toast_no_subfolder: "No subfolders",
        toast_error_browse: "Error browsing folder",
        toast_no_folder_selected: "No folder selected",
        status_scanning: "Scanning...",
        status_file_count: "{count} screenshot files",
        toast_scan_error: "Error scanning files",
        status_conn_error: "Connection error",
        toast_refresh: "List refreshed",
        toast_no_preview: "No files to preview",
        toast_invalid_num: "Please enter a valid number",
        toast_start_gt_end: "Start number must be smaller than end number",
        status_preview: "Preview: {count} files will be renamed",
        toast_no_rename: "No files to rename",
        confirm_rename_count: "Are you sure you want to rename {count} files?",
        btn_renaming: "Renaming...",
        toast_rename_error: "Error renaming files",
        toast_theme_change: "Switched to {theme} theme",
        theme_dark: "Dark",
        theme_light: "Light",
        btn_rename: "Rename",
        toast_settings_saved: "Settings saved",
        toast_settings_error: "Error saving settings",
        toast_preview_delay: "Switch to target window — capturing in {sec}s...",
        toast_preview_ready: "Screen preview ready",
        toast_preview_failed: "Failed to capture screen preview",
        toast_overlay_region_set: "Region updated from screen overlay",
        toast_overlay_cancelled: "Overlay selection cancelled",
        toast_overlay_error: "Error running screen overlay",
        toast_capture_folder_required: "Please choose a save folder first",
        toast_capture_invalid_region: "Capture region width and height must be at least 10",
        toast_capture_started: "Auto capture started",
        toast_capture_stopped: "Auto capture stopped",
        toast_capture_completed: "Completed {count} captured shots",
        toast_capture_error: "Auto capture error",
        toast_permissions_updated: "Permission status updated",
        toast_permissions_error: "Could not check permissions",
        toast_accessibility_needed: "Grant Accessibility permission in System Settings so Auto Page-Turn can press keys",
        toast_key_recorded: "Page-turn key set to {key}",
        toast_region_updated: "Region updated: {w}×{h} at ({x}, {y})"
    },
    vi: {
        desc: "Đổi tên đồng loạt file screenshot theo thứ tự thời gian",
        tab_indexing: "Screenshot Indexing",
        tab_auto_capture: "Chụp tự động",
        resizer_title: "Kéo để điều chỉnh kích thước",
        folder: "Thư mục",
        folder_placeholder: "Nhập đường dẫn thư mục...",
        browse: "Duyệt",
        refresh: "Làm mới",
        range: "Phạm vi đánh số",
        from: "Từ",
        to: "Đến",
        preview: "Xem trước",
        rename: "Đổi tên",
        notes: "Ghi chú",
        notes_placeholder: "Nhập ghi chú tại đây...",
        theme_toggle: "Đổi chế độ Sáng / Tối",
        file_list: "Danh sách file screenshot",
        original_name: "Tên gốc",
        new_name: "Tên mới",
        empty_title: "Chưa có file nào",
        empty_desc: "Chọn thư mục chứa các file screenshot để bắt đầu",
        modal_select_folder: "Chọn thư mục",
        modal_no_subfolder: "Không có thư mục con",
        back: "Trở về",
        cancel: "Huỷ",
        select_this_folder: "Chọn thư mục này",
        confirm_rename: "Xác nhận đổi tên",
        confirm_message: "Bạn có chắc chắn muốn đổi tên?",
        first_file: "File đầu tiên:",
        last_file: "File cuối cùng:",
        cancel_btn: "Huỷ bỏ",
        agree_rename: "Đồng ý đổi tên",
        preview_image: "Xem trước ảnh",
        prev_image: "Ảnh trước (Mũi tên Trái / Up)",
        next_image: "Ảnh tiếp theo (Mũi tên Phải / Down)",
        click_to_preview: "Click để xem trước ảnh",
        // Auto Capture UI
        capture_save_folder: "Thư mục lưu ảnh",
        capture_folder_placeholder: "Nhập đường dẫn lưu ảnh chụp...",
        capture_region: "Vùng chụp cố định",
        btn_test_shot_now: "Chụp thử ngay",
        btn_test_shot_2s: "Chụp thử sau 2s",
        btn_pick_region_overlay: "Chọn vùng trên màn hình",
        capture_timer_sound: "Hẹn giờ & Âm thanh",
        capture_interval: "Chu kỳ chụp (1–10s)",
        capture_max_shots: "Giới hạn số ảnh",
        capture_max_shots_placeholder: "0 = ∞",
        capture_sound_label: "Âm thanh chụp macOS",
        page_turn_title: "Tự động lật trang",
        page_turn_enable: "Bật tự động lật trang",
        pt_key_recorder_label: "Phím mẫu (click & nhấn phím bất kỳ)",
        pt_key_recorder_placeholder: "Click & nhấn phím...",
        pt_key_recorder_title: "Click vào đây và nhấn phím bất kỳ để ghi",
        pt_key_listening: "Đang chờ nhấn phím...",
        capture_controls: "Điều khiển chụp",
        btn_capture_start: "Bắt đầu chụp",
        btn_capture_stop: "Dừng",
        phase_idle: "Sẵn sàng",
        phase_countdown: "Bắt đầu sau {sec}s...",
        phase_capturing: "Đang chụp...",
        phase_completed: "Hoàn thành",
        phase_stopped: "Đã dừng",
        phase_error: "Lỗi",
        perm_screen_recording: "Ghi màn hình",
        perm_accessibility: "Trợ năng (Accessibility)",
        perm_granted: "Đã cấp",
        perm_missing: "Chưa cấp",
        perm_unknown: "Chưa rõ",
        btn_check_permissions: "Kiểm tra / Xin quyền macOS",
        view_canvas: "Xem trước màn hình",
        canvas_empty_title: "Chưa có ảnh chụp màn hình",
        canvas_empty_desc: "Nhấn Chụp thử để xem toàn màn hình và kéo chọn vùng chụp",
        canvas_drag_hint: "Kéo trên ảnh xem trước để chọn vùng chụp",
        canvas_coord_summary: "Vùng: ({x}, {y}) {w}×{h}",
        // JS strings
        toast_enter_folder: "Vui lòng nhập đường dẫn thư mục",
        toast_no_subfolder: "Không có thư mục con",
        toast_error_browse: "Lỗi khi duyệt thư mục",
        toast_no_folder_selected: "Chưa chọn thư mục",
        status_scanning: "Đang quét...",
        status_file_count: "{count} file screenshot",
        toast_scan_error: "Lỗi khi quét file",
        status_conn_error: "Lỗi kết nối",
        toast_refresh: "Đã làm mới danh sách",
        toast_no_preview: "Chưa có file để xem trước",
        toast_invalid_num: "Vui lòng nhập số hợp lệ",
        toast_start_gt_end: "Số đầu phải nhỏ hơn số cuối",
        status_preview: "Xem trước: {count} file sẽ được đổi tên",
        toast_no_rename: "Chưa có file để đổi tên",
        confirm_rename_count: "Bạn có chắc chắn muốn đổi tên {count} file?",
        btn_renaming: "Đang đổi tên...",
        toast_rename_error: "Lỗi khi đổi tên",
        toast_theme_change: "Đã chuyển sang Giao diện {theme}",
        theme_dark: "Tối",
        theme_light: "Sáng",
        btn_rename: "Đổi tên",
        toast_settings_saved: "Đã lưu cài đặt",
        toast_settings_error: "Lỗi khi lưu cài đặt",
        toast_preview_delay: "Hãy chuyển sang cửa sổ cần chụp — sẽ chụp sau {sec}s...",
        toast_preview_ready: "Đã chụp ảnh xem trước màn hình",
        toast_preview_failed: "Không thể chụp ảnh xem trước",
        toast_overlay_region_set: "Đã cập nhật vùng chụp từ màn hình",
        toast_overlay_cancelled: "Đã huỷ chọn trên màn hình",
        toast_overlay_error: "Lỗi khi mở lớp chọn màn hình",
        toast_capture_folder_required: "Vui lòng chọn thư mục lưu ảnh trước",
        toast_capture_invalid_region: "Chiều rộng và chiều cao vùng chụp phải tối thiểu 10",
        toast_capture_started: "Đã bắt đầu chụp tự động",
        toast_capture_stopped: "Đã dừng chụp tự động",
        toast_capture_completed: "Đã chụp xong {count} ảnh",
        toast_capture_error: "Lỗi khi chụp tự động",
        toast_permissions_updated: "Đã cập nhật trạng thái quyền",
        toast_permissions_error: "Không thể kiểm tra quyền macOS",
        toast_accessibility_needed: "Hãy cấp quyền Trợ năng (Accessibility) trong Cài đặt hệ thống để phím lật trang hoạt động",
        toast_key_recorded: "Đã đặt phím lật trang: {key}",
        toast_region_updated: "Đã cập nhật vùng: {w}×{h} tại ({x}, {y})"
    }
};

let currentLang = localStorage.getItem('user_lang') || 'en';
if (currentLang !== 'en' && currentLang !== 'vi') currentLang = 'en';

function t(key, vars = {}) {
    const dict = translations[currentLang] || translations.en;
    let str = dict[key] || translations.en[key] || key;
    for (const [k, v] of Object.entries(vars)) {
        str = str.replace(`{${k}}`, v);
    }
    return str;
}

function updateDOMTranslations() {
    document.querySelectorAll('[data-i18n]').forEach(el => {
        el.textContent = t(el.getAttribute('data-i18n'));
    });
    document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
        el.placeholder = t(el.getAttribute('data-i18n-placeholder'));
    });
    document.querySelectorAll('[data-i18n-title]').forEach(el => {
        el.title = t(el.getAttribute('data-i18n-title'));
    });

    const headerLangSelect = document.getElementById('header-lang-select');
    if (headerLangSelect && headerLangSelect.value !== currentLang) {
        headerLangSelect.value = currentLang;
    }

    refreshDynamicTranslations();
}

function refreshDynamicTranslations() {
    // Update clickable table row tooltips if table already rendered
    $$('#file-tbody tr.clickable-row').forEach(tr => {
        tr.title = t('click_to_preview');
    });

    // Update dynamic Auto Capture indicators
    renderPermissionBadges(lastPermissions);
    renderCaptureStatus(lastCaptureStatus);
    updateCanvasCoordSummary();
    refreshKeyRecorderDisplay();
}

function setLanguage(lang) {
    if (lang !== 'en' && lang !== 'vi') return;
    currentLang = lang;
    localStorage.setItem('user_lang', currentLang);
    document.documentElement.setAttribute('lang', currentLang);
    updateDOMTranslations();
}

// ── State ───────────────────────────────────────────────────────────

let activeTab = 'indexing';
let currentFolder = '';
let currentFiles = [];
let browserCurrentPath = '';
let browserTarget = 'indexing';
let currentImageIndex = -1;

// Auto-Capture State
let captureSettings = {
    save_folder: '',
    region: { x: 100, y: 100, width: 800, height: 600 },
    interval_sec: 3,
    max_shots: 0,
    countdown_sec: 3,
    page_turn: {
        enabled: true,
        mode: 'keyboard',
        key_name: 'ArrowRight',
        key_code: 124,
        click_x: 500,
        click_y: 500,
    },
    sound_enabled: true,
};

let lastPermissions = { screen_recording: null, accessibility: null };
let lastCaptureStatus = {
    running: false,
    phase: 'idle',
    countdown_remaining: 0,
    captured_count: 0,
    max_shots: 0,
    interval_sec: 3,
    save_folder: '',
    last_file: '',
    captured_files: [],
    last_error: ''
};

let statusPollTimer = null;
let isRecordingKey = false;

// Interactive Canvas State
let previewMeta = null;
let previewImageObj = null;
let isDrawingRegion = false;
let dragStartLogical = null;
let regionBeforeDrag = null;

// ── DOM Helpers ─────────────────────────────────────────────────────

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

function escapeAttr(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

// ── Top Bar Tab Navigation ──────────────────────────────────────────

function switchTab(tabName) {
    if (tabName !== 'indexing' && tabName !== 'capture') return;
    const prevTab = activeTab;
    activeTab = tabName;

    const btnIndexing = $('#tab-btn-indexing');
    const btnCapture = $('#tab-btn-capture');
    const viewIndexing = $('#view-indexing');
    const viewCapture = $('#view-capture');

    if (btnIndexing) {
        btnIndexing.classList.toggle('active', tabName === 'indexing');
        btnIndexing.setAttribute('aria-selected', tabName === 'indexing' ? 'true' : 'false');
    }
    if (btnCapture) {
        btnCapture.classList.toggle('active', tabName === 'capture');
        btnCapture.setAttribute('aria-selected', tabName === 'capture' ? 'true' : 'false');
    }
    if (viewIndexing) {
        viewIndexing.classList.toggle('active', tabName === 'indexing');
        viewIndexing.style.display = tabName === 'indexing' ? 'flex' : 'none';
    }
    if (viewCapture) {
        viewCapture.classList.toggle('active', tabName === 'capture');
        viewCapture.style.display = tabName === 'capture' ? 'flex' : 'none';
    }

    if (tabName === 'indexing' && prevTab === 'capture') {
        const capFolder = ($('#capture-folder-input')?.value || '').trim();
        if (capFolder) {
            const folderInput = $('#folder-input');
            if (folderInput) folderInput.value = capFolder;
            currentFolder = capFolder;
            scanFiles();
        }
    } else if (tabName === 'capture') {
        requestAnimationFrame(() => {
            fitCanvasToStage();
            redrawCaptureCanvas();
        });
    }
}

// ── Toast ───────────────────────────────────────────────────────────

function showToast(message, typeOrDuration = 'info', duration = 3000) {
    let type = 'info';
    let dur = duration;

    if (typeof typeOrDuration === 'number') {
        dur = typeOrDuration;
    } else if (typeof typeOrDuration === 'string') {
        type = typeOrDuration;
    }

    const toast = $('#toast');

    let iconSvg = '';
    if (type === 'error') {
        iconSvg = `<svg class="toast-icon toast-icon-error" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="15" y1="9" x2="9" y2="15"/><line x1="9" y1="9" x2="15" y2="15"/></svg>`;
    } else if (type === 'success') {
        iconSvg = `<svg class="toast-icon toast-icon-success" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>`;
    } else if (type === 'warning') {
        iconSvg = `<svg class="toast-icon toast-icon-warning" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>`;
    } else {
        iconSvg = `<svg class="toast-icon toast-icon-info" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="16" x2="12" y2="12"/><line x1="12" y1="8" x2="12.01" y2="8"/></svg>`;
    }

    toast.className = `toast toast-${type}`;
    toast.innerHTML = `
        ${iconSvg}
        <span>${message}</span>
    `;
    toast.classList.add('show');
    clearTimeout(toast._timer);
    toast._timer = setTimeout(() => toast.classList.remove('show'), dur);
}

// ── Status ──────────────────────────────────────────────────────────

function setStatus(text, type = '') {
    const statusText = $('#status-text');
    const statusDot = $('#status-dot');

    if (statusText) statusText.textContent = text;
    if (statusDot) {
        statusDot.className = 'status-dot';
        if (type) statusDot.classList.add(type);
    }
}

// ── Folder Input ────────────────────────────────────────────────────

function loadFolder() {
    const input = $('#folder-input');
    const folder = input.value.trim();

    if (!folder) {
        showToast(t('toast_enter_folder'));
        return;
    }

    currentFolder = folder;
    scanFiles();
}

// ── Folder Browser Modal ────────────────────────────────────────────

function closeModalWithAnimation(modal, callback) {
    if (!modal || modal.style.display === 'none' || modal.classList.contains('closing')) return;

    modal.classList.add('closing');
    setTimeout(() => {
        modal.style.display = 'none';
        modal.classList.remove('closing');
        if (callback) callback();
    }, 190);
}

async function openBrowser(target = 'indexing') {
    browserTarget = target === 'capture' ? 'capture' : 'indexing';
    const modal = $('#folder-modal');
    modal.classList.remove('closing');
    modal.style.display = 'flex';
    const startPath = browserTarget === 'capture'
        ? (($('#capture-folder-input')?.value || '').trim() || currentFolder || '')
        : (currentFolder || '');
    await browseTo(startPath || undefined);
}

function closeBrowser() {
    const modal = $('#folder-modal');
    closeModalWithAnimation(modal);
}

function closeBrowserOutside(event) {
    if (event.target === event.currentTarget) {
        closeBrowser();
    }
}

async function browseTo(path) {
    try {
        const res = await API.browse(path);
        if (!res.ok) {
            showToast(escapeAttr(res.message || t('toast_error_browse')), 'error');
            return;
        }

        browserCurrentPath = res.current;
        $('#modal-current-path').textContent = res.current;
        $('#btn-parent').style.display = res.parent ? 'inline-flex' : 'none';

        const list = $('#modal-dir-list');
        if (res.dirs.length === 0) {
            list.innerHTML = `<div class="modal-empty">${escapeAttr(t('modal_no_subfolder'))}</div>`;
        } else {
            const base = res.current === '/' ? '' : res.current;
            list.innerHTML = res.dirs.map(dir => {
                const fullPath = `${base}/${dir}`;
                return `
                <div class="dir-item" data-path="${escapeAttr(fullPath)}" onclick="browseTo(this.getAttribute('data-path'))">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
                        stroke-linecap="round" stroke-linejoin="round">
                        <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>
                    </svg>
                    ${escapeAttr(dir)}
                </div>`;
            }).join('');
        }
    } catch (err) {
        showToast(t('toast_error_browse'), 'error');
    }
}

async function browseParent() {
    const res = await API.browse(browserCurrentPath);
    if (res.ok && res.parent) {
        await browseTo(res.parent);
    }
}

async function selectFolder() {
    if (browserTarget === 'capture') {
        const capInput = $('#capture-folder-input');
        if (capInput) capInput.value = browserCurrentPath;
        closeBrowser();
        await saveCaptureSettingsFromUI({ showSavedToast: true });
        return;
    }

    currentFolder = browserCurrentPath;
    $('#folder-input').value = browserCurrentPath;
    closeBrowser();
    scanFiles();
}

// ── Scan ────────────────────────────────────────────────────────────

async function scanFiles() {
    if (!currentFolder) {
        showToast(t('toast_no_folder_selected'));
        return;
    }

    setStatus(t('status_scanning'), 'info');

    try {
        const res = await API.scanFiles(currentFolder);
        if (res.ok) {
            currentFiles = res.files;
            renderTable(res.files);
            setStatus(t('status_file_count', { count: res.count }), 'success');
            $('#file-count').textContent = `(${res.count})`;
        } else {
            currentFiles = [];
            renderEmptyState();
            setStatus(res.message, 'error');
            $('#file-count').textContent = '';
        }
    } catch (err) {
        showToast(t('toast_scan_error'), 'error');
        setStatus(t('status_conn_error'), 'error');
    }
}

async function refreshFiles() {
    if (!currentFolder) {
        showToast(t('toast_no_folder_selected'));
        return;
    }
    await scanFiles();
    showToast(t('toast_refresh'));
}

// ── Table ───────────────────────────────────────────────────────────

function handleRowClick(tr) {
    const filename = tr.getAttribute('data-filename');
    if (filename) {
        openImageModal(filename);
    }
}

function renderTable(files, startNum = null) {
    const tbody = $('#file-tbody');
    const wrapper = $('#table-wrapper');
    const emptyState = $('#empty-state');

    if (!files || files.length === 0) {
        renderEmptyState();
        return;
    }

    emptyState.style.display = 'none';
    wrapper.style.display = 'flex';

    const rowTitle = escapeAttr(t('click_to_preview'));
    tbody.innerHTML = files.map((f, i) => {
        const newName = startNum !== null ? `${startNum + i}.png` : '—';
        const newNameClass = startNum !== null ? '' : 'style="color: var(--color-ink-muted-48); font-weight: 400;"';
        const attrName = escapeAttr(f.name);
        return `<tr class="clickable-row" data-filename="${attrName}" onclick="handleRowClick(this)" title="${rowTitle}">
            <td>${f.index}</td>
            <td>
                <div class="filename-cell">
                    <svg class="file-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
                        <circle cx="8.5" cy="8.5" r="1.5"/>
                        <polyline points="21 15 16 10 5 21"/>
                    </svg>
                    <span>${attrName}</span>
                </div>
            </td>
            <td ${newNameClass}>${escapeAttr(newName)}</td>
        </tr>`;
    }).join('');
}

function renderEmptyState() {
    const wrapper = $('#table-wrapper');
    const emptyState = $('#empty-state');

    wrapper.style.display = 'none';
    emptyState.style.display = 'flex';
}

// ── Preview ─────────────────────────────────────────────────────────

function preview() {
    if (!currentFiles.length) {
        showToast(t('toast_no_preview'));
        return;
    }

    const startNum = parseInt($('#input-start').value);
    const endNum = parseInt($('#input-end').value);

    if (isNaN(startNum) || isNaN(endNum)) {
        showToast(t('toast_invalid_num'));
        return;
    }

    if (startNum > endNum) {
        showToast(t('toast_start_gt_end'));
        return;
    }

    const totalNumbers = endNum - startNum + 1;
    const count = Math.min(currentFiles.length, totalNumbers);

    renderTable(currentFiles.slice(0, count), startNum);
    setStatus(t('status_preview', { count: count }), 'info');
}

// ── Rename Confirmation Modal ───────────────────────────────────────

let pendingRenameData = null;

function requestRename() {
    if (!currentFiles.length) {
        showToast(t('toast_no_rename'));
        return;
    }

    const startNum = parseInt($('#input-start').value);
    const endNum = parseInt($('#input-end').value);

    if (isNaN(startNum) || isNaN(endNum)) {
        showToast(t('toast_invalid_num'));
        return;
    }

    if (startNum > endNum) {
        showToast(t('toast_start_gt_end'));
        return;
    }

    const totalNumbers = endNum - startNum + 1;
    const count = Math.min(currentFiles.length, totalNumbers);

    pendingRenameData = { startNum, endNum, count };

    $('#confirm-count-text').textContent = t('confirm_rename_count', { count: count });
    $('#confirm-first-old').textContent = currentFiles[0].name;
    $('#confirm-first-new').textContent = `${startNum}.png`;
    $('#confirm-last-old').textContent = currentFiles[count - 1].name;
    $('#confirm-last-new').textContent = `${startNum + count - 1}.png`;

    const modal = $('#confirm-modal');
    modal.classList.remove('closing');
    modal.style.display = 'flex';
}

function closeConfirmModal() {
    const modal = $('#confirm-modal');
    closeModalWithAnimation(modal, () => {
        pendingRenameData = null;
    });
}

function closeConfirmOutside(event) {
    if (event.target === event.currentTarget) {
        closeConfirmModal();
    }
}

async function executeRename() {
    if (!pendingRenameData) return;

    const { startNum, endNum } = pendingRenameData;
    closeConfirmModal();

    const btn = $('#btn-rename');
    btn.disabled = true;
    btn.innerHTML = `<span class="spinner"></span> ${escapeAttr(t('btn_renaming'))}`;

    try {
        const res = await API.renameFiles(startNum, endNum);
        if (res.ok) {
            showToast(escapeAttr(res.message), 'success');
            setStatus(res.message, 'success');
            currentFiles = [];
            renderEmptyState();
            $('#file-count').textContent = '';
        } else {
            showToast(escapeAttr(res.message), 'error');
            setStatus(res.message, 'error');
        }
    } catch (err) {
        showToast(t('toast_rename_error'), 'error');
        setStatus(t('status_conn_error'), 'error');
    } finally {
        btn.disabled = false;
        btn.innerHTML = `
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
            </svg>
            <span data-i18n="rename">${escapeAttr(t('btn_rename'))}</span>
        `;
    }
}

// ── Resizer ─────────────────────────────────────────────────────────

function initResizerFor(containerSel, sidebarSel, resizerSel, storageKey, defaultWidth = 290, onResizeDone = null) {
    const container = $(containerSel);
    const sidebar = $(sidebarSel);
    const resizer = $(resizerSel);

    if (!container || !sidebar || !resizer) return;

    const MIN_SIDEBAR_WIDTH = 290;

    const savedWidth = localStorage.getItem(storageKey);
    if (savedWidth) {
        const parsed = parseInt(savedWidth, 10);
        if (!isNaN(parsed) && parsed >= MIN_SIDEBAR_WIDTH && parsed <= 650) {
            sidebar.style.width = `${parsed}px`;
        } else {
            sidebar.style.width = `${defaultWidth}px`;
        }
    } else {
        sidebar.style.width = `${defaultWidth}px`;
    }

    let isDragging = false;
    let startX = 0;
    let startWidth = 0;

    const onPointerDown = (e) => {
        isDragging = true;
        startX = e.clientX;
        startWidth = sidebar.getBoundingClientRect().width;

        resizer.classList.add('dragging');
        document.body.style.cursor = 'col-resize';
        document.body.style.userSelect = 'none';

        document.addEventListener('pointermove', onPointerMove);
        document.addEventListener('pointerup', onPointerUp);
    };

    const onPointerMove = (e) => {
        if (!isDragging) return;
        const deltaX = e.clientX - startX;
        const containerWidth = container.getBoundingClientRect().width;
        const minAllowed = MIN_SIDEBAR_WIDTH;
        const maxAllowed = Math.min(650, Math.max(MIN_SIDEBAR_WIDTH, containerWidth - 350));
        let newWidth = startWidth + deltaX;

        newWidth = Math.max(minAllowed, Math.min(newWidth, maxAllowed));
        sidebar.style.width = `${newWidth}px`;
        if (onResizeDone) onResizeDone();
    };

    const onPointerUp = () => {
        if (!isDragging) return;
        isDragging = false;
        resizer.classList.remove('dragging');
        document.body.style.cursor = '';
        document.body.style.userSelect = '';

        document.removeEventListener('pointermove', onPointerMove);
        document.removeEventListener('pointerup', onPointerUp);

        localStorage.setItem(storageKey, sidebar.offsetWidth.toString());
        if (onResizeDone) onResizeDone();
    };

    resizer.addEventListener('pointerdown', onPointerDown);
}

function initResizer() {
    initResizerFor('#split-container', '#sidebar-panel', '#resizer-handle', 'sidebar_width', 290);
    initResizerFor('#capture-split-container', '#capture-sidebar-panel', '#capture-resizer-handle', 'capture_sidebar_width', 340, () => {
        fitCanvasToStage();
        redrawCaptureCanvas();
    });
}

// ── Notes Persistence ───────────────────────────────────────────────

function saveNotes() {
    const input = $('#notes-input');
    if (input) {
        localStorage.setItem('user_temp_notes', input.value);
    }
}

function loadNotes() {
    const input = $('#notes-input');
    if (input) {
        const saved = localStorage.getItem('user_temp_notes');
        if (saved !== null) {
            input.value = saved;
        }
    }
}

// ── Image Preview Modal ─────────────────────────────────────────────

function openImageModal(filenameOrIndex) {
    if (!currentFiles || currentFiles.length === 0) return;

    if (typeof filenameOrIndex === 'number') {
        currentImageIndex = filenameOrIndex;
    } else {
        currentImageIndex = currentFiles.findIndex(f => f.name === filenameOrIndex);
    }

    if (currentImageIndex < 0) currentImageIndex = 0;
    if (currentImageIndex >= currentFiles.length) currentImageIndex = currentFiles.length - 1;

    updateImageModalContent();

    const modal = $('#image-modal');
    if (modal) {
        modal.classList.remove('closing');
        modal.style.display = 'flex';
    }
}

function updateImageModalContent() {
    if (currentImageIndex < 0 || currentImageIndex >= currentFiles.length) return;

    const file = currentFiles[currentImageIndex];
    const title = $('#image-modal-title');
    const img = $('#image-modal-img');
    const counter = $('#image-modal-counter');

    if (title) title.textContent = file.name;
    if (counter) counter.textContent = `${currentImageIndex + 1} / ${currentFiles.length}`;
    if (img) img.src = `/api/image?name=${encodeURIComponent(file.name)}&t=${Date.now()}`;

    const rows = $$('#file-tbody tr');
    rows.forEach((row, idx) => {
        if (idx === currentImageIndex) {
            row.classList.add('active-preview-row');
            row.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
        } else {
            row.classList.remove('active-preview-row');
        }
    });
}

function navigateImage(step) {
    if (!currentFiles || currentFiles.length === 0) return;

    let newIndex = currentImageIndex + step;
    if (newIndex < 0) newIndex = currentFiles.length - 1;
    if (newIndex >= currentFiles.length) newIndex = 0;

    currentImageIndex = newIndex;
    updateImageModalContent();
}

function closeImageModal() {
    const modal = $('#image-modal');
    closeModalWithAnimation(modal, () => {
        const img = $('#image-modal-img');
        if (img) img.src = '';
        const rows = $$('#file-tbody tr');
        rows.forEach(row => row.classList.remove('active-preview-row'));
    });
}

function closeImageOutside(event) {
    if (event.target === event.currentTarget) {
        closeImageModal();
    }
}

// ── Auto Capture: Settings & Form Handlers ──────────────────────────

function clampInt(val, min, max, fallback) {
    const n = parseInt(val, 10);
    if (isNaN(n)) return fallback;
    if (max !== null && max !== undefined) {
        return Math.max(min, Math.min(max, n));
    }
    return Math.max(min, n);
}

function formatKeyDisplay(keyName) {
    const k = keyName || 'ArrowRight';
    const symbols = {
        ArrowRight: '→ ArrowRight',
        ArrowLeft: '← ArrowLeft',
        ArrowDown: '↓ ArrowDown',
        ArrowUp: '↑ ArrowUp',
        Space: '␣ Space',
        PageDown: '⇟ PageDown',
        PageUp: '⇞ PageUp',
        Enter: '↵ Enter',
        Return: '↵ Return',
        Tab: '⇥ Tab',
        Escape: '⎋ Escape',
        Backspace: '⌫ Backspace',
        Delete: '⌦ Delete',
        Home: '↖ Home',
        End: '↘ End',
    };
    if (symbols[k]) return symbols[k];
    if (k.length === 1) return k.toUpperCase();
    return k;
}

function normalizeRecordedKey(e) {
    const ignored = new Set([
        'Shift', 'Control', 'Alt', 'Meta', 'CapsLock',
        'Fn', 'NumLock', 'ScrollLock', 'Dead', 'Unidentified'
    ]);
    if (ignored.has(e.key)) return null;

    if (e.code === 'Space' || e.key === ' ' || e.key === 'Spacebar') {
        return 'Space';
    }
    if (e.code === 'NumpadEnter' || e.key === 'Enter') {
        return 'Enter';
    }
    const namedKeys = [
        'ArrowRight', 'ArrowLeft', 'ArrowDown', 'ArrowUp',
        'PageDown', 'PageUp', 'Tab', 'Escape', 'Home', 'End',
        'Backspace', 'Delete',
        'F1', 'F2', 'F3', 'F4', 'F5', 'F6', 'F7', 'F8', 'F9', 'F10', 'F11', 'F12'
    ];
    if (namedKeys.includes(e.key)) {
        return e.key;
    }
    const keyMatch = /^Key([A-Z])$/.exec(e.code || '');
    if (keyMatch) {
        return keyMatch[1].toLowerCase();
    }
    const digitMatch = /^Digit([0-9])$/.exec(e.code || '');
    if (digitMatch) {
        return digitMatch[1];
    }
    if (e.key && e.key.length === 1) {
        return e.key.toLowerCase();
    }
    return e.code || e.key || 'ArrowRight';
}

function refreshKeyRecorderDisplay() {
    const rec = $('#key-recorder-input');
    const keyName = captureSettings?.page_turn?.key_name || 'ArrowRight';
    if (rec && !isRecordingKey && document.activeElement !== rec) {
        rec.value = formatKeyDisplay(keyName);
    }
}

function initKeyRecorder() {
    const rec = $('#key-recorder-input');
    if (!rec) return;

    const startRecording = () => {
        isRecordingKey = true;
        rec.classList.add('is-recording');
        rec.value = t('pt_key_listening');
    };

    rec.addEventListener('focus', startRecording);
    rec.addEventListener('click', startRecording);

    rec.addEventListener('blur', () => {
        isRecordingKey = false;
        rec.classList.remove('is-recording');
        refreshKeyRecorderDisplay();
    });

    window.addEventListener('keydown', async (e) => {
        if (!isRecordingKey && document.activeElement !== rec) return;

        e.preventDefault();
        e.stopPropagation();
        if (typeof e.stopImmediatePropagation === 'function') {
            e.stopImmediatePropagation();
        }

        const keyName = normalizeRecordedKey(e);
        if (!keyName) return;

        isRecordingKey = false;
        captureSettings.page_turn.mode = 'keyboard';
        captureSettings.page_turn.key_name = keyName;
        captureSettings.page_turn.key_code = null;

        rec.classList.remove('is-recording');
        rec.value = formatKeyDisplay(keyName);
        rec.blur();

        rec.classList.add('is-saved');
        setTimeout(() => rec.classList.remove('is-saved'), 900);

        showToast(t('toast_key_recorded', { key: escapeAttr(formatKeyDisplay(keyName)) }), 'success');
        await saveCaptureSettingsFromUI({ showSavedToast: false });
    }, true);
}

function applySettingsToUI(rawSettings) {
    if (!rawSettings) return;
    const reg = rawSettings.region || {};
    const pt = rawSettings.page_turn || {};

    captureSettings = {
        save_folder: rawSettings.save_folder || '',
        region: {
            x: Number.isFinite(Number(reg.x)) ? Math.round(Number(reg.x)) : 100,
            y: Number.isFinite(Number(reg.y)) ? Math.round(Number(reg.y)) : 100,
            width: clampInt(reg.width, 10, null, 800),
            height: clampInt(reg.height, 10, null, 600),
        },
        interval_sec: clampInt(rawSettings.interval_sec, 1, 10, 3),
        max_shots: clampInt(rawSettings.max_shots, 0, null, 0),
        countdown_sec: clampInt(rawSettings.countdown_sec, 0, 10, 3),
        page_turn: {
            enabled: pt.enabled !== undefined ? Boolean(pt.enabled) : true,
            mode: 'keyboard',
            key_name: pt.key_name || 'ArrowRight',
            key_code: pt.key_code ?? null,
        },
        sound_enabled: rawSettings.sound_enabled !== undefined ? Boolean(rawSettings.sound_enabled) : true,
    };

    const folderInput = $('#capture-folder-input');
    if (folderInput) folderInput.value = captureSettings.save_folder;

    if ($('#reg-x')) $('#reg-x').value = captureSettings.region.x;
    if ($('#reg-y')) $('#reg-y').value = captureSettings.region.y;
    if ($('#reg-w')) $('#reg-w').value = captureSettings.region.width;
    if ($('#reg-h')) $('#reg-h').value = captureSettings.region.height;

    if ($('#capture-interval-range')) $('#capture-interval-range').value = captureSettings.interval_sec;
    if ($('#capture-interval')) $('#capture-interval').value = captureSettings.interval_sec;

    const maxShotsEl = $('#capture-max-shots');
    if (maxShotsEl) {
        maxShotsEl.value = captureSettings.max_shots > 0 ? String(captureSettings.max_shots) : '';
    }

    if ($('#capture-sound-toggle')) {
        $('#capture-sound-toggle').checked = captureSettings.sound_enabled;
    }

    if ($('#page-turn-enabled')) {
        $('#page-turn-enabled').checked = captureSettings.page_turn.enabled;
    }
    const ptBody = $('#page-turn-config-body');
    if (ptBody) {
        ptBody.classList.toggle('is-disabled', !captureSettings.page_turn.enabled);
    }

    refreshKeyRecorderDisplay();
    updateCanvasCoordSummary();
    redrawCaptureCanvas();
}

function collectSettingsFromUI() {
    const saveFolder = ($('#capture-folder-input')?.value || '').trim();
    const rx = clampInt($('#reg-x')?.value, -10000, 20000, captureSettings.region.x);
    const ry = clampInt($('#reg-y')?.value, -10000, 20000, captureSettings.region.y);
    const rw = clampInt($('#reg-w')?.value, 10, 20000, captureSettings.region.width);
    const rh = clampInt($('#reg-h')?.value, 10, 20000, captureSettings.region.height);

    const intervalSec = clampInt($('#capture-interval')?.value, 1, 10, captureSettings.interval_sec);
    const maxRaw = ($('#capture-max-shots')?.value || '').trim();
    const maxShots = maxRaw === '' ? 0 : clampInt(maxRaw, 0, 100000, 0);
    const soundEnabled = $('#capture-sound-toggle') ? Boolean($('#capture-sound-toggle').checked) : true;

    const ptEnabled = $('#page-turn-enabled') ? Boolean($('#page-turn-enabled').checked) : true;
    const keyName = captureSettings.page_turn.key_name || 'ArrowRight';

    const payload = {
        save_folder: saveFolder,
        region: { x: rx, y: ry, width: rw, height: rh },
        interval_sec: intervalSec,
        max_shots: maxShots,
        countdown_sec: clampInt(captureSettings.countdown_sec, 0, 10, 3),
        page_turn: {
            enabled: ptEnabled,
            mode: 'keyboard',
            key_name: keyName,
        },
        sound_enabled: soundEnabled,
    };
    return payload;
}

async function saveCaptureSettingsFromUI({ showSavedToast = false } = {}) {
    const payload = collectSettingsFromUI();
    try {
        const res = await API.saveSettings(payload);
        if (res.ok && res.settings) {
            applySettingsToUI(res.settings);
            if (showSavedToast) {
                showToast(escapeAttr(res.message || t('toast_settings_saved')), 'success');
            }
            return true;
        }
        showToast(escapeAttr(res.message || t('toast_settings_error')), 'error');
        return false;
    } catch (err) {
        showToast(t('toast_settings_error'), 'error');
        return false;
    }
}

async function loadCaptureSettings() {
    try {
        const res = await API.getSettings();
        if (res.ok) {
            if (res.settings) applySettingsToUI(res.settings);
            if (res.permissions) renderPermissionBadges(res.permissions);
        }
    } catch (err) {
        // Non-fatal on initial load
    }
}

async function onCaptureFolderCommit() {
    await saveCaptureSettingsFromUI({ showSavedToast: true });
}

function onRegionInputLive() {
    captureSettings.region = {
        x: clampInt($('#reg-x')?.value, -10000, 20000, captureSettings.region.x),
        y: clampInt($('#reg-y')?.value, -10000, 20000, captureSettings.region.y),
        width: clampInt($('#reg-w')?.value, 1, 20000, captureSettings.region.width),
        height: clampInt($('#reg-h')?.value, 1, 20000, captureSettings.region.height),
    };
    updateCanvasCoordSummary();
    redrawCaptureCanvas();
}

async function onRegionInputCommit() {
    const wEl = $('#reg-w');
    const hEl = $('#reg-h');
    if (wEl) wEl.value = clampInt(wEl.value, 10, 20000, 800);
    if (hEl) hEl.value = clampInt(hEl.value, 10, 20000, 600);
    onRegionInputLive();
    await saveCaptureSettingsFromUI();
}

function syncIntervalFromRange(val) {
    const clamped = clampInt(val, 1, 10, 3);
    if ($('#capture-interval')) $('#capture-interval').value = clamped;
    captureSettings.interval_sec = clamped;
}

async function syncIntervalFromNumber(val, commit = false) {
    const clamped = clampInt(val, 1, 10, 3);
    if ($('#capture-interval-range')) $('#capture-interval-range').value = clamped;
    captureSettings.interval_sec = clamped;
    if (commit) {
        if ($('#capture-interval')) $('#capture-interval').value = clamped;
        await saveCaptureSettingsFromUI();
    }
}

async function onMaxShotsCommit() {
    const el = $('#capture-max-shots');
    if (el && el.value.trim() !== '') {
        const v = clampInt(el.value, 0, 100000, 0);
        el.value = v > 0 ? String(v) : '';
    }
    await saveCaptureSettingsFromUI();
}

async function onPageTurnEnabledChange() {
    const checked = $('#page-turn-enabled') ? Boolean($('#page-turn-enabled').checked) : true;
    captureSettings.page_turn.enabled = checked;
    const ptBody = $('#page-turn-config-body');
    if (ptBody) ptBody.classList.toggle('is-disabled', !checked);
    await saveCaptureSettingsFromUI();
}

// ── TCC Permissions ─────────────────────────────────────────────────

function renderPermissionBadges(perms) {
    if (!perms) return;
    lastPermissions = perms;

    const applyBadge = (el, val) => {
        if (!el) return;
        el.className = 'perm-badge';
        if (val === true) {
            el.classList.add('perm-granted');
            el.textContent = t('perm_granted');
        } else if (val === false) {
            el.classList.add('perm-missing');
            el.textContent = t('perm_missing');
        } else {
            el.classList.add('perm-unknown');
            el.textContent = t('perm_unknown');
        }
    };

    applyBadge($('#perm-screen-badge'), perms.screen_recording);
    applyBadge($('#perm-access-badge'), perms.accessibility);
}

async function requestCapturePermissions(prompt = true) {
    const btn = $('#btn-check-permissions');
    if (btn) btn.disabled = true;
    try {
        const res = await API.checkPermissions(prompt);
        if (res.ok && res.permissions) {
            renderPermissionBadges(res.permissions);
            showToast(t('toast_permissions_updated'), 'info');
        } else {
            showToast(escapeAttr(res.message || t('toast_permissions_error')), 'error');
        }
    } catch (err) {
        showToast(t('toast_permissions_error'), 'error');
    } finally {
        if (btn) btn.disabled = false;
    }
}

// ── Screen Overlay Picker (Mode 1) & Preview Screen (Mode 2) ────────

async function pickOverlay(target = 'region') {
    const btn = $('#btn-pick-region-overlay');
    if (btn) btn.disabled = true;
    try {
        const res = await API.pickOverlay(target);
        if (res.ok) {
            if (res.settings) {
                applySettingsToUI(res.settings);
            } else {
                if (res.region) {
                    captureSettings.region = { ...captureSettings.region, ...res.region };
                }
                applySettingsToUI(captureSettings);
            }
            showToast(t('toast_overlay_region_set'), 'success');
        } else if (res.cancelled) {
            showToast(escapeAttr(res.message || t('toast_overlay_cancelled')), 'info');
        } else {
            showToast(escapeAttr(res.message || t('toast_overlay_error')), 'error');
        }
    } catch (err) {
        showToast(t('toast_overlay_error'), 'error');
    } finally {
        if (btn) btn.disabled = false;
    }
}

async function capturePreviewScreen(delaySec = 0.2) {
    const btnNow = $('#btn-capture-preview');
    const btnDelay = $('#btn-capture-preview-delay');
    if (btnNow) btnNow.disabled = true;
    if (btnDelay) btnDelay.disabled = true;

    if (delaySec >= 1.5) {
        showToast(t('toast_preview_delay', { sec: Math.round(delaySec) }), 'info', 2200);
    }

    try {
        const res = await API.previewScreen(delaySec);
        if (!res.ok) {
            if (res.permissions) renderPermissionBadges(res.permissions);
            showToast(escapeAttr(res.message || t('toast_preview_failed')), 'error');
            return;
        }

        const img = new Image();
        img.onload = () => {
            previewMeta = {
                screen_width: Number(res.screen_width) || img.naturalWidth,
                screen_height: Number(res.screen_height) || img.naturalHeight,
                image_width: Number(res.image_width) || img.naturalWidth,
                image_height: Number(res.image_height) || img.naturalHeight,
                scale_factor: Number(res.scale_factor) || 1,
                origin_x: Number(res.origin_x) || 0,
                origin_y: Number(res.origin_y) || 0,
            };
            previewImageObj = img;

            const scaleBadge = $('#canvas-scale-badge');
            if (scaleBadge) {
                const sf = Number.isInteger(previewMeta.scale_factor)
                    ? `${previewMeta.scale_factor}x`
                    : `${previewMeta.scale_factor.toFixed(1)}x`;
                scaleBadge.textContent = `${previewMeta.screen_width}×${previewMeta.screen_height} pt • ${sf}`;
            }

            const emptyHint = $('#canvas-empty-hint');
            const canvas = $('#capture-canvas');
            if (emptyHint) emptyHint.style.display = 'none';
            if (canvas) {
                canvas.style.display = 'block';
                canvas.width = previewMeta.image_width;
                canvas.height = previewMeta.image_height;
            }

            requestAnimationFrame(() => {
                fitCanvasToStage();
                redrawCaptureCanvas();
            });
            showToast(t('toast_preview_ready'), 'success');
        };
        img.onerror = () => {
            showToast(t('toast_preview_failed'), 'error');
        };
        img.src = res.image_url;
    } catch (err) {
        showToast(t('toast_preview_failed'), 'error');
    } finally {
        if (btnNow) btnNow.disabled = false;
        if (btnDelay) btnDelay.disabled = false;
    }
}

// ── Interactive Canvas Rendering & Pointer Math ─────────────────────

function updateCanvasCoordSummary() {
    const el = $('#canvas-coord-summary');
    if (!el) return;
    const reg = captureSettings.region;
    el.textContent = t('canvas_coord_summary', {
        x: reg.x,
        y: reg.y,
        w: reg.width,
        h: reg.height,
    });
}

function fitCanvasToStage() {
    const stage = $('#capture-canvas-stage');
    const canvas = $('#capture-canvas');
    if (!stage || !canvas || !previewMeta || canvas.style.display === 'none') return;

    const availW = Math.max(80, stage.clientWidth - 24);
    const availH = Math.max(80, stage.clientHeight - 24);
    const scale = Math.min(availW / previewMeta.image_width, availH / previewMeta.image_height);

    const dispW = Math.max(40, Math.floor(previewMeta.image_width * scale));
    const dispH = Math.max(40, Math.floor(previewMeta.image_height * scale));
    canvas.style.width = `${dispW}px`;
    canvas.style.height = `${dispH}px`;
}

function canvasEventToLogical(e) {
    const canvas = $('#capture-canvas');
    const rect = canvas.getBoundingClientRect();
    const pxX = (e.clientX - rect.left) * (previewMeta.image_width / rect.width);
    const pxY = (e.clientY - rect.top) * (previewMeta.image_height / rect.height);
    const logicalX = Math.round(previewMeta.origin_x + pxX / previewMeta.scale_factor);
    const logicalY = Math.round(previewMeta.origin_y + pxY / previewMeta.scale_factor);

    const minX = previewMeta.origin_x;
    const maxX = previewMeta.origin_x + previewMeta.screen_width;
    const minY = previewMeta.origin_y;
    const maxY = previewMeta.origin_y + previewMeta.screen_height;

    return {
        x: Math.max(minX, Math.min(maxX, logicalX)),
        y: Math.max(minY, Math.min(maxY, logicalY)),
    };
}

function drawRoundedRectPill(ctx, x, y, w, h, r) {
    const radius = Math.min(r, w / 2, h / 2);
    ctx.beginPath();
    ctx.moveTo(x + radius, y);
    ctx.lineTo(x + w - radius, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + radius);
    ctx.lineTo(x + w, y + h - radius);
    ctx.quadraticCurveTo(x + w, y + h, x + w - radius, y + h);
    ctx.lineTo(x + radius, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - radius);
    ctx.lineTo(x, y + radius);
    ctx.quadraticCurveTo(x, y, x + radius, y);
    ctx.closePath();
}

function redrawCaptureCanvas() {
    const canvas = $('#capture-canvas');
    if (!canvas || !previewImageObj || !previewMeta) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    ctx.clearRect(0, 0, canvas.width, canvas.height);
    ctx.drawImage(previewImageObj, 0, 0, canvas.width, canvas.height);

    const rect = canvas.getBoundingClientRect();
    const drawScale = rect.width > 0 ? previewMeta.image_width / rect.width : previewMeta.scale_factor;
    const isDark = document.documentElement.getAttribute('data-theme') === 'dark';
    const primaryColor = isDark ? '#0a84ff' : '#0066cc';

    // 1. Draw Capture Region Box
    const reg = captureSettings.region;
    const rx = (reg.x - previewMeta.origin_x) * previewMeta.scale_factor;
    const ry = (reg.y - previewMeta.origin_y) * previewMeta.scale_factor;
    const rw = reg.width * previewMeta.scale_factor;
    const rh = reg.height * previewMeta.scale_factor;

    ctx.save();
    ctx.fillStyle = isDark ? 'rgba(10, 132, 255, 0.16)' : 'rgba(0, 102, 204, 0.14)';
    ctx.fillRect(rx, ry, rw, rh);

    ctx.strokeStyle = primaryColor;
    ctx.lineWidth = 2.5 * drawScale;
    ctx.strokeRect(rx, ry, rw, rh);

    // Corner handles
    const handleSize = 7 * drawScale;
    ctx.fillStyle = '#ffffff';
    ctx.strokeStyle = primaryColor;
    ctx.lineWidth = 2 * drawScale;
    const corners = [
        [rx, ry],
        [rx + rw, ry],
        [rx, ry + rh],
        [rx + rw, ry + rh],
    ];
    for (const [hx, hy] of corners) {
        ctx.fillRect(hx - handleSize / 2, hy - handleSize / 2, handleSize, handleSize);
        ctx.strokeRect(hx - handleSize / 2, hy - handleSize / 2, handleSize, handleSize);
    }

    // Region dimensions badge
    const regLabel = `${reg.width}×${reg.height} pt`;
    const fontSize = Math.round(12 * drawScale);
    ctx.font = `600 ${fontSize}px -apple-system, BlinkMacSystemFont, sans-serif`;
    const textW = ctx.measureText(regLabel).width;
    const padX = 8 * drawScale;
    const pillH = 22 * drawScale;
    const pillW = textW + padX * 2;
    const pillX = Math.max(4 * drawScale, Math.min(canvas.width - pillW - 4 * drawScale, rx));
    const pillY = ry - pillH - 6 * drawScale >= 4 * drawScale ? ry - pillH - 6 * drawScale : ry + 6 * drawScale;

    drawRoundedRectPill(ctx, pillX, pillY, pillW, pillH, 6 * drawScale);
    ctx.fillStyle = primaryColor;
    ctx.fill();

    ctx.fillStyle = '#ffffff';
    ctx.textBaseline = 'middle';
    ctx.fillText(regLabel, pillX + padX, pillY + pillH / 2);
    ctx.restore();
}

function initCaptureCanvas() {
    const canvas = $('#capture-canvas');
    const stage = $('#capture-canvas-stage');
    if (!canvas) return;

    canvas.addEventListener('pointerdown', (e) => {
        if (!previewMeta) return;
        const pt = canvasEventToLogical(e);

        // Region drag mode
        isDrawingRegion = true;
        dragStartLogical = pt;
        regionBeforeDrag = { ...captureSettings.region };
        if (canvas.setPointerCapture) {
            try { canvas.setPointerCapture(e.pointerId); } catch (_) {}
        }
    });

    canvas.addEventListener('pointermove', (e) => {
        if (!isDrawingRegion || !previewMeta || !dragStartLogical) return;
        const pt = canvasEventToLogical(e);
        const x = Math.min(dragStartLogical.x, pt.x);
        const y = Math.min(dragStartLogical.y, pt.y);
        const w = Math.abs(pt.x - dragStartLogical.x);
        const h = Math.abs(pt.y - dragStartLogical.y);

        captureSettings.region = {
            x,
            y,
            width: Math.max(10, w),
            height: Math.max(10, h),
        };
        if ($('#reg-x')) $('#reg-x').value = captureSettings.region.x;
        if ($('#reg-y')) $('#reg-y').value = captureSettings.region.y;
        if ($('#reg-w')) $('#reg-w').value = captureSettings.region.width;
        if ($('#reg-h')) $('#reg-h').value = captureSettings.region.height;
        updateCanvasCoordSummary();
        redrawCaptureCanvas();
    });

    const finishRegionDrag = async (e) => {
        if (!isDrawingRegion || !previewMeta || !dragStartLogical) return;
        isDrawingRegion = false;

        const pt = canvasEventToLogical(e);
        const dx = Math.abs(pt.x - dragStartLogical.x);
        const dy = Math.abs(pt.y - dragStartLogical.y);

        if (dx < 5 || dy < 5) {
            // Ignore accidental single click in region mode
            if (regionBeforeDrag) {
                captureSettings.region = { ...regionBeforeDrag };
                if ($('#reg-x')) $('#reg-x').value = captureSettings.region.x;
                if ($('#reg-y')) $('#reg-y').value = captureSettings.region.y;
                if ($('#reg-w')) $('#reg-w').value = captureSettings.region.width;
                if ($('#reg-h')) $('#reg-h').value = captureSettings.region.height;
                updateCanvasCoordSummary();
                redrawCaptureCanvas();
            }
            dragStartLogical = null;
            regionBeforeDrag = null;
            return;
        }

        const x = Math.min(dragStartLogical.x, pt.x);
        const y = Math.min(dragStartLogical.y, pt.y);
        const w = Math.max(10, dx);
        const h = Math.max(10, dy);

        captureSettings.region = { x, y, width: w, height: h };
        if ($('#reg-x')) $('#reg-x').value = x;
        if ($('#reg-y')) $('#reg-y').value = y;
        if ($('#reg-w')) $('#reg-w').value = w;
        if ($('#reg-h')) $('#reg-h').value = h;

        dragStartLogical = null;
        regionBeforeDrag = null;

        updateCanvasCoordSummary();
        redrawCaptureCanvas();
        await saveCaptureSettingsFromUI({ showSavedToast: false });
        showToast(t('toast_region_updated', { x, y, w, h }), 'success');
    };

    canvas.addEventListener('pointerup', finishRegionDrag);
    canvas.addEventListener('pointercancel', finishRegionDrag);

    if (stage && typeof ResizeObserver !== 'undefined') {
        const ro = new ResizeObserver(() => {
            if (activeTab === 'capture') {
                fitCanvasToStage();
                redrawCaptureCanvas();
            }
        });
        ro.observe(stage);
    }

    window.addEventListener('resize', () => {
        if (activeTab === 'capture') {
            fitCanvasToStage();
            redrawCaptureCanvas();
        }
    });
}

// ── Auto Capture Loop Controls ──────────────────────────────────────

function renderCaptureStatus(status) {
    if (!status) return;
    lastCaptureStatus = status;

    const running = Boolean(status.running);
    const phase = status.phase || 'idle';

    // Buttons
    const btnStart = $('#btn-capture-start');
    const btnStop = $('#btn-capture-stop');
    if (btnStart) btnStart.disabled = running;
    if (btnStop) {
        btnStop.disabled = !running;
        btnStop.classList.toggle('is-running', running);
    }

    // Header dot
    const headerDot = $('#header-capture-dot');
    if (headerDot) {
        headerDot.className = 'header-capture-dot';
        if (running && phase === 'countdown') {
            headerDot.classList.add('countdown');
        } else if (running) {
            headerDot.classList.add('active');
        } else if (phase === 'error') {
            headerDot.classList.add('error');
        }
    }

    // Status card dot & phase
    const statusDot = $('#capture-status-dot');
    if (statusDot) {
        statusDot.className = 'capture-status-dot';
        if (phase === 'countdown' || phase === 'capturing' || phase === 'completed' || phase === 'error') {
            statusDot.classList.add(phase);
        }
    }

    const phaseEl = $('#capture-status-phase');
    if (phaseEl) {
        if (phase === 'countdown') {
            phaseEl.textContent = t('phase_countdown', { sec: status.countdown_remaining ?? 0 });
        } else if (phase === 'capturing') {
            phaseEl.textContent = t('phase_capturing');
        } else if (phase === 'completed') {
            phaseEl.textContent = t('phase_completed');
        } else if (phase === 'stopped') {
            phaseEl.textContent = t('phase_stopped');
        } else if (phase === 'error') {
            phaseEl.textContent = t('phase_error');
        } else {
            phaseEl.textContent = t('phase_idle');
        }
    }

    const counterEl = $('#capture-status-counter');
    if (counterEl) {
        const count = Number(status.captured_count || 0);
        const max = Number(status.max_shots || 0);
        counterEl.textContent = max > 0 ? `${count} / ${max}` : `${count} / ∞`;
    }

    const errEl = $('#capture-status-error');
    if (errEl) {
        if (status.last_error) {
            errEl.textContent = status.last_error;
            errEl.style.display = 'block';
        } else {
            errEl.textContent = '';
            errEl.style.display = 'none';
        }
    }
}

function stopStatusPolling() {
    if (statusPollTimer) {
        clearInterval(statusPollTimer);
        statusPollTimer = null;
    }
}

function startStatusPolling() {
    stopStatusPolling();
    statusPollTimer = setInterval(async () => {
        await pollCaptureStatusOnce();
    }, 400);
}

async function pollCaptureStatusOnce() {
    try {
        const res = await API.getCaptureStatus();
        if (!res.ok || !res.status) return;
        const prevRunning = lastCaptureStatus.running;
        renderCaptureStatus(res.status);

        if (prevRunning && !res.status.running) {
            stopStatusPolling();
            if (res.status.phase === 'completed') {
                showToast(t('toast_capture_completed', { count: res.status.captured_count || 0 }), 'success');
            } else if (res.status.phase === 'error') {
                showToast(escapeAttr(res.status.last_error || t('toast_capture_error')), 'error');
            }
        }
    } catch (err) {
        // Ignore transient poll error
    }
}

async function startCapture() {
    const rawW = parseInt($('#reg-w')?.value, 10);
    const rawH = parseInt($('#reg-h')?.value, 10);
    if (isNaN(rawW) || isNaN(rawH) || rawW < 10 || rawH < 10) {
        showToast(t('toast_capture_invalid_region'), 'warning');
        return;
    }

    const payload = collectSettingsFromUI();
    if (!payload.save_folder) {
        showToast(t('toast_capture_folder_required'), 'warning');
        return;
    }

    try {
        const res = await API.startCapture(payload);
        if (res.ok) {
            if (res.settings) applySettingsToUI(res.settings);
            if (res.permissions) renderPermissionBadges(res.permissions);
            if (res.status) renderCaptureStatus(res.status);

            if (res.accessibility_warning || (payload.page_turn.enabled && res.permissions && res.permissions.accessibility === false)) {
                showToast(escapeAttr(res.accessibility_warning || t('toast_accessibility_needed')), 'warning', 5500);
            } else {
                showToast(escapeAttr(res.message || t('toast_capture_started')), 'success');
            }
            startStatusPolling();
        } else {
            showToast(escapeAttr(res.message || t('toast_capture_error')), 'error');
        }
    } catch (err) {
        showToast(t('toast_capture_error'), 'error');
    }
}

async function stopCapture() {
    try {
        const res = await API.stopCapture();
        stopStatusPolling();
        if (res.ok) {
            if (res.status) renderCaptureStatus(res.status);
            showToast(escapeAttr(res.message || t('toast_capture_stopped')), 'info');
        } else {
            showToast(escapeAttr(res.message || t('toast_capture_error')), 'error');
        }
    } catch (err) {
        showToast(t('toast_capture_error'), 'error');
    }
}

// ── Keyboard shortcuts ──────────────────────────────────────────────

document.addEventListener('keydown', (e) => {
    if (document.activeElement && document.activeElement.id === 'key-recorder-input') {
        return;
    }

    const imageModal = $('#image-modal');
    const isImageModalOpen = imageModal && imageModal.style.display !== 'none' && !imageModal.classList.contains('closing');

    if (isImageModalOpen) {
        if (e.key === 'ArrowDown' || e.key === 'ArrowRight') {
            e.preventDefault();
            navigateImage(1);
            return;
        }
        if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') {
            e.preventDefault();
            navigateImage(-1);
            return;
        }
    }

    if (e.key === 'Escape') {
        closeBrowser();
        closeConfirmModal();
        closeImageModal();
    }
});

// ── Theme Switching ─────────────────────────────────────────────────

function toggleTheme() {
    const current = document.documentElement.getAttribute('data-theme');
    const target = current === 'dark' ? 'light' : 'dark';
    document.documentElement.setAttribute('data-theme', target);
    localStorage.setItem('user_theme', target);
    redrawCaptureCanvas();
    showToast(t('toast_theme_change', { theme: target === 'dark' ? t('theme_dark') : t('theme_light') }));
}

function initTheme() {
    const saved = localStorage.getItem('user_theme');
    if (saved) {
        document.documentElement.setAttribute('data-theme', saved);
    } else if (window.matchMedia && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        document.documentElement.setAttribute('data-theme', 'dark');
    }
}

initTheme();

// ── Init ────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', async () => {
    const headerLangSelect = document.getElementById('header-lang-select');
    if (headerLangSelect) {
        headerLangSelect.value = currentLang;
    }
    document.documentElement.setAttribute('lang', currentLang);

    updateDOMTranslations();
    renderEmptyState();
    initResizer();
    loadNotes();
    initKeyRecorder();
    initCaptureCanvas();

    await loadCaptureSettings();
    await pollCaptureStatusOnce();
    if (lastCaptureStatus.running) {
        startStatusPolling();
    }
});
