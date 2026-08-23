# Screenshot Indexing

[![Build & Release macOS App](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/trietnguyen2611/Screenshot-Indexing/actions/workflows/build-and-release.yml)

Ứng dụng hỗ trợ đổi tên đồng loạt các file chụp màn hình (Screenshot) theo thứ tự thời gian chụp (dựa vào số giây ở cuối tên file).

Giao diện được thiết kế theo chuẩn ngôn ngữ thiết kế của Apple (Apple Design System).

---

## 1. Tải ứng dụng (Dành cho người dùng)

Truy cập mục **[Releases](https://github.com/trietnguyen2611/Screenshot-Indexing/releases)** để tải bản cài đặt tương ứng với chip máy Mac của bạn:

| Loại máy Mac | File cài đặt khuyên dùng |
| :--- | :--- |
| **Mac Intel** (MacBook/iMac đời cũ dùng chip Intel) | `Screenshot-Indexing-<version>-macOS-Intel.dmg` |
| **Mac Apple Silicon** (M1, M2, M3, M4,...) | `Screenshot-Indexing-<version>-macOS-AppleSilicon.dmg` |

### Hướng dẫn cài đặt:
1. Mở file `.dmg` vừa tải về.
2. Kéo biểu tượng **Screenshot Indexing** vào thư mục **Applications**.
3. **Lưu ý mở app lần đầu (Bỏ qua Gatekeeper macOS)**:
   - Do ứng dụng mã nguồn mở chưa đăng ký chứng chỉ trả phí của Apple, macOS có thể báo *"Không thể mở vì nhà phát triển không xác định"* hoặc *"Ứng dụng bị hỏng"*.
   - **Cách xử lý rất đơn giản**:
     - Mở **Terminal** và chạy lệnh:
       ```bash
       xattr -cr /Applications/"Screenshot Indexing.app"
       ```
     - Hoặc: Vào thư mục **Applications** > **Chuột phải (hoặc nhấn giữ Control + click)** vào **Screenshot Indexing** > Chọn **Open (Mở)** > Bấm **Open** thêm một lần nữa.

---

## 2. Các tính năng chính

- **Sắp xếp tự động**: Tự động sắp xếp các file screenshot từ sớm nhất đến muộn nhất dựa vào thời gian chụp.
- **Đánh số tùy chỉnh**: Nhập phạm vi số bắt đầu và số kết thúc để đổi tên hàng loạt.
- **Xem trước**: Kiểm tra danh sách file trước khi tiến hành đổi tên.
- **Tránh xung đột tên**: Sử dụng cơ chế đổi tên qua file tạm để tránh trùng lặp.
- **Bộ duyệt thư mục**: Hỗ trợ dán đường dẫn trực tiếp hoặc duyệt thư mục qua giao diện.
- **Tự động đóng gói CI/CD**: Tự động build ra ứng dụng native riêng cho cả **Intel** và **Apple Silicon** khi cập nhật code lên GitHub.

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

### Bước 3. Tự đóng gói (Build) ứng dụng macOS cục bộ:
```bash
APP_VERSION="1.0.0" pyinstaller --noconsole --name "Screenshot Indexing" --icon app_icon.icns --add-data "templates:templates" --add-data "static:static" --noconfirm app.py
```

---

## 4. Cách phát hành phiên bản mới (Release & Versioning)

Khi muốn ra mắt một phiên bản mới (ví dụ: `v1.0.2`):

### Cách 1. Dùng Git Tag (Đơn giản nhất):
```bash
git tag v1.0.2
git push origin v1.0.2
```
> GitHub Actions sẽ tự động kích hoạt 2 luồng build song song cho **Intel** và **Apple Silicon**, sau đó phát hành cả 2 file `.dmg` lên mục **Releases**.

### Cách 2. Kích hoạt thủ công từ GitHub Actions:
1. Vào tab **Actions** trên GitHub.
2. Chọn workflow **Build & Release macOS App**.
3. Bấm nút **Run workflow** và nhập phiên bản (ví dụ: `v1.0.2`).

---

## 5. Cấu trúc dự án

```
Screenshot-Indexing/
├── .github/
│   └── workflows/
│       └── build-and-release.yml # CI/CD tự động build cho Intel & Apple Silicon
├── app.py                       # Backend Flask & PyWebView
├── app_icon.icns                # Logo / Icon ứng dụng
├── requirements.txt             # Danh sách thư viện Python
├── .gitignore                   # Cấu hình bỏ qua file build & rác
├── templates/
│   └── index.html               # Giao diện HTML (hiển thị version)
└── static/
    ├── style.css                # CSS thiết kế giao diện
    └── app.js                   # Logic xử lý frontend
```
