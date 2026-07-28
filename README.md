# Screenshot Indexing

Ứng dụng web hỗ trợ đổi tên đồng loạt các file chụp màn hình (Screenshot) theo thứ tự thời gian chụp (dựa vào số giây ở cuối tên file).

Giao diện được thiết kế theo chuẩn ngôn ngữ thiết kế của Apple (Apple Design System).

---

## Tính năng chính

- **Sắp xếp tự động**: Tự động sắp xếp các file screenshot từ sớm nhất đến muộn nhất dựa vào thời gian chụp.
- **Đánh số tùy chỉnh**: Nhập phạm vi số bắt đầu và số kết thúc để đổi tên hàng loạt.
- **Xem trước**: Kiểm tra danh sách file trước khi tiến hành đổi tên.
- **Tránh xung đột tên**: Sử dụng cơ chế đổi tên qua file tạm để tránh trùng lặp.
- **Bộ duyệt thư mục**: Hỗ trợ dán đường dẫn trực tiếp hoặc duyệt thư mục qua giao diện web.

---

## Yêu cầu hệ thống

- Python 3.8+

---

## Cài đặt và Chạy ứng dụng

1. **Khởi tạo môi trường ảo và cài đặt thư viện**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -r requirements.txt
   ```

2. **Chạy ứng dụng**:
   ```bash
   python app.py
   ```

3. **Truy cập giao diện web**:
   Mở trình duyệt tại địa chỉ: [http://localhost:5050](http://localhost:5050)

---

## Cấu trúc dự án

```
screenshot-index/
├── app.py              # Flask backend server
├── requirements.txt    # Danh sách thư viện Python
├── .gitignore          # Cấu hình bỏ qua file theo dõi git
├── templates/
│   └── index.html      # Giao diện HTML
└── static/
    ├── style.css       # CSS thiết kế theo Apple Design System
    └── app.js          # Logic xử lý phía frontend
```
