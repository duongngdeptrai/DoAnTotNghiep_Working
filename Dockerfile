FROM python:3.12-slim

WORKDIR /app

COPY backend/requirements.txt ./requirements.txt
COPY backend/app ./app
COPY backend/__init__.py ./__init__.py

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
