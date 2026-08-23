# Screenshot Indexing

[![Build & Release macOS App](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml)

Ứng dụng hỗ trợ đổi tên đồng loạt các file chụp màn hình (Screenshot) theo thứ tự thời gian chụp (dựa vào số giây ở cuối tên file).

Giao diện được thiết kế theo chuẩn ngôn ngữ thiết kế của Apple (Apple Design System).

---

## 1. Tải ứng dụng (Dành cho người dùng)

Người dùng macOS có thể tải trực tiếp file cài đặt đã được đóng gói sẵn mà không cần cài đặt Python:

- **Cách 1 - Từ GitHub Releases (Khuyên dùng)**:
  - Truy cập mục **[Releases](https://github.com/trietnguyen2611/Screenshot-Indexing/releases)**.
  - Tải file `Screenshot-Indexing-macOS.dmg` hoặc `Screenshot-Indexing-macOS.zip`.
  - Mở file `.dmg` và kéo ứng dụng vào thư mục **Applications** để sử dụng.

- **Cách 2 - Từ GitHub Actions**:
  - Truy cập tab **[Actions](https://github.com/trietnguyen2611/Screenshot-Indexing/actions)** > Chọn build mới nhất.
  - Tải artifact `Screenshot-Indexing-macOS-Packages` ở cuối trang.

---

## 2. Các tính năng chính

- **Sắp xếp tự động**: Tự động sắp xếp các file screenshot từ sớm nhất đến muộn nhất dựa vào thời gian chụp.
- **Đánh số tùy chỉnh**: Nhập phạm vi số bắt đầu và số kết thúc để đổi tên hàng loạt.
- **Xem trước**: Kiểm tra danh sách file trước khi tiến hành đổi tên.
- **Tránh xung đột tên**: Sử dụng cơ chế đổi tên qua file tạm để tránh trùng lặp.
- **Bộ duyệt thư mục**: Hỗ trợ dán đường dẫn trực tiếp hoặc duyệt thư mục qua giao diện.
- **Tự động đóng gói CI/CD**: Tự động build ra ứng dụng macOS (`.app`), file `.dmg`, và `.zip` khi cập nhật code lên GitHub.

---

## 3. Cài đặt và Chạy từ mã nguồn (Dành cho nhà phát triển)

### Bước 1. Khởi tạo môi trường ảo và cài đặt thư viện:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### Bước 2. Chạy ứng dụng:
```bash
python app.py
```

### Bước 3. Tự đóng gói (Build) ứng dụng macOS:
```bash
pyinstaller --noconsole --name "Screenshot Indexing" --icon app_icon.icns --add-data "templates:templates" --add-data "static:static" --noconfirm app.py
```

---

## 4. Cấu trúc dự án

```
Screenshot-Indexing/
├── .github/
│   └── workflows/
│       └── build-and-release.yml # CI/CD tự động build & release
├── app.py                       # Backend Flask & PyWebView
├── app_icon.icns                # Logo / Icon ứng dụng
├── requirements.txt             # Danh sách thư viện Python
├── .gitignore                   # Cấu hình bỏ qua file build & rác
├── templates/
│   └── index.html               # Giao diện HTML
└── static/
    ├── style.css                # CSS thiết kế giao diện
    └── app.js                   # Logic xử lý frontend
```
