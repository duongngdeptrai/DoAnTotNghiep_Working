import asyncio
from typing import Any

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self.active_connections: set[WebSocket] = set()
        self.loop: asyncio.AbstractEventLoop | None = None

    def attach_loop(self, loop: asyncio.AbstractEventLoop) -> None:
        self.loop = loop

    async def connect(self, websocket: WebSocket) -> None:
        await websocket.accept()
        self.active_connections.add(websocket)

    def disconnect(self, websocket: WebSocket) -> None:
        self.active_connections.discard(websocket)

    async def broadcast(self, message: dict[str, Any]) -> None:
        stale: list[WebSocket] = []
        for connection in self.active_connections:
            try:
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
