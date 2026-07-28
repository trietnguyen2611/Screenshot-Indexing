// ── Screenshot Index — Frontend Logic ───────────────────────────────

const API = {
    chooseFolder: () => fetch('/api/choose-folder', { method: 'POST' }).then(r => r.json()),
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

// ── DOM Helpers ─────────────────────────────────────────────────────

const $ = (sel) => document.querySelector(sel);
const $$ = (sel) => document.querySelectorAll(sel);

// ── Toast ───────────────────────────────────────────────────────────

function showToast(message, duration = 2500) {
    const toast = $('#toast');
    toast.textContent = message;
    toast.classList.add('show');
    setTimeout(() => toast.classList.remove('show'), duration);
}

// ── Status ──────────────────────────────────────────────────────────

function setStatus(text, type = '') {
    const statusText = $('#status-text');
    const statusDot = $('#status-dot');

    statusText.textContent = text;
    statusDot.className = 'status-dot';
    if (type) statusDot.classList.add(type);
}

// ── Folder ──────────────────────────────────────────────────────────

async function chooseFolder() {
    const btn = $('#btn-choose-folder');
    btn.disabled = true;

    try {
        const res = await API.chooseFolder();
        if (res.ok) {
            currentFolder = res.folder;
            updateFolderDisplay(res.folder);
            await scanFiles();
        }
    } catch (err) {
        showToast('Lỗi khi chọn thư mục');
    } finally {
        btn.disabled = false;
    }
}

function updateFolderDisplay(folder) {
    const display = $('#folder-display');
    const pathEl = $('#folder-path');

    if (folder) {
        display.classList.add('has-folder');
        pathEl.textContent = folder;
    } else {
        display.classList.remove('has-folder');
        pathEl.textContent = 'Chưa chọn thư mục...';
    }
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
    wrapper.style.display = 'block';

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

// ── Init ────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
    renderEmptyState();
});
