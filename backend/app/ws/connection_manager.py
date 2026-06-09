import asyncio
from typing import Any

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self.active_connections: set[WebSocket] = set()
        self.connection_context: dict[WebSocket, dict[str, Any]] = {}
        self.loop: asyncio.AbstractEventLoop | None = None

    def attach_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        self.loop = loop

    async def connect(
        self,
        websocket: WebSocket,
        *,
        allowed_device_ids: set[str] | None = None,
        owner_device_ids: set[str] | None = None,
    ) -> None:
        await websocket.accept()
        self.active_connections.add(websocket)
        self.connection_context[websocket] = {
            "allowed_device_ids": allowed_device_ids,
            "owner_device_ids": owner_device_ids,
        }

    def disconnect(self, websocket: WebSocket) -> None:
        self.active_connections.discard(websocket)
        self.connection_context.pop(websocket, None)

    def _can_receive(self, message: dict[str, Any], context: dict[str, Any]) -> bool:
        message_type = message.get("type")
        allowed = context.get("allowed_device_ids")
        if message_type in {"location_update", "geofence_alert"}:
            if allowed is None:
                return True  # None = allow all devices
            device_id = message.get("deviceId")
            return device_id in allowed
        if message_type == "geofence_state_update":
            return allowed is None or bool(allowed)
        return True

    async def broadcast(self, message: dict[str, Any]) -> None:
        stale: list[WebSocket] = []
        for connection in self.active_connections:
            try:
                context = self.connection_context.get(connection, {})
                if self._can_receive(message, context):
                    await connection.send_json(message)
            except Exception:
                stale.append(connection)

        for connection in stale:
            self.disconnect(connection)

    def broadcast_from_thread(self, message: dict[str, Any]) -> None:
        if self.loop is None:
            return
        asyncio.run_coroutine_threadsafe(self.broadcast(message), self.loop)


ws_manager = ConnectionManager()
