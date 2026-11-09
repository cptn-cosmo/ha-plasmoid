#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Tiny Home Assistant mock for developing the plasmoid without a real instance.

    python3 tools/mock_ha.py [--port 8123] [--token TOKEN]

Implements GET /api/, GET /api/states, POST /api/services/<domain>/<service>
and the WebSocket API subset the plasmoid uses (auth, subscribe_events,
get_states, ping). Requires aiohttp.
"""
import argparse
import asyncio
import copy
import datetime
import json

from aiohttp import WSMsgType, web

DEFAULT_TOKEN = "dev-token-0123456789abcdefghij"


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def entity(eid, state, **attrs):
    return {"entity_id": eid, "state": state, "attributes": attrs,
            "last_changed": now(), "last_updated": now(), "context": {"id": "x"}}


STATES = {s["entity_id"]: s for s in [
    entity("light.living_room", "on", friendly_name="Living Room Ceiling", brightness=180,
           supported_color_modes=["brightness"], color_mode="brightness"),
    entity("light.desk", "off", friendly_name="Desk Lamp", brightness=None,
           supported_color_modes=["color_temp", "hs"]),
    entity("light.hallway", "on", friendly_name="Hallway (on/off)", supported_color_modes=["onoff"]),
    entity("switch.coffee", "off", friendly_name="Coffee Machine"),
    entity("input_boolean.guest_mode", "on", friendly_name="Guest Mode"),
    entity("fan.bedroom", "off", friendly_name="Bedroom Fan", percentage=0),
    entity("cover.blinds", "closed", friendly_name="Office Blinds", current_position=0),
    entity("lock.front_door", "locked", friendly_name="Front Door"),
    entity("scene.movie", "unknown", friendly_name="Movie Night"),
    entity("switch.broken", "unavailable", friendly_name="Garage Plug"),
    entity("sensor.temperature", "21.4", friendly_name="Living Room Temperature", unit_of_measurement="°C"),
]}

clients = set()


def authorized(request, token):
    return request.headers.get("Authorization") == f"Bearer {token}"


async def broadcast(old, new):
    for ws, sub_id in list(clients):
        if sub_id is None:
            continue
        msg = {"id": sub_id, "type": "event", "event": {
            "event_type": "state_changed",
            "data": {"entity_id": new["entity_id"], "old_state": old, "new_state": new},
            "origin": "LOCAL", "time_fired": now()}}
        try:
            await ws.send_str(json.dumps(msg))
        except ConnectionResetError:
            pass


async def set_state(eid, state, **attrs):
    old = copy.deepcopy(STATES[eid])
    new = STATES[eid]
    new["state"] = state
    new["attributes"].update(attrs)
    new["last_changed"] = new["last_updated"] = now()
    await broadcast(old, new)
    return new


async def handle_service(domain, service, data):
    eid = data.get("entity_id")
    if eid not in STATES:
        return []
    cur = STATES[eid]["state"]
    if service == "toggle":
        service = "turn_off" if cur in ("on", "open") else "turn_on"
        if domain == "cover":
            return [await set_state(eid, "closed" if cur == "open" else "open")]
    if service == "turn_on":
        attrs = {}
        if "brightness_pct" in data:
            attrs["brightness"] = round(data["brightness_pct"] * 255 / 100)
        elif domain == "light" and STATES[eid]["attributes"].get("brightness") is None \
                and "onoff" not in STATES[eid]["attributes"].get("supported_color_modes", []):
            attrs["brightness"] = 255
        return [await set_state(eid, "on" if domain != "scene" else now(), **attrs)]
    if service == "turn_off":
        attrs = {"brightness": None} if "brightness" in STATES[eid]["attributes"] else {}
        return [await set_state(eid, "off", **attrs)]
    if service in ("lock", "unlock"):
        return [await set_state(eid, "locked" if service == "lock" else "unlocked")]
    return []


def make_app(token):
    async def api_root(request):
        if not authorized(request, token):
            return web.json_response({"message": "401: Unauthorized"}, status=401)
        return web.json_response({"message": "API running."})

    async def api_states(request):
        if not authorized(request, token):
            return web.json_response({"message": "401: Unauthorized"}, status=401)
        return web.json_response(list(STATES.values()))

    async def api_service(request):
        if not authorized(request, token):
            return web.json_response({"message": "401: Unauthorized"}, status=401)
        data = await request.json() if request.can_read_body else {}
        domain, service = request.match_info["domain"], request.match_info["service"]
        print(f"service call: {domain}.{service} {data}", flush=True)
        changed = await handle_service(domain, service, data)
        return web.json_response(changed)

    async def websocket(request):
        ws = web.WebSocketResponse()
        await ws.prepare(request)
        await ws.send_str(json.dumps({"type": "auth_required", "ha_version": "2026.11.0"}))
        entry = [ws, None]
        authed = False
        async for msg in ws:
            if msg.type != WSMsgType.TEXT:
                continue
            data = json.loads(msg.data)
            if not authed:
                if data.get("type") == "auth" and data.get("access_token") == token:
                    authed = True
                    await ws.send_str(json.dumps({"type": "auth_ok", "ha_version": "2026.11.0"}))
                    print("ws: authenticated", flush=True)
                else:
                    await ws.send_str(json.dumps({"type": "auth_invalid", "message": "Invalid access token"}))
                    print("ws: auth_invalid", flush=True)
                    await ws.close()
                continue
            mid, mtype = data.get("id"), data.get("type")
            if mtype == "subscribe_events":
                clients.discard(tuple(entry))
                entry[1] = mid
                clients.add(tuple(entry))
                print(f"ws: subscribed to {data.get('event_type')}", flush=True)
                await ws.send_str(json.dumps({"id": mid, "type": "result", "success": True, "result": None}))
            elif mtype == "get_states":
                await ws.send_str(json.dumps({"id": mid, "type": "result", "success": True,
                                              "result": list(STATES.values())}))
            elif mtype == "ping":
                await ws.send_str(json.dumps({"id": mid, "type": "pong"}))
        clients.discard(tuple(entry))
        print("ws: closed", flush=True)
        return ws

    app = web.Application()
    app.router.add_get("/api/", api_root)
    app.router.add_get("/api/states", api_states)
    app.router.add_post("/api/services/{domain}/{service}", api_service)
    app.router.add_get("/api/websocket", websocket)
    return app


async def ticker():
    """Change the temperature now and then so live updates are visible."""
    while True:
        await asyncio.sleep(10)
        t = float(STATES["sensor.temperature"]["state"])
        await set_state("sensor.temperature", f"{t + 0.1:.1f}")


async def main(port, token):
    runner = web.AppRunner(make_app(token))
    await runner.setup()
    await web.TCPSite(runner, "127.0.0.1", port).start()
    print(f"mock Home Assistant on http://127.0.0.1:{port}  token: {token}", flush=True)
    await ticker()


if __name__ == "__main__":
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--port", type=int, default=8123)
    p.add_argument("--token", default=DEFAULT_TOKEN)
    a = p.parse_args()
    asyncio.run(main(a.port, a.token))
