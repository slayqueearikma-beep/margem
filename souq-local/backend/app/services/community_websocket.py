"""WebSocket connection manager for community chat."""

from __future__ import annotations

import asyncio
import json
import logging
from collections import defaultdict
from uuid import UUID

from fastapi import WebSocket

logger = logging.getLogger("margem.community.ws")


class CommunityConnectionManager:
    def __init__(self) -> None:
        self._channel_connections: dict[str, set[WebSocket]] = defaultdict(set)
        self._user_channels: dict[str, set[str]] = defaultdict(set)
        self._online_users: dict[str, set[str]] = defaultdict(set)  # city_slug -> user_ids
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket, *, channel_id: UUID, user_id: UUID, city_slug: str) -> None:
        await websocket.accept()
        key = str(channel_id)
        uid = str(user_id)
        async with self._lock:
            self._channel_connections[key].add(websocket)
            self._user_channels[uid].add(key)
            self._online_users[city_slug].add(uid)

    async def disconnect(self, websocket: WebSocket, *, channel_id: UUID, user_id: UUID, city_slug: str) -> None:
        key = str(channel_id)
        uid = str(user_id)
        async with self._lock:
            conns = self._channel_connections.get(key)
            if conns and websocket in conns:
                conns.discard(websocket)
                if not conns:
                    del self._channel_connections[key]
            user_ch = self._user_channels.get(uid)
            if user_ch:
                user_ch.discard(key)
                if not user_ch:
                    del self._user_channels[uid]
                    self._online_users[city_slug].discard(uid)

    def online_count(self, city_slug: str) -> int:
        return len(self._online_users.get(city_slug, set()))

    async def broadcast_channel(self, channel_id: UUID, event: dict) -> None:
        key = str(channel_id)
        payload = json.dumps(event, default=str)
        async with self._lock:
            connections = list(self._channel_connections.get(key, set()))
        stale: list[WebSocket] = []
        for connection in connections:
            try:
                await connection.send_text(payload)
            except Exception:
                stale.append(connection)
        if stale:
            async with self._lock:
                for ws in stale:
                    self._channel_connections[key].discard(ws)


community_ws_manager = CommunityConnectionManager()
