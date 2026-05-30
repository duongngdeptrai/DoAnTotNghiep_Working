# 🚀 Hướng dẫn Deploy Backend lên Render

> **Backend:** FastAPI + MongoDB + MQTT  
> **Platform:** Render.com (Free Tier)  
> **Database:** MongoDB Atlas (Free Tier)

---

## 📋 Mục lục

1. [Chuẩn bị trước khi bắt đầu](#1-chuẩn-bị-trước-khi-bắt-đầu)
2. [Tạo MongoDB Atlas (Database miễn phí)](#2-tạo-mongodb-atlas-database-miễn-phí)
3. [Push code lên GitHub](#3-push-code-lên-github)
4. [Deploy Backend lên Render](#4-deploy-backend-lên-render)
5. [Cấu hình môi trường (Environment Variables)](#5-cấu-hình-môi-trường-environment-variables)
6. [Kết nối Frontend với Backend](#6-kết-nối-frontend-với-backend)
7. [Kiểm tra sau khi deploy](#7-kiểm-tra-sau-khi-deploy)
8. [Xử lý sự cố thường gặp](#8-xử-lý-sự-cố-thường-gặp)

---

## 1. Chuẩn bị trước khi bắt đầu

### Bạn cần có:
- ✅ Tài khoản GitHub (để lưu code)
- ✅ Tài khoản Gmail (để gửi email thông báo)
- ✅ Tài khoản Telegram (tùy chọn, để nhận thông báo Telegram)

### Kiểm tra file quan trọng trong project:

```
📁 Do An Tot Nghiep/
├── 📁 backend/
│   ├── 📄 render.yaml          ← Đã có sẵn
│   ├── 📄 requirements.txt     ← Đã có sẵn
│   └── 📁 app/
│       ├── 📄 main.py          ← File chính của backend
│       └── 📄 core/
│           └── 📄 config.py    ← Cấu hình môi trường
└── 📄 .gitignore               ← Đã cập nhật
```

---

## 2. Tạo MongoDB Atlas (Database miễn phí)

MongoDB Atlas là dịch vụ cloud hosting MongoDB **MIỄN PHÍ** (M0 Sandbox).

### Bước 2.1: Đăng ký tài khoản

1. Truy cập: [mongodb.com/atlas](https://www.mongodb.com/atlas/database)
2. Click **"Try Free"** → Đăng ký bằng email hoặc Google
3. Xác nhận email qua link gửi đến hộp thư của bạn

### Bước 2.2: Tạo Database Cluster

Sau khi đăng nhập thành công:

1. **Chọn project mặc định** (hoặc tạo project mới tên "Child Tracking")
2. Click nút **"Build a database"** (màu xanh lá)
3. Chọn **"M0 Sandbox"** (Free tier, 512MB storage)
4. Chọn **Region gần nhất**:
   - ⭐ **Singapore** (nếu bạn ở Việt Nam)
   - Hoặc **Sydney**, **Tokyo** cũng được
5. Click **"Create"**

> ⏱️ **Lưu ý:** Việc tạo cluster mất khoảng **3-5 phút**. Bạn sẽ thấy màn hình đợi.

### Bước 2.3: Tạo User quản trị Database

Khi xuất hiện màn hình **"Security Quickstart"**:

1. **Username:** `admin`
2. **Password:** Tạo password mạnh (ví dụ: `ChildTrack2026!`)
   - ⚠️ **QUAN TRỌNG:** Ghi nhớ password này! Bạn sẽ cần sau.
3. Click **"Create User"**

### Bước 2.4: Cho phép truy cập từ mọi IP

Tiếp theo màn hình sẽ hỏi **"Where would you like to connect from?"**:

1. Chọn **"My Local Environment"**
2. Click **"Add My Current IP Address"**
3. Hoặc chọn **"Allow Access from Anywhere"** (0.0.0.0/0)
   - ⚠️ Lưu ý: Chỉ dùng 0.0.0.0/0 cho project học tập/demo
4. Click **"Finish and Close"**

### Bước 2.5: Lấy Connection String (Chuỗi kết nối)

Sau khi tạo xong:

1. Click nút **"Connect"** trên cluster vừa tạo
2. Chọn **"Drivers"**
3. Chọn **"Python"** và version **3.12+** (hoặc mặc định)
4. Copy connection string, ví dụ:

```
mongodb+srv://admin:ChildTrack2026!@cluster0.xxxxx.mongodb.net/?retryWrites=true&w=majority
```

5. **Thêm tên database vào cuối** (thay `?` bằng `/child_tracking?`):

```
mongodb+srv://admin:ChildTrack2026!@cluster0.xxxxx.mongodb.net/child_tracking?retryWrites=true&w=majority
```

> ⚠️ **QUAN TRỌNG:** Đây là thông tin nhạy cảm! Giữ kín connection string này.

---

## 3. Push code lên GitHub

Render sẽ tự động lấy code từ GitHub để deploy, nên bạn cần push code lên GitHub trước.

### Bước 3.1: Tạo Repository trên GitHub

1. Truy cập [github.com](https://github.com) và đăng nhập
2. Click nút **"+"** (góc trên bên phải) → **"New repository"**
3. Điền thông tin:
   - **Repository name:** `child-tracking-system` (hoặc tên bạn thích)
   - **Description:** "Hệ thống theo dõi trẻ em"
   - Chọn **"Private"** (khuyến nghị) hoặc **"Public"**
4. Click **"Create repository"**

### Bước 3.2: Push code lên GitHub

Mở **Terminal** (hoặc Git Bash) và chạy các lệnh sau:

```bash
# 1. Di chuyển vào thư mục project
cd "d:/Do An Tot Nghiep"

# 2. Khởi tạo Git (nếu chưa có)
git init

# 3. Thêm tất cả file vào staging (trừ file trong .gitignore)
git add .

# 4. Kiểm tra xem có file nào bị quên không
git status

# 5. Commit code
git commit -m "Initial commit - backend with Render deployment config"

# 6. Đặt tên branch chính là 'main'
git branch -M main

# 7. Liên kết với GitHub repo (THAY user-name và repo-name của bạn)
git remote add origin https://github.com/user-name/child-tracking-system.git

# 8. Push code lên GitHub
git push -u origin main
```

> 💡 **Nếu bạn dùng VS Code:**
> - Mở Terminal trong VS Code (`Ctrl + `)
> - Chạy các lệnh trên

> 💡 **Nếu lỗi xác thực GitHub:**
> - Vào GitHub → Settings → Developer settings → Personal access tokens
> - Tạo token và dùng token làm password khi push

---

## 4. Deploy Backend lên Render

### Bước 4.1: Đăng ký / Đăng nhập Render

1. Truy cập [render.com](https://render.com)
2. Click **"Get Started"**
3. Chọn **"Sign up with GitHub"** (khuyến nghị)
4. Cho phép Render truy cập GitHub repositories của bạn

### Bước 4.2: Tạo Web Service mới

1. Sau khi đăng nhập, click nút **"New +"** (góc trên bên phải)
2. Chọn **"Web Service"**

   ![Chọn Web Service](https://i.imgur.com/example.png)

### Bước 4.3: Chọn Repository

1. Tìm repository `child-tracking-system` vừa tạo
2. Click **"Connect"** bên cạnh repo đó

### Bước 4.4: Điền thông tin cấu hình

Điền vào các trường như hình dưới đây:

| Trường | Giá trị | Giải thích |
|--------|---------|-----------|
| **Name** | `child-tracking-backend` | Tên dịch vụ, sẽ thành URL |
| **Region** | `Singapore` | Khu vực gần Việt Nam nhất |
| **Branch** | `main` | Nhánh code để deploy |
| **Runtime** | `Python 3` | Ngôn ngữ Python |
| **Build Command** | `pip install -r requirements.txt` | Lệnh cài dependencies |
| **Start Command** | `uvicorn app.main:app --host 0.0.0.0 --port $PORT` | Lệnh chạy server |
| **Plan** | `Free` | Miễn phí |

> 📸 **Giải thích các trường:**
> - **Name:** Đặt `child-tracking-backend` → URL sẽ là `child-tracking-backend.onrender.com`
> - **Region:** Chọn **Singapore** để latency thấp nhất
> - **Build Command:** Render dùng lệnh này để cài thư viện Python
> - **Start Command:** Lệnh khởi động FastAPI server
> - **$PORT:** Render tự động gán port, bạn **KHÔNG** được hardcode port!

### Bước 4.5: Chọn Plan

1. Chọn **"Free"** (0$/tháng)
2. Click **"Create Web Service"**

> ⚠️ **Lưu ý về Free Plan:**
> - Server sẽ **ngủ sau 15 phút không có request**
> - Request đầu tiên sau khi ngủ mất **~30 giây** để "thức dậy"
> - 750 giờ/tháng (đủ cho 1 service chạy 24/7)
> - Nếu cần uptime 24/7 → nâng lên **Starter** ($7/tháng)

---

## 5. Cấu hình môi trường (Environment Variables)

Sau khi tạo Web Service, bạn sẽ vào trang dashboard. Click tab **"Environment"** (bên trái).

Thêm các biến môi trường sau:

### 🔴 BẮT BUỘC (phải có):

| Key | Value | Giải thích |
|-----|-------|-----------|
| `MONGO_URI` | `mongodb+srv://admin:PASSWORD@cluster0.xxx.mongodb.net/child_tracking?retryWrites=true&w=majority` | Connection string từ MongoDB Atlas (Bước 2.5) |
| `JWT_SECRET_KEY` | `random-string-mạnh-ví-dụ-abc123xyz789` | Secret key để mã hóa JWT token |

> ⚠️ **Thay PASSWORD** trong `MONGO_URI` bằng password bạn đặt ở Bước 2.3!

### 🟡 KHuyến nghị (có nên thêm):

| Key | Value | Giải thích |
|-----|-------|-----------|
| `CORS_ORIGINS` | `http://your-frontend.vercel.app` | URL frontend của bạn |
| `SMTP_USERNAME` | `duongthcsvt7e@gmail.com` | Gmail gửi thông báo |
| `SMTP_PASSWORD` | `xxxx xxxx xxxx xxxx` | Gmail App Password |
| `SMTP_FROM_EMAIL` | `duongthcsvt7e@gmail.com` | Email người gửi |
| `TELEGRAM_BOT_TOKEN` | `123456789:ABCdef...` | Token bot Telegram (nếu dùng) |
| `TELEGRAM_CHAT_ID` | `123456789` | Chat ID nhận thông báo |

### 🟢 Tùy chọn (có thể để mặc định):

| Key | Mặc định | Giải thích |
|-----|----------|-----------|
| `APP_NAME` | Child Tracking Backend | Tên ứng dụng |
| `MONGO_DB_NAME` | child_tracking | Tên database |
| `GEOFENCE_CENTER_LAT` | 21.0285 | Vĩ độ trung tâm (HN) |
| `GEOFENCE_CENTER_LNG` | 105.8542 | Kinh độ trung tâm (HN) |
| `GEOFENCE_RADIUS_M` | 100 | Bán kính geofence (mét) |
| `ALERT_COOLDOWN_SEC` | 60 | Thời gian giữa 2 cảnh báo (giây) |
| `DEFAULT_DEVICE_ID` | child_01 | ID thiết bị mặc định |

### Cách thêm Environment Variable:

```
1. Vào trang Render Dashboard → chọn service của bạn
2. Click tab "Environment" (bên trái)
3. Click "Add Environment Variable"
4. Điền Key và Value
5. Click "Save"
6. Làm lại cho đến khi thêm hết tất cả
7. Click "Save Changes" (góc trên bên phải)
8. Render sẽ tự động deploy lại với config mới
```

### 📝 Lưu ý về Gmail App Password:

Nếu dùng Gmail để gửi email, bạn **KHÔNG** dùng password thường. Phải dùng **App Password**:

1. Vào [myaccount.google.com/apppasswords](https://myaccount.google.com/apppasswords)
2. Đăng nhập tài khoản Gmail
3. Chọn **"Mail"** → **"Other (Custom name)"**
4. Đặt tên: `Child Tracking Backend`
5. Click **"Generate"**
6. Copy 16 ký tự password được tạo (ví dụ: `abcd efgh ijkl mnop`)
7. Dùng password này cho `SMTP_PASSWORD`

---

## 6. Kết nối Frontend với Backend

Sau khi backend deploy thành công, bạn sẽ có URL:

```
https://child-tracking-backend.onrender.com
```

### Cập nhật file `.env` của Frontend:

Mở file `frontend/.env` (hoặc tạo mới nếu chưa có):

```env
# URL Backend đã deploy trên Render
VITE_API_URL=https://child-tracking-backend.onrender.com

# Nếu backend chưa deploy xong, tạm dùng local:
# VITE_API_URL=http://localhost:8001
```

### Cập nhật CORS Origins:

Quay lại Render Dashboard → Environment → sửa `CORS_ORIGINS`:

```env
CORS_ORIGINS=https://your-frontend.vercel.app,http://localhost:5173,http://localhost:8080
```

Thay `your-frontend.vercel.app` bằng URL thực tế của frontend sau khi deploy.

---

## 7. Kiểm tra sau khi deploy

### 7.1: Xem Logs (Nhật ký chạy)

1. Vào Render Dashboard → chọn service `child-tracking-backend`
2. Click tab **"Logs"** (bên trái)
3. Xem log để kiểm tra:

**✅ Thành công (log hiển thị):**
```
INFO:     Started server process
INFO:     Waiting for application startup.
INFO:     Connecting to MongoDB...
INFO:     -> MongoDB: mongodb+srv://admin:****@cluster0.xxx.mongodb.net/child_tracking
INFO:     Attaching event loop to WebSocket manager...
INFO:     Initializing services...
INFO:     === STARTUP COMPLETE ===
INFO:     Visit: http://0.0.0.0:8001/docs (Swagger)
INFO:     WebSocket: ws://0.0.0.0:8001/ws
INFO:     Uvicorn running on http://0.0.0.0:8001 (Press CTRL+C to quit)
```

**❌ Thất bại (log hiển thị lỗi):**
```
ERROR:    Failed to connect to MongoDB
Traceback (most recent call last):
  ...
pymongo.errors.ConfigurationError:...
```

### 7.2: Test API bằng trình duyệt

1. Truy cập: `https://child-tracking-backend.onrender.com/docs`
2. Bạn sẽ thấy **Swagger UI** (giao diện test API)
3. Click **"Try it out"** → **"Execute"** trên endpoint bất kỳ

### 7.3: Test đăng ký user

Trong Swagger UI:

1. Tìm endpoint `POST /api/auth/register`
2. Click **"Try it out"**
3. Nhập body:
```json
{
  "email": "test@example.com",
  "password": "password123",
  "full_name": "Nguyễn Văn A"
}
```
4. Click **"Execute"**
5. Nếu trả về status `200` và data user → ✅ Thành công!

### 7.4: Test đăng nhập

1. Tìm endpoint `POST /api/auth/login`
2. Click **"Try it out"**
3. Nhập body:
```json
{
  "email": "test@example.com",
  "password": "password123"
}
```
4. Click **"Execute"**
5. Copy `access_token` từ response
6. Click nút **"Authorize"** (góc trên bên phải Swagger)
7. Dán token vào: `Bearer YOUR_ACCESS_TOKEN`
8. Click **"Authorize"**
9. Bây giờ bạn có thể test các endpoint cần đăng nhập!

---

## 8. Xử lý sự cố thường gặp

### ❌ Lỗi: "ModuleNotFoundError: No module named 'app'"

**Nguyên nhân:** Render không tìm thấy file `main.py` của bạn.

**Cách sửa:**
1. Kiểm tra file structure:
```
backend/
├── render.yaml
├── requirements.txt
└── app/
    ├── main.py        ← Phải có file này
    └── ...
```
2. Start Command phải là:
   ```
   uvicorn app.main:app --host 0.0.0.0 --port $PORT
   ```

### ❌ Lỗi: "MongoDB connection timeout"

**Nguyên nhân:** 
- MongoDB URI sai
- Chưa cho phép IP của Render truy cập MongoDB Atlas

**Cách sửa:**
1. Kiểm tra lại `MONGO_URI` trong Environment Variables
2. Vào MongoDB Atlas → Network Access → Thêm IP `0.0.0.0/0`
3. Hoặc: Network Access → Add IP Address → Current Access IP

### ❌ Lỗi: "CORS policy: No 'Access-Control-Allow-Origin'"

**Nguyên nhân:** Frontend URL chưa được thêm vào `CORS_ORIGINS`

**Cách sửa:**
1. Tìm URL thực tế của frontend (ví dụ: `https://child-tracking.vercel.app`)
2. Vào Render → Environment → sửa `CORS_ORIGINS`
3. Thêm: `https://child-tracking.vercel.app`
4. Click **"Save Changes"**

### ❌ Lỗi: "Service sleeping / cold start"

**Triệu chứng:** Request đầu tiên sau vài phút mất ~30s

**Nguyên nhân:** Free plan ngủ sau 15 phút không có request

**Cách khắc phục:**
- **Miễn phí:** Dùng dịch vụ uptime monitor (ví dụ: [uptimerobot.com](https://uptimerobot.com))
  - Tạo monitor ping URL backend mỗi 5 phút
- **Trả phí:** Nâng plan lên **Starter** ($7/tháng)

### ❌ Lỗi: "Module 'bcrypt' not found"

**Nguyên nhân:** Dependencies chưa được cài đúng

**Cách sửa:**
1. Vào Render → chọn service → **"Manual Deploy"** → **"Clear build cache & deploy"**
2. Hoặc kiểm tra `requirements.txt` có dòng `bcrypt==4.0.1` không

### ❌ Lỗi: "Port already in use" hoặc "Address already in use"

**Nguyên nhân:** Hardcode port thay vì dùng `$PORT`

**Cách sửa:**
- Start Command **PHẢI** là:
  ```
  uvicorn app.main:app --host 0.0.0.0 --port $PORT
  ```
- **KHÔNG** dùng: `--port 8001`

---

## 📊 Tóm tắt Checklist

### Trước khi deploy:
- [ ] MongoDB Atlas đã tạo và có connection string
- [ ] Code đã push lên GitHub
- [ ] File `render.yaml` có trong thư mục `backend/`

### Khi deploy:
- [ ] Tạo Web Service trên Render
- [ ] Chọn đúng region (Singapore)
- [ ] Điền đúng Build Command và Start Command
- [ ] Thêm đủ Environment Variables
- [ ] Lưu `MONGO_URI` đúng (thay password thật)

### Sau khi deploy:
- [ ] Truy cập `/docs` thành công
- [ ] Test API đăng ký/đăng nhập
- [ ] Frontend có thể kết nối backend
- [ ] CORS đã được cấu hình đúng

---

## 🎯 URL quan trọng sau khi deploy

| Thứ gì | URL | Mô tả |
|--------|-----|-------|
| **Backend API** | `https://child-tracking-backend.onrender.com` | API chính |
| **Swagger Docs** | `https://child-tracking-backend.onrender.com/docs` | Giao diện test API |
| **Health Check** | `https://child-tracking-backend.onrender.com/` | Kiểm tra server sống hay không |

---

## 🆘 Cần trợ giúp?

Nếu gặp lỗi không có trong danh sách trên:

1. Vào Render → Logs để xem chi tiết lỗi
2. Copy toàn bộ error message
3. Tìm kiếm lỗi trên Google
4. Hoặc hỏi lại mình với chi tiết lỗi nhé! 😊

---

## 📚 Tài liệu tham khảo

- [Render Docs](https://render.com/docs)
- [FastAPI Deployment](https://fastapi.tiangolo.com/deployment/)
- [MongoDB Atlas Docs](https://www.mongodb.com/docs/atlas/)
- [Uvicorn Docs](https://www.uvicorn.org/)

---

> **Tạo bởi:** Claude Sonnet 4.6  
> **Ngày:** 30/05/2026  
> **Phiên bản:** 1.0
