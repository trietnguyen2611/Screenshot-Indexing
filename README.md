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
pyinstaller --noconsole --name "Screenshot Indexing" --icon app_icon.icns --add-data "templates:templates" --add-data "static:static" --noconfirm app.py
```

---

## Cấu trúc dự án

```
Screenshot-Indexing/
├── .github/workflows/   # CI/CD tự động build & release (Intel & Apple Silicon)
├── app.py               # Backend Flask & PyWebView
├── app_icon.icns        # Icon ứng dụng
├── requirements.txt     # Danh sách thư viện
├── templates/           # Giao diện HTML
└── static/              # CSS & JS frontend
```
