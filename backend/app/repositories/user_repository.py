from time import time
from bson import ObjectId
from pymongo.errors import DuplicateKeyError

from app.db.mongo import mongo_manager


class UserRepository:
    def __init__(self) -> None:
        self.collection = mongo_manager.get_collection("users")

    def _normalize_email(self, email: str) -> str:
        return email.strip().lower()

    def create_user(self, email: str, password_hash: str) -> dict:
        now = int(time())
        payload = {
            "email": self._normalize_email(email),
            "passwordHash": password_hash,
            "createdAt": now,
        }
        try:
            result = self.collection.insert_one(payload)
        except DuplicateKeyError as exc:
            raise ValueError("email_exists") from exc
        payload["_id"] = result.inserted_id
        return payload

    def get_by_email(self, email: str) -> dict | None:
        return self.collection.find_one({"email": self._normalize_email(email)})

    def get_by_id(self, user_id: str) -> dict | None:
        try:
            object_id = ObjectId(user_id)
        except Exception:
            return None
        return self.collection.find_one({"_id": object_id})
