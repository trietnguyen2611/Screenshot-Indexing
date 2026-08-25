# Screenshot Indexing

[![Build & Release macOS App](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml)

Ứng dụng hỗ trợ sắp xếp và đổi tên hàng loạt file chụp màn hình (Screenshot) theo thứ tự thời gian, được thiết kế theo chuẩn **Apple Design System**.

---

## Tính năng chính

- **Sắp xếp tự động**: Sắp xếp file screenshot theo mốc thời gian chụp chính xác.
- **Đánh số tùy chỉnh**: Nhập phạm vi số bắt đầu và số kết thúc để đổi tên hàng loạt.
- **Xem trước trực quan**: Xem danh sách tên mới và hình ảnh trước khi thực hiện.
- **Tránh xung đột tên**: Cơ chế đổi tên qua file tạm tránh ghi đè dữ liệu.
- **Bộ duyệt thư mục**: Hỗ trợ dán đường dẫn hoặc duyệt thư mục trực tiếp.

---

## Cài đặt & Chạy từ mã nguồn

```bash
# 1. Khởi tạo môi trường ảo và cài đặt thư viện
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 2. Chạy ứng dụng
python app.py
```

---

## Đóng gói ứng dụng (Build macOS App)

```bash
pyinstaller --noconsole --name "Screenshot Indexing" --icon macapp_icon.icns --add-data "templates:templates" --add-data "static:static" --noconfirm app.py
```

---

## Cấu trúc dự án

```
Screenshot-Indexing/
├── .github/workflows/   # CI/CD tự động build & release (Intel & Apple Silicon)
├── app.py               # Backend Flask & PyWebView
├── macapp_icon.icns        # Icon ứng dụng
├── requirements.txt     # Danh sách thư viện
├── templates/           # Giao diện HTML
└── static/              # CSS & JS frontend
```

---

## Khắc phục lỗi không mở được ứng dụng trên macOS (App is damaged)

Khi tải file `.dmg` từ GitHub Release, macOS Gatekeeper có thể chặn ứng dụng và báo lỗi **"Screenshot Indexing is damaged and can't be opened. You should move it to the Trash."** (Ứng dụng bị hỏng và không thể mở).

**Cách khắc phục:**
1. Kéo thả file `Screenshot Indexing.app` từ DMG vào thư mục **Applications** (Ứng dụng).
2. Mở ứng dụng **Terminal** trên máy Mac.
3. Chạy lệnh sau để gỡ bỏ thuộc tính cách ly (Quarantine):
   ```bash
   xattr -cr "/Applications/Screenshot Indexing.app"
   ```
4. Mở lại ứng dụng bình thường.
