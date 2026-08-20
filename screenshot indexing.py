import os
import re
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
import base64
import io
import unicodedata

# ── Apple Design Tokens ──────────────────────────────────────────────
COLORS = {
    "primary": "#0066cc",
    "primary_focus": "#0071e3",
    "primary_on_dark": "#2997ff",
    "ink": "#1d1d1f",
    "ink_muted_80": "#333333",
    "ink_muted_48": "#7a7a7a",
    "canvas": "#ffffff",
    "canvas_parchment": "#f5f5f7",
    "surface_pearl": "#fafafc",
    "hairline": "#e0e0e0",
    "divider_soft": "#f0f0f0",
    "on_primary": "#ffffff",
    "on_dark": "#ffffff",
    "success": "#34c759",
    "warning": "#ff9500",
    "error": "#ff3b30",
}

FONT_FAMILY = "SF Pro Text, SF Pro Display, system-ui, -apple-system, Helvetica Neue, Arial, sans-serif"

FONTS = {
    "display_lg": (FONT_FAMILY, 20, "bold"),       # Window title area
    "tagline": (FONT_FAMILY, 15, "bold"),           # Section headers
    "body_strong": (FONT_FAMILY, 13, "bold"),       # Bold labels
    "body": (FONT_FAMILY, 13, "normal"),            # Normal text
    "caption": (FONT_FAMILY, 11, "normal"),         # Small text
    "caption_strong": (FONT_FAMILY, 11, "bold"),    # Small bold text
    "button": (FONT_FAMILY, 13, "normal"),          # Button text
    "button_large": (FONT_FAMILY, 14, "normal"),    # Primary CTA
    "fine_print": (FONT_FAMILY, 10, "normal"),      # Status bar
}

# ── SVG Icon Paths (drawn on tk.Canvas) ──────────────────────────────
# Icons are drawn procedurally as they're simple shapes

def draw_folder_icon(canvas, x, y, size=16, color="#1d1d1f"):
    """Draw a folder icon."""
    s = size
    # Folder body
    canvas.create_rectangle(x, y + s*0.2, x + s, y + s*0.9,
                            outline=color, width=1.5, fill="")
    # Folder tab
    canvas.create_polygon(
        x, y + s*0.2,
        x, y + s*0.05,
        x + s*0.15, y + s*0.05,
        x + s*0.35, y + s*0.05,
        x + s*0.45, y + s*0.2,
        outline=color, width=1.5, fill=""
    )


def draw_refresh_icon(canvas, x, y, size=16, color="#1d1d1f"):
    """Draw a refresh/reload circular arrow icon."""
    import math
    s = size
    cx, cy = x + s/2, y + s/2
    r = s * 0.38
    # Draw arc (270 degrees)
    canvas.create_arc(cx - r, cy - r, cx + r, cy + r,
                      start=45, extent=270,
                      style="arc", outline=color, width=1.8)
    # Arrow head
    angle = math.radians(45)
    ax = cx + r * math.cos(angle)
    ay = cy - r * math.sin(angle)
    arrow_s = s * 0.15
    canvas.create_polygon(
        ax - arrow_s, ay - arrow_s*0.3,
        ax + arrow_s*0.3, ay - arrow_s,
        ax, ay + arrow_s*0.8,
        fill=color, outline=color
    )


def draw_eye_icon(canvas, x, y, size=16, color="#1d1d1f"):
    """Draw an eye/preview icon."""
    s = size
    cx, cy = x + s/2, y + s/2
    # Eye shape
    canvas.create_oval(cx - s*0.42, cy - s*0.18, cx + s*0.42, cy + s*0.18,
                       outline=color, width=1.5, fill="")
    # Pupil
    canvas.create_oval(cx - s*0.1, cy - s*0.1, cx + s*0.1, cy + s*0.1,
                       outline=color, width=1.2, fill=color)


def draw_rename_icon(canvas, x, y, size=16, color="#ffffff"):
    """Draw a pencil/edit icon."""
    s = size
    # Pencil body (diagonal line)
    canvas.create_line(x + s*0.15, y + s*0.85,
                       x + s*0.75, y + s*0.25,
                       fill=color, width=1.8)
    # Pencil tip
    canvas.create_polygon(
        x + s*0.08, y + s*0.92,
        x + s*0.15, y + s*0.85,
        x + s*0.22, y + s*0.78,
        x + s*0.08, y + s*0.92,
        fill=color, outline=color
    )
    # Top of pencil
    canvas.create_line(x + s*0.72, y + s*0.12,
                       x + s*0.88, y + s*0.28,
                       fill=color, width=1.8)


def draw_hash_icon(canvas, x, y, size=16, color="#1d1d1f"):
    """Draw a hash/number icon."""
    s = size
    # Vertical lines
    canvas.create_line(x + s*0.35, y + s*0.1, x + s*0.3, y + s*0.9,
                       fill=color, width=1.5)
    canvas.create_line(x + s*0.65, y + s*0.1, x + s*0.6, y + s*0.9,
                       fill=color, width=1.5)
    # Horizontal lines
    canvas.create_line(x + s*0.15, y + s*0.35, x + s*0.85, y + s*0.35,
                       fill=color, width=1.5)
    canvas.create_line(x + s*0.15, y + s*0.65, x + s*0.85, y + s*0.65,
                       fill=color, width=1.5)


def draw_list_icon(canvas, x, y, size=16, color="#1d1d1f"):
    """Draw a list/table icon."""
    s = size
    for i, offset in enumerate([0.2, 0.4, 0.6, 0.8]):
        yy = y + s * offset
        # Bullet
        canvas.create_oval(x + s*0.1, yy - s*0.03, x + s*0.16, yy + s*0.03,
                           fill=color, outline=color)
        # Line
        canvas.create_line(x + s*0.25, yy, x + s*0.9, yy,
                           fill=color, width=1.2)


def draw_check_icon(canvas, x, y, size=16, color="#34c759"):
    """Draw a checkmark icon."""
    s = size
    canvas.create_line(
        x + s*0.2, y + s*0.5,
        x + s*0.4, y + s*0.75,
        x + s*0.8, y + s*0.25,
        fill=color, width=2.0, joinstyle="round"
    )


# ── Custom Apple-style Widgets ───────────────────────────────────────

class AppleButton(tk.Canvas):
    """A pill-shaped button following Apple design language."""

    def __init__(self, parent, text, command=None, style="primary",
                 icon_draw_func=None, width=None, **kwargs):
        self.style_name = style
        self.command = command
        self.text = text
        self.icon_draw_func = icon_draw_func
        self._pressed = False

        # Style config
        styles = {
            "primary": {
                "bg": COLORS["primary"],
                "fg": COLORS["on_primary"],
                "active_bg": COLORS["primary_focus"],
                "font": ("SF Pro Text", 13, "normal"),
                "height": 34,
                "padx": 20,
            },
            "secondary": {
                "bg": COLORS["canvas"],
                "fg": COLORS["primary"],
                "active_bg": COLORS["divider_soft"],
                "font": ("SF Pro Text", 13, "normal"),
                "border": COLORS["primary"],
                "height": 34,
                "padx": 20,
            },
            "utility": {
                "bg": COLORS["surface_pearl"],
                "fg": COLORS["ink_muted_80"],
                "active_bg": COLORS["divider_soft"],
                "font": ("SF Pro Text", 12, "normal"),
                "height": 30,
                "padx": 14,
            },
        }

        self.cfg = styles.get(style, styles["primary"])
        h = self.cfg["height"]

        # Calculate width
        if width:
            w = width
        else:
            text_width = len(text) * 8 + self.cfg["padx"] * 2
            if icon_draw_func:
                text_width += 20
            w = max(text_width, 80)

        super().__init__(parent, width=w, height=h,
                         bg=parent.cget("bg") if hasattr(parent, 'cget') else COLORS["canvas"],
                         highlightthickness=0, cursor="hand2", **kwargs)

        self._width = w
        self._height = h
        self._draw()

        self.bind("<Button-1>", self._on_press)
        self.bind("<ButtonRelease-1>", self._on_release)
        self.bind("<Enter>", self._on_enter)
        self.bind("<Leave>", self._on_leave)

    def _draw(self, hover=False):
        self.delete("all")
        w, h = self._width, self._height
        r = h // 2  # Pill radius

        bg = self.cfg["active_bg"] if hover else self.cfg["bg"]
        fg = self.cfg["fg"]

        # Draw pill shape
        self._draw_pill(0, 0, w, h, r, fill=bg,
                        outline=self.cfg.get("border", bg))

        # Icon + Text
        text_x = w // 2
        if self.icon_draw_func:
            icon_size = 14
            total_width = icon_size + 6 + len(self.text) * 7
            icon_x = (w - total_width) // 2
            self.icon_draw_func(self, icon_x, (h - icon_size) // 2,
                                size=icon_size, color=fg)
            text_x = icon_x + icon_size + 6 + len(self.text) * 3.5

        self.create_text(text_x, h // 2, text=self.text,
                         fill=fg, font=self.cfg["font"], anchor="center")

    def _draw_pill(self, x, y, w, h, r, fill, outline):
        """Draw a pill/capsule shape."""
        self.create_arc(x, y, x + 2*r, y + h, start=90, extent=180,
                        fill=fill, outline=outline, width=1)
        self.create_arc(x + w - 2*r, y, x + w, y + h, start=-90, extent=180,
                        fill=fill, outline=outline, width=1)
        self.create_rectangle(x + r, y, x + w - r, y + h,
                              fill=fill, outline=fill)
        # Top and bottom border lines for the middle rect
        self.create_line(x + r, y, x + w - r, y, fill=outline, width=1)
        self.create_line(x + r, y + h, x + w - r, y + h, fill=outline, width=1)

    def _on_press(self, event):
        self._pressed = True
        # Scale effect (Apple's signature micro-interaction)
        self.configure(width=int(self._width * 0.96),
                       height=int(self._height * 0.96))
        self._draw()

    def _on_release(self, event):
        self._pressed = False
        self.configure(width=self._width, height=self._height)
        self._draw()
        if self.command:
            self.command()

    def _on_enter(self, event):
        self._draw(hover=True)

    def _on_leave(self, event):
        self._draw(hover=False)


# ── Main Application ─────────────────────────────────────────────────

class RenameApp:
    def __init__(self, root):
        self.root = root
        self.root.title("Screenshot Index")
        self.root.geometry("800x620")
        self.root.minsize(700, 500)
        self.root.configure(bg=COLORS["canvas_parchment"])

        # Try to set macOS appearance
        try:
            self.root.tk.call("tk::unsupported::MacWindowStyle",
                              "style", self.root._w, "moveableModal", "")
        except:
            pass

        self.screenshot_files = []
        self.folder_path = ""

        self._setup_styles()
        self._build_ui()

    def _setup_styles(self):
        """Configure ttk styles following Apple design."""
        style = ttk.Style()
        style.theme_use("clam")

        # Treeview
        style.configure("Apple.Treeview",
                         background=COLORS["canvas"],
                         foreground=COLORS["ink"],
                         fieldbackground=COLORS["canvas"],
                         font=("SF Pro Text", 12),
                         rowheight=32,
                         borderwidth=0)
        style.configure("Apple.Treeview.Heading",
                         background=COLORS["canvas_parchment"],
                         foreground=COLORS["ink_muted_80"],
                         font=("SF Pro Text", 11, "bold"),
                         borderwidth=0,
                         relief="flat")
        style.map("Apple.Treeview",
                   background=[("selected", "#d6e8ff")],
                   foreground=[("selected", COLORS["ink"])])
        style.map("Apple.Treeview.Heading",
                   background=[("active", COLORS["divider_soft"])])

        # Scrollbar
        style.configure("Apple.Vertical.TScrollbar",
                         gripcount=0,
                         background=COLORS["hairline"],
                         troughcolor=COLORS["canvas"],
                         borderwidth=0,
                         arrowsize=0)

    def _build_ui(self):
        bg = COLORS["canvas_parchment"]

        # ── Header ─────────────────────────────────────────────────
        header = tk.Frame(self.root, bg=COLORS["canvas"], height=56)
        header.pack(fill="x")
        header.pack_propagate(False)

        # Title
        tk.Label(header, text="Screenshot Index",
                 font=("SF Pro Display", 18, "bold"),
                 fg=COLORS["ink"], bg=COLORS["canvas"]
                 ).pack(side="left", padx=24, pady=14)

        # Hairline separator
        tk.Frame(self.root, bg=COLORS["hairline"], height=1).pack(fill="x")

        # ── Content area ───────────────────────────────────────────
        content = tk.Frame(self.root, bg=bg)
        content.pack(fill="both", expand=True, padx=0, pady=0)

        # ── Section: Folder ────────────────────────────────────────
        section_folder = tk.Frame(content, bg=bg)
        section_folder.pack(fill="x", padx=24, pady=(20, 0))

        # Section icon + label
        lbl_frame = tk.Frame(section_folder, bg=bg)
        lbl_frame.pack(fill="x")

        icon_cv = tk.Canvas(lbl_frame, width=18, height=18, bg=bg,
                            highlightthickness=0)
        icon_cv.pack(side="left", padx=(0, 6))
        draw_folder_icon(icon_cv, 1, 1, 16, COLORS["ink_muted_80"])

        tk.Label(lbl_frame, text="Thư mục chứa screenshot",
                 font=("SF Pro Text", 13, "bold"),
                 fg=COLORS["ink"], bg=bg).pack(side="left")

        # Folder row
        folder_row = tk.Frame(section_folder, bg=bg)
        folder_row.pack(fill="x", pady=(8, 0))

        self.var_folder = tk.StringVar(value="Chưa chọn thư mục...")
        entry_frame = tk.Frame(folder_row, bg=COLORS["canvas"],
                               highlightbackground=COLORS["hairline"],
                               highlightthickness=1, bd=0)
        entry_frame.pack(side="left", fill="x", expand=True, ipady=6)

        self.folder_entry = tk.Label(entry_frame, textvariable=self.var_folder,
                                     font=("SF Pro Text", 12),
                                     fg=COLORS["ink_muted_48"],
                                     bg=COLORS["canvas"], anchor="w")
        self.folder_entry.pack(fill="x", padx=12)

        btn_container = tk.Frame(folder_row, bg=bg)
        btn_container.pack(side="right", padx=(12, 0))

        AppleButton(btn_container, "Chọn thư mục", command=self._choose_folder,
                    style="secondary", icon_draw_func=draw_folder_icon
                    ).pack(side="left", padx=(0, 8))

        AppleButton(btn_container, "Làm mới", command=self._refresh_files,
                    style="utility", icon_draw_func=draw_refresh_icon
                    ).pack(side="left")

        # ── Section: Range ─────────────────────────────────────────
        section_range = tk.Frame(content, bg=bg)
        section_range.pack(fill="x", padx=24, pady=(20, 0))

        range_lbl_frame = tk.Frame(section_range, bg=bg)
        range_lbl_frame.pack(fill="x")

        icon_cv2 = tk.Canvas(range_lbl_frame, width=18, height=18, bg=bg,
                             highlightthickness=0)
        icon_cv2.pack(side="left", padx=(0, 6))
        draw_hash_icon(icon_cv2, 1, 1, 16, COLORS["ink_muted_80"])

        tk.Label(range_lbl_frame, text="Phạm vi đánh số",
                 font=("SF Pro Text", 13, "bold"),
                 fg=COLORS["ink"], bg=bg).pack(side="left")

        range_row = tk.Frame(section_range, bg=bg)
        range_row.pack(fill="x", pady=(8, 0))

        # Start number
        tk.Label(range_row, text="Từ", font=("SF Pro Text", 12),
                 fg=COLORS["ink_muted_80"], bg=bg).pack(side="left")

        start_frame = tk.Frame(range_row, bg=COLORS["canvas"],
                               highlightbackground=COLORS["hairline"],
                               highlightthickness=1, bd=0)
        start_frame.pack(side="left", padx=(8, 0), ipady=4)

        self.var_start = tk.StringVar()
        tk.Entry(start_frame, textvariable=self.var_start, width=8,
                 font=("SF Pro Text", 13), fg=COLORS["ink"],
                 bg=COLORS["canvas"], bd=0, highlightthickness=0,
                 justify="center").pack(padx=8)

        # Dash
        tk.Label(range_row, text="—", font=("SF Pro Text", 14),
                 fg=COLORS["ink_muted_48"], bg=bg).pack(side="left", padx=8)

        # End number
        tk.Label(range_row, text="Đến", font=("SF Pro Text", 12),
                 fg=COLORS["ink_muted_80"], bg=bg).pack(side="left")

        end_frame = tk.Frame(range_row, bg=COLORS["canvas"],
                             highlightbackground=COLORS["hairline"],
                             highlightthickness=1, bd=0)
        end_frame.pack(side="left", padx=(8, 0), ipady=4)

        self.var_end = tk.StringVar()
        tk.Entry(end_frame, textvariable=self.var_end, width=8,
                 font=("SF Pro Text", 13), fg=COLORS["ink"],
                 bg=COLORS["canvas"], bd=0, highlightthickness=0,
                 justify="center").pack(padx=8)

        # Preview button
        AppleButton(range_row, "Xem trước", command=self._preview,
                    style="utility", icon_draw_func=draw_eye_icon
                    ).pack(side="right")

        # ── Section: Table ─────────────────────────────────────────
        section_table = tk.Frame(content, bg=bg)
        section_table.pack(fill="both", expand=True, padx=24, pady=(20, 0))

        table_lbl_frame = tk.Frame(section_table, bg=bg)
        table_lbl_frame.pack(fill="x")

        icon_cv3 = tk.Canvas(table_lbl_frame, width=18, height=18, bg=bg,
                             highlightthickness=0)
        icon_cv3.pack(side="left", padx=(0, 6))
        draw_list_icon(icon_cv3, 1, 1, 16, COLORS["ink_muted_80"])

        tk.Label(table_lbl_frame, text="Danh sách file",
                 font=("SF Pro Text", 13, "bold"),
                 fg=COLORS["ink"], bg=bg).pack(side="left")

        self.lbl_count = tk.Label(table_lbl_frame, text="",
                                  font=("SF Pro Text", 11),
                                  fg=COLORS["ink_muted_48"], bg=bg)
        self.lbl_count.pack(side="left", padx=(8, 0))

        # Table container with rounded corners feel
        table_container = tk.Frame(section_table, bg=COLORS["canvas"],
                                   highlightbackground=COLORS["hairline"],
                                   highlightthickness=1, bd=0)
        table_container.pack(fill="both", expand=True, pady=(8, 0))

        columns = ("stt", "old_name", "seconds", "new_name")
        self.tree = ttk.Treeview(table_container, columns=columns,
                                  show="headings", style="Apple.Treeview")
        self.tree.heading("stt", text="#")
        self.tree.heading("old_name", text="Tên gốc")
        self.tree.heading("seconds", text="Giây")
        self.tree.heading("new_name", text="Tên mới")

        self.tree.column("stt", width=40, anchor="center", minwidth=40)
        self.tree.column("old_name", width=400, minwidth=200)
        self.tree.column("seconds", width=60, anchor="center", minwidth=50)
        self.tree.column("new_name", width=120, anchor="center", minwidth=80)

        scrollbar = ttk.Scrollbar(table_container, orient="vertical",
                                   command=self.tree.yview,
                                   style="Apple.Vertical.TScrollbar")
        self.tree.configure(yscrollcommand=scrollbar.set)
        self.tree.pack(side="left", fill="both", expand=True)
        scrollbar.pack(side="right", fill="y")

        # ── Bottom Bar ─────────────────────────────────────────────
        bottom_bar = tk.Frame(self.root, bg=COLORS["canvas"], height=60)
        bottom_bar.pack(fill="x", side="bottom")
        bottom_bar.pack_propagate(False)

        # Top hairline
        tk.Frame(self.root, bg=COLORS["hairline"], height=1).pack(
            fill="x", side="bottom")

        # Status label
        self.lbl_status = tk.Label(bottom_bar, text="Chưa chọn thư mục",
                                    font=("SF Pro Text", 11),
                                    fg=COLORS["ink_muted_48"],
                                    bg=COLORS["canvas"])
        self.lbl_status.pack(side="left", padx=24)

        # Action buttons
        btn_frame = tk.Frame(bottom_bar, bg=COLORS["canvas"])
        btn_frame.pack(side="right", padx=24, pady=12)

        AppleButton(btn_frame, "Làm mới", command=self._refresh_files,
                    style="utility", icon_draw_func=draw_refresh_icon
                    ).pack(side="left", padx=(0, 10))

        AppleButton(btn_frame, "Đổi tên", command=self._rename,
                    style="primary", icon_draw_func=draw_rename_icon
                    ).pack(side="left")

    # ── Logic ────────────────────────────────────────────────────────

    def _choose_folder(self):
        folder = filedialog.askdirectory(title="Chọn thư mục chứa file screenshot")
        if not folder:
            return
        self.folder_path = folder
        self.var_folder.set(folder)
        self.folder_entry.config(fg=COLORS["ink"])
        self._scan_files()

    def _refresh_files(self):
        if not self.folder_path or not os.path.isdir(self.folder_path):
            messagebox.showwarning("Cảnh báo",
                                   "Chưa chọn thư mục hoặc thư mục không tồn tại!")
            return
        self._scan_files()
        self._set_status(
            f"Đã làm mới — {len(self.screenshot_files)} file",
            COLORS["success"])

    def _scan_files(self):
        self.screenshot_files = [
            f for f in os.listdir(self.folder_path)
            if is_screenshot_file(f)
        ]
        self.screenshot_files.sort(key=get_sort_key)

        if not self.screenshot_files:
            self._clear_table()
            self.lbl_count.config(text="")
            self._set_status("Không tìm thấy file screenshot", COLORS["error"])
            return

        count = len(self.screenshot_files)
        self.lbl_count.config(text=f"({count} file)")
        self._set_status(f"Tìm thấy {count} file screenshot", COLORS["success"])

        self._clear_table()
        for i, f in enumerate(self.screenshot_files, 1):
            sec = get_seconds_display(f)
            self.tree.insert("", "end", values=(i, f, sec, "—"))

    def _preview(self):
        if not self.screenshot_files:
            messagebox.showwarning("Cảnh báo",
                                   "Chưa chọn thư mục hoặc không có file screenshot!")
            return

        start_str = self.var_start.get().strip()
        end_str = self.var_end.get().strip()

        if not start_str.isdigit() or not end_str.isdigit():
            messagebox.showwarning("Cảnh báo", "Vui lòng nhập số hợp lệ!")
            return

        start_num = int(start_str)
        end_num = int(end_str)

        if start_num > end_num:
            messagebox.showwarning("Cảnh báo",
                                   "Số đầu phải nhỏ hơn hoặc bằng số cuối!")
            return

        total_numbers = end_num - start_num + 1
        if total_numbers != len(self.screenshot_files):
            messagebox.showinfo(
                "Thông báo",
                f"Có {len(self.screenshot_files)} file nhưng phạm vi có "
                f"{total_numbers} số.\n"
                f"Sẽ đổi tên {min(total_numbers, len(self.screenshot_files))} file."
            )

        self._clear_table()
        count = min(len(self.screenshot_files), total_numbers)
        for i in range(count):
            f = self.screenshot_files[i]
            sec = get_seconds_display(f)
            new_name = f"{start_num + i}.png"
            self.tree.insert("", "end", values=(i + 1, f, sec, new_name))

        self._set_status(f"Xem trước: {count} file sẽ được đổi tên",
                         COLORS["primary"])

    def _rename(self):
        if not self.screenshot_files:
            messagebox.showwarning("Cảnh báo", "Chưa có file để đổi tên!")
            return

        start_str = self.var_start.get().strip()
        end_str = self.var_end.get().strip()

        if not start_str.isdigit() or not end_str.isdigit():
            messagebox.showwarning("Cảnh báo",
                                   "Vui lòng nhập số đầu và số cuối!")
            return

        start_num = int(start_str)
        end_num = int(end_str)

        if start_num > end_num:
            messagebox.showwarning("Cảnh báo",
                                   "Số đầu phải nhỏ hơn hoặc bằng số cuối!")
            return

        total_numbers = end_num - start_num + 1
        count = min(len(self.screenshot_files), total_numbers)

        confirm = messagebox.askyesno(
            "Xác nhận đổi tên",
            f"Bạn có chắc muốn đổi tên {count} file?\n\n"
            f"Từ: {self.screenshot_files[0]}\n"
            f"  →  {start_num}.png\n\n"
            f"Đến: {self.screenshot_files[count - 1]}\n"
            f"  →  {start_num + count - 1}.png"
        )

        if not confirm:
            return

        rename_pairs = []
        for i in range(count):
            old_name = self.screenshot_files[i]
            new_name = f"{start_num + i}.png"
            rename_pairs.append((old_name, new_name))

        # Step 1: Rename to temp names to avoid conflicts
        temp_pairs = []
        for old_name, new_name in rename_pairs:
            temp_name = f"__temp_rename_{new_name}"
            old_path = os.path.join(self.folder_path, old_name)
            temp_path = os.path.join(self.folder_path, temp_name)
            os.rename(old_path, temp_path)
            temp_pairs.append((temp_name, new_name))

        # Step 2: Rename from temp to final names
        success_count = 0
        for temp_name, new_name in temp_pairs:
            temp_path = os.path.join(self.folder_path, temp_name)
            new_path = os.path.join(self.folder_path, new_name)
            if os.path.exists(new_path):
                continue
            os.rename(temp_path, new_path)
            success_count += 1

        self._set_status(
            f"Đã đổi tên {success_count}/{count} file thành công!",
            COLORS["success"])
        messagebox.showinfo(
            "Hoàn tất",
            f"Đã đổi tên {success_count}/{count} file thành công!")

        self.screenshot_files = []
        self._clear_table()
        self.lbl_count.config(text="")

    def _clear_table(self):
        for item in self.tree.get_children():
            self.tree.delete(item)

    def _set_status(self, text, color=None):
        self.lbl_status.config(text=text,
                                fg=color or COLORS["ink_muted_48"])


def is_screenshot_file(filename):
    if not filename.lower().endswith('.png'):
        return False
    norm_nfc = unicodedata.normalize('NFC', filename).lower()
    norm_nfd = unicodedata.normalize('NFD', filename).lower()
    prefixes = ["screenshot", "ảnh màn hình", "anh man hinh"]
    for pref in prefixes:
        pref_nfc = unicodedata.normalize('NFC', pref).lower()
        pref_nfd = unicodedata.normalize('NFD', pref).lower()
        if norm_nfc.startswith(pref_nfc) or norm_nfd.startswith(pref_nfd):
            return True
    return False


def get_sort_key(filename):
    match = re.search(r'(\d+)\.(\d+)\.(\d+)\.\w+$', filename)
    if match:
        hours = int(match.group(1))
        minutes = int(match.group(2))
        seconds = int(match.group(3))
        return hours * 3600 + minutes * 60 + seconds
    return 0


def get_seconds_display(filename):
    match = re.search(r'(\d+)\.(\d+)\.(\d+)\.\w+$', filename)
    if match:
        return match.group(3)
    return "?"


if __name__ == "__main__":
    root = tk.Tk()
    app = RenameApp(root)
    root.mainloop()
