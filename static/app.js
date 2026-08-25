// ── Screenshot Index — Frontend Logic ───────────────────────────────

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
};

// ── i18n ────────────────────────────────────────────────────────────
const translations = {
    en: {
        desc: "Batch rename screenshot files chronologically",
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
        btn_rename: "Rename"
    },
    vi: {
        desc: "Đổi tên đồng loạt file screenshot theo thứ tự thời gian",
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
        btn_renaming: "${t('btn_renaming')}",
        toast_rename_error: "Lỗi khi đổi tên",
        toast_theme_change: "Đã chuyển sang Giao diện {theme}",
        theme_dark: "Tối",
        theme_light: "Sáng",
        btn_rename: "Đổi tên"
    }
};

let currentLang = localStorage.getItem('user_lang') || 'en';

function t(key, vars = {}) {
    let str = translations[currentLang][key] || key;
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
    
    const langSelect = document.getElementById('lang-select');
    if (langSelect && langSelect.value !== currentLang) {
        langSelect.value = currentLang;
    }
}

function setLanguage(lang) {
    if (lang !== 'en' && lang !== 'vi') return;
    currentLang = lang;
    localStorage.setItem('user_lang', currentLang);
    document.documentElement.setAttribute('lang', currentLang);
    updateDOMTranslations();
}

// ── State ───────────────────────────────────────────────────────────

let currentFolder = '';
let currentFiles = [];
let browserCurrentPath = '';
let currentImageIndex = -1;

// ── DOM Helpers ─────────────────────────────────────────────────────

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

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

async function openBrowser() {
    const modal = $('#folder-modal');
    modal.classList.remove('closing');
    modal.style.display = 'flex';
    const startPath = currentFolder || '';
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
            showToast(res.message);
            return;
        }

        browserCurrentPath = res.current;
        $('#modal-current-path').textContent = res.current;
        $('#btn-parent').style.display = res.parent ? 'inline-flex' : 'none';

        const list = $('#modal-dir-list');
        if (res.dirs.length === 0) {
            list.innerHTML = '<div class="modal-empty">Không có thư mục con</div>';
        } else {
            list.innerHTML = res.dirs.map(dir => `
                <div class="dir-item" onclick="browseTo('${(res.current + '/' + dir).replace(/'/g, "\\'")}')">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
                        stroke-linecap="round" stroke-linejoin="round">
                        <path d="M22 19a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h5l2 3h9a2 2 0 0 1 2 2z"/>
                    </svg>
                    ${dir}
                </div>
            `).join('');
        }
    } catch (err) {
        showToast(t('toast_error_browse'));
    }
}

async function browseParent() {
    const res = await API.browse(browserCurrentPath);
    if (res.ok && res.parent) {
        await browseTo(res.parent);
    }
}

function selectFolder() {
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
            setStatus(t('status_file_count', {count: res.count}), 'success');
            $('#file-count').textContent = `(${res.count})`;
        } else {
            currentFiles = [];
            renderEmptyState();
            setStatus(res.message, 'error');
            $('#file-count').textContent = '';
        }
    } catch (err) {
        showToast(t('toast_scan_error'));
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

function escapeAttr(str) {
    return String(str)
        .replace(/&/g, '&amp;')
        .replace(/"/g, '&quot;')
        .replace(/'/g, '&#39;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;');
}

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

    tbody.innerHTML = files.map((f, i) => {
        const newName = startNum !== null ? `${startNum + i}.png` : '—';
        const newNameClass = startNum !== null ? '' : 'style="color: var(--color-ink-muted-48); font-weight: 400;"';
        const attrName = escapeAttr(f.name);
        return `<tr class="clickable-row" data-filename="${attrName}" onclick="handleRowClick(this)" title="Click để xem trước ảnh">
            <td>${f.index}</td>
            <td>
                <div class="filename-cell">
                    <svg class="file-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <rect x="3" y="3" width="18" height="18" rx="2" ry="2"/>
                        <circle cx="8.5" cy="8.5" r="1.5"/>
                        <polyline points="21 15 16 10 5 21"/>
                    </svg>
                    <span>${f.name}</span>
                </div>
            </td>
            <td ${newNameClass}>${newName}</td>
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
    setStatus(t('status_preview', {count: count}), 'info');
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

    $('#confirm-count-text').textContent = t('confirm_rename_count', {count: count});
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
    btn.innerHTML = `<span class="spinner"></span> ${t('btn_renaming')}`;

    try {
        const res = await API.renameFiles(startNum, endNum);
        if (res.ok) {
            showToast(res.message);
            setStatus(res.message, 'success');
            currentFiles = [];
            renderEmptyState();
            $('#file-count').textContent = '';
        } else {
            showToast(res.message);
            setStatus(res.message, 'error');
        }
    } catch (err) {
        showToast(t('toast_rename_error'));
        setStatus(t('status_conn_error'), 'error');
    } finally {
        btn.disabled = false;
        btn.innerHTML = `
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
            </svg>
            ${t('btn_rename')}
        `;
    }
}

// ── Resizer ─────────────────────────────────────────────────────────

function initResizer() {
    const container = $('#split-container');
    const sidebar = $('#sidebar-panel');
    const resizer = $('#resizer-handle');

    if (!container || !sidebar || !resizer) return;

    const getMinWidth = () => {
        const containerWidth = container.getBoundingClientRect().width;
        return Math.max(260, Math.round(containerWidth * 0.25));
    };

    // Restore saved sidebar width
    const savedWidth = localStorage.getItem('sidebar_width');
    const minWidth = getMinWidth();
    if (savedWidth) {
        const parsed = parseInt(savedWidth, 10);
        if (!isNaN(parsed) && parsed >= minWidth && parsed <= 650) {
            sidebar.style.width = `${parsed}px`;
        } else {
            sidebar.style.width = `${minWidth}px`;
        }
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
        const minAllowed = Math.max(260, Math.round(containerWidth * 0.25)); // Limit at 2.5:7.5 ratio (min 25%)
        const maxAllowed = Math.min(650, containerWidth - 350);
        let newWidth = startWidth + deltaX;

        newWidth = Math.max(minAllowed, Math.min(newWidth, maxAllowed));
        sidebar.style.width = `${newWidth}px`;
    };

    const onPointerUp = () => {
        if (!isDragging) return;
        isDragging = false;
        resizer.classList.remove('dragging');
        document.body.style.cursor = '';
        document.body.style.userSelect = '';

        document.removeEventListener('pointermove', onPointerMove);
        document.removeEventListener('pointerup', onPointerUp);

        localStorage.setItem('sidebar_width', sidebar.offsetWidth.toString());
    };

    resizer.addEventListener('pointerdown', onPointerDown);
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

    // Highlight active row in table and scroll into view
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

// ── Keyboard shortcuts ──────────────────────────────────────────────

document.addEventListener('keydown', (e) => {
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
    showToast(t('toast_theme_change', {theme: target === 'dark' ? t('theme_dark') : t('theme_light')}));
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

document.addEventListener('DOMContentLoaded', () => {
    const langSelect = document.getElementById('lang-select');
    if (langSelect) {
        langSelect.value = currentLang;
    }
    updateDOMTranslations();
    renderEmptyState();
    initResizer();
    loadNotes();
});
