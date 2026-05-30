# ⚙️ Thông tin cần điền khi tạo Web Service trên Render

> Copy thông tin bên dưới và điền vào form Render theo từng ô

---

## 📋 Thông tin chính

| Trường | Giá trị cần điền |
|--------|------------------|
| **Name** | `child-tracking-backend` |
| **Region** | `Singapore` |
| **Root Directory** | `backend` |
| **Runtime** | `Python 3` (hoặc `Python 3.12`) |
| **Branch** | `main` |
| **Build Command** | `pip install --only-binary=:all: -r requirements.txt` |
| **Start Command** | `uvicorn app.main:app --host 0.0.0.0 --port $PORT` |
| **Plan** | `Free` ($0/tháng) |

---

## 🔐 Environment Variables

Click **"Add Environment Variable"** và thêm lần lượt các biến sau:

### 🔴 BẮT BUỘC

| # | Name | Value |
|---|------|-------|
| 1 | `MONGO_URI` | `mongodb+srv://duongthcsvt7e_db_user:duongthcsvt2912@cluster0.8ansdo1.mongodb.net/child_tracking?appName=Cluster0` |
| 2 | `JWT_SECRET_KEY` | `child-tracking-secret-key-2026-a8f3d9e1b4c7` |

### 🟡 KHUYẾN NGHỊ

| # | Name | Value |
|---|------|-------|
| 3 | `CORS_ORIGINS` | `http://localhost:5173,http://localhost:8080` |
| 4 | `SMTP_USERNAME` | `duongthcsvt7e@gmail.com` |
| 5 | `SMTP_PASSWORD` | *(Gmail App Password của bạn)* |
| 6 | `SMTP_FROM_EMAIL` | `duongthcsvt7e@gmail.com` |

### 🟢 TÙY CHỌN (có thể để trống)

| # | Name | Value |
|---|------|-------|
| 7 | `TELEGRAM_BOT_TOKEN` | *(nếu dùng Telegram)* |
| 8 | `TELEGRAM_CHAT_ID` | *(nếu dùng Telegram)* |

---

## ✅ Checklist trước khi bấm "Deploy Web Service"

- [ ] Source Code: `duongngdeptrai / DoAnTotNghiep_Working`
- [ ] Name: `child-tracking-backend`
- [ ] Region: **Singapore** (không phải Oregon)
- [ ] Root Directory: `backend`
- [ ] Runtime: **Python 3**
- [ ] Build Command: `pip install --only-binary=:all: -r requirements.txt`
- [ ] Start Command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
- [ ] Plan: **Free**
- [ ] Đã thêm `MONGO_URI` vào Environment Variables
- [ ] Đã thêm `JWT_SECRET_KEY` vào Environment Variables

---

## 📝 Sau khi deploy thành công

Backend URL sẽ là:
```
https://child-tracking-backend.onrender.com
```

Test API:
```
https://child-tracking-backend.onrender.com/docs
```

---

> **Lưu ý:** Free plan sẽ ngủ sau 15 phút không có request. Request đầu tiên sau khi ngủ mất ~30s.
