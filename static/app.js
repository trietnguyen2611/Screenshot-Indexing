// ── Screenshot Index — Frontend Logic ───────────────────────────────

const API = {
    browse: (path) => fetch('/api/browse', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ path })
    }).then(r => r.json()),
    scanFiles: (folder) => fetch('/api/scan', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ folder })
    }).then(r => r.json()),
    renameFiles: (start, end) => fetch('/api/rename', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ start, end })
    }).then(r => r.json()),
};

// ── State ───────────────────────────────────────────────────────────

let currentFolder = '';
let currentFiles = [];
let browserCurrentPath = '';

// ── DOM Helpers ─────────────────────────────────────────────────────

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

// ── Toast ───────────────────────────────────────────────────────────

function showToast(message, duration = 3000) {
    const toast = $('#toast');
    toast.innerHTML = `
        <svg class="toast-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="10"/>
            <line x1="12" y1="16" x2="12" y2="12"/>
            <line x1="12" y1="8" x2="12.01" y2="8"/>
        </svg>
        <span>${message}</span>
    `;
    toast.classList.add('show');
    clearTimeout(toast._timer);
    toast._timer = setTimeout(() => toast.classList.remove('show'), duration);
}

// ── Status ──────────────────────────────────────────────────────────

function setStatus(text, type = '') {
    const statusText = $('#status-text');
    const statusDot = $('#status-dot');

    statusText.textContent = text;
    statusDot.className = 'status-dot';
    if (type) statusDot.classList.add(type);
}

// ── Folder Input ────────────────────────────────────────────────────

function loadFolder() {
    const input = $('#folder-input');
    const folder = input.value.trim();

    if (!folder) {
        showToast('Vui lòng nhập đường dẫn thư mục');
        return;
    }

    currentFolder = folder;
    scanFiles();
}

// ── Folder Browser Modal ────────────────────────────────────────────

async function openBrowser() {
    const modal = $('#folder-modal');
    modal.style.display = 'flex';
    const startPath = currentFolder || '';
    await browseTo(startPath || undefined);
}

function closeBrowser() {
    $('#folder-modal').style.display = 'none';
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
        showToast('Lỗi khi duyệt thư mục');
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
        showToast('Chưa chọn thư mục');
        return;
    }

    setStatus('Đang quét...', 'info');

    try {
        const res = await API.scanFiles(currentFolder);
        if (res.ok) {
            currentFiles = res.files;
            renderTable(res.files);
            setStatus(`${res.count} file screenshot`, 'success');
            $('#file-count').textContent = `(${res.count})`;
        } else {
            currentFiles = [];
            renderEmptyState();
            setStatus(res.message, 'error');
            $('#file-count').textContent = '';
        }
    } catch (err) {
        showToast('Lỗi khi quét file');
        setStatus('Lỗi kết nối', 'error');
    }
}

async function refreshFiles() {
    if (!currentFolder) {
        showToast('Chưa chọn thư mục');
        return;
    }
    await scanFiles();
    showToast('Đã làm mới danh sách');
}

// ── Table ───────────────────────────────────────────────────────────

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
        return `<tr>
            <td>${f.index}</td>
            <td>${f.name}</td>
            <td>${f.seconds}</td>
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
        showToast('Chưa có file để xem trước');
        return;
    }

    const startNum = parseInt($('#input-start').value);
    const endNum = parseInt($('#input-end').value);

    if (isNaN(startNum) || isNaN(endNum)) {
        showToast('Vui lòng nhập số hợp lệ');
        return;
    }

    if (startNum > endNum) {
        showToast('Số đầu phải nhỏ hơn số cuối');
        return;
    }

    const totalNumbers = endNum - startNum + 1;
    const count = Math.min(currentFiles.length, totalNumbers);

    renderTable(currentFiles.slice(0, count), startNum);
    setStatus(`Xem trước: ${count} file sẽ được đổi tên`, 'info');
}

// ── Rename ──────────────────────────────────────────────────────────

async function renameFiles() {
    if (!currentFiles.length) {
        showToast('Chưa có file để đổi tên');
        return;
    }

    const startNum = parseInt($('#input-start').value);
    const endNum = parseInt($('#input-end').value);

    if (isNaN(startNum) || isNaN(endNum)) {
        showToast('Vui lòng nhập số hợp lệ');
        return;
    }

    if (startNum > endNum) {
        showToast('Số đầu phải nhỏ hơn số cuối');
        return;
    }

    const totalNumbers = endNum - startNum + 1;
    const count = Math.min(currentFiles.length, totalNumbers);

    // Confirmation
    if (!confirm(
        `Bạn có chắc muốn đổi tên ${count} file?\n\n` +
        `Từ: ${currentFiles[0].name}\n  →  ${startNum}.png\n\n` +
        `Đến: ${currentFiles[count - 1].name}\n  →  ${startNum + count - 1}.png`
    )) return;

    const btn = $('#btn-rename');
    btn.disabled = true;
    btn.innerHTML = `<span class="spinner"></span> Đang đổi tên...`;

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
        showToast('Lỗi khi đổi tên');
        setStatus('Lỗi kết nối', 'error');
    } finally {
        btn.disabled = false;
        btn.innerHTML = `
            <svg class="btn-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"/>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"/>
            </svg>
            Đổi tên
        `;
    }
}

// ── Resizer ─────────────────────────────────────────────────────────

function initResizer() {
    const container = $('#split-container');
    const sidebar = $('#sidebar-panel');
    const resizer = $('#resizer-handle');

    if (!container || !sidebar || !resizer) return;

    // Restore saved sidebar width
    const savedWidth = localStorage.getItem('sidebar_width');
    if (savedWidth) {
        const parsed = parseInt(savedWidth, 10);
        if (!isNaN(parsed) && parsed >= 220 && parsed <= 600) {
            sidebar.style.width = `${parsed}px`;
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
        const maxAllowed = Math.min(600, containerWidth - 300);
        let newWidth = startWidth + deltaX;

        newWidth = Math.max(240, Math.min(newWidth, maxAllowed));
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

// ── Keyboard shortcut: Escape to close modal ────────────────────────

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') closeBrowser();
});

// ── Init ────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
    renderEmptyState();
    initResizer();
});
