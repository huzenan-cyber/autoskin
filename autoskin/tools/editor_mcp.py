#!/usr/bin/env python3
"""Thin UrhoXEditor MCP CLI for agents (stdlib only).

Does not start the editor. Discovers loopback instances, then:
  status              health + get_editor_state
  tools               names + one-line descriptions
  tools --schema NAME one tool inputSchema
  call NAME [JSON]    tools/call
  wait OP_ID          poll get_operation

Stdout is JSON. Stderr is human diagnostics. Exit 0 ok, 1 error, 2 need --instance.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Any


def instance_dirs() -> list[Path]:
    dirs: list[Path] = []
    local = os.environ.get("LOCALAPPDATA")
    xdg_runtime = os.environ.get("XDG_RUNTIME_DIR")
    home = Path.home()
    if local:
        dirs.append(Path(local) / "UrhoXEditor" / "mcp-instances")
    if xdg_runtime:
        dirs.append(Path(xdg_runtime) / "UrhoXEditor" / "mcp-instances")
    dirs.append(home / ".local" / "share" / "UrhoXEditor" / "mcp-instances")
    dirs.append(home / "Library" / "Application Support" / "UrhoXEditor" / "mcp-instances")
    if local:
        dirs.append(Path(local) / "UrhoX" / "UrhoXEditor" / "mcp-instances")
    seen: set[str] = set()
    out: list[Path] = []
    for d in dirs:
        key = str(d)
        if key not in seen:
            seen.add(key)
            out.append(d)
    return out


def read_json_file(path: Path) -> dict[str, Any]:
    raw = path.read_bytes()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    for encoding in ("utf-8", "utf-8-sig", "gbk", "cp936", "mbcs", "latin-1"):
        try:
            data = json.loads(raw.decode(encoding))
        except (UnicodeDecodeError, json.JSONDecodeError):
            continue
        if isinstance(data, dict):
            return data
    raise ValueError(f"unreadable instance file: {path}")


def load_records() -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    seen: set[str] = set()
    for folder in instance_dirs():
        if not folder.is_dir():
            continue
        for path in sorted(folder.glob("*.json")):
            key = str(path.resolve())
            if key in seen:
                continue
            seen.add(key)
            try:
                data = read_json_file(path)
            except (OSError, ValueError):
                continue
            endpoint = str(data.get("endpoint") or "").rstrip("/")
            if not endpoint:
                continue
            data["_file"] = str(path)
            data["endpoint"] = endpoint
            records.append(data)
    return records


class McpError(RuntimeError):
    def __init__(self, message: str, payload: Any = None):
        super().__init__(message)
        self.payload = payload


class Client:
    def __init__(self, endpoint: str, token: str = "", timeout: float = 30.0):
        self.endpoint = endpoint.rstrip("/")
        self.token = token
        self.timeout = timeout
        self._id = 0

    @property
    def base(self) -> str:
        if self.endpoint.endswith("/mcp"):
            return self.endpoint[: -len("/mcp")]
        return self.endpoint

    def _headers(self, content_type: bool = True) -> dict[str, str]:
        headers = {"Accept": "application/json"}
        if content_type:
            headers["Content-Type"] = "application/json"
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        return headers

    def _http(self, method: str, url: str, body: bytes | None = None) -> Any:
        req = urllib.request.Request(url, data=body, method=method, headers=self._headers(body is not None))
        try:
            with urllib.request.urlopen(req, timeout=self.timeout) as resp:
                raw = resp.read().decode("utf-8", errors="replace")
        except urllib.error.HTTPError as exc:
            raw = exc.read().decode("utf-8", errors="replace")
            raise McpError(f"HTTP {exc.code} {method} {url}: {raw[:400]}", raw) from exc
        except TimeoutError as exc:
            raise McpError(f"connection failed {method} {url}: timed out") from exc
        except urllib.error.URLError as exc:
            raise McpError(f"connection failed {method} {url}: {exc}") from exc
        if not raw:
            return None
        try:
            return json.loads(raw)
        except json.JSONDecodeError as exc:
            raise McpError(f"non-json response: {raw[:400]}") from exc

    def health(self) -> dict[str, Any]:
        for url in (self.base + "/health", self.endpoint):
            try:
                parsed = self._http("GET", url)
            except McpError:
                continue
            if isinstance(parsed, dict):
                return parsed
        raise McpError("no health endpoint responded")

    def rpc(self, method: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        self._id += 1
        payload: dict[str, Any] = {"jsonrpc": "2.0", "id": self._id, "method": method}
        if params is not None:
            payload["params"] = params
        parsed = self._http("POST", self.endpoint, json.dumps(payload, ensure_ascii=False).encode("utf-8"))
        if not isinstance(parsed, dict):
            raise McpError("rpc returned non-object")
        if "error" in parsed:
            raise McpError(f"jsonrpc error: {parsed['error']}", parsed)
        result = parsed.get("result")
        if not isinstance(result, dict):
            raise McpError("rpc missing result object", parsed)
        return result

    def call_tool(self, name: str, arguments: dict[str, Any] | None = None) -> dict[str, Any]:
        result = self.rpc("tools/call", {"name": name, "arguments": arguments or {}})
        envelope = result.get("structuredContent")
        if not isinstance(envelope, dict):
            content = result.get("content") or []
            if content and isinstance(content[0], dict) and isinstance(content[0].get("text"), str):
                try:
                    envelope = json.loads(content[0]["text"])
                except json.JSONDecodeError as exc:
                    raise McpError(f"tools/call {name}: cannot parse content", result) from exc
        if not isinstance(envelope, dict):
            raise McpError(f"tools/call {name}: no envelope", result)
        envelope = dict(envelope)
        envelope["_mcp_isError"] = bool(result.get("isError"))
        return envelope


def emit(data: Any, exit_code: int = 0) -> int:
    json.dump(data, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return exit_code


def fail(message: str, extra: Any = None, exit_code: int = 1) -> int:
    payload: dict[str, Any] = {"ok": False, "error": message}
    if extra is not None:
        payload["detail"] = extra
    print(message, file=sys.stderr)
    return emit(payload, exit_code)


def cli_state_path() -> Path:
    override = (os.environ.get("EDITOR_MCP_STATE") or "").strip()
    if override:
        return Path(override)
    local = os.environ.get("LOCALAPPDATA")
    if local:
        return Path(local) / "UrhoXEditor" / "mcp-cli-state.json"
    return Path.home() / ".local" / "share" / "UrhoXEditor" / "mcp-cli-state.json"


def load_cli_state() -> dict[str, Any]:
    path = cli_state_path()
    if not path.is_file():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    return data if isinstance(data, dict) else {}


def save_cli_state(instance_id: str, endpoint: str) -> None:
    path = cli_state_path()
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps({"editor_instance_id": instance_id, "endpoint": endpoint}, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
    except OSError:
        return


class Session:
    def __init__(self, client: Client, health: dict[str, Any], restarted: bool):
        self.client = client
        self.health = health
        self.restarted = restarted
        self._state: dict[str, Any] | None = None

    @property
    def instance_id(self) -> str:
        return str(self.health.get("editor_instance_id") or "")

    def editor_state(self) -> dict[str, Any]:
        if self._state is None:
            self._state = self.client.call_tool("get_editor_state")
        return self._state

    def scene_ids(self) -> tuple[str, int]:
        state = self.editor_state()
        data = state.get("data") if isinstance(state.get("data"), dict) else state
        if not isinstance(data, dict):
            return "", 0
        generation = str(data.get("scene_generation") or "")
        revision = data.get("scene_revision")
        try:
            rev = int(revision)
        except (TypeError, ValueError):
            rev = 0
        return generation, rev


def stamp(payload: dict[str, Any], session: Session, extra: dict[str, Any] | None = None) -> dict[str, Any]:
    info = {
        "editor_instance_id": session.instance_id,
        "endpoint": session.client.endpoint,
        "editor_restarted": session.restarted,
    }
    if extra:
        info.update(extra)
    payload["_cli"] = info
    return payload


def discover_client(args: argparse.Namespace) -> tuple[Client, dict[str, Any]]:
    if args.endpoint:
        client = Client(args.endpoint, args.token or os.environ.get("EDITOR_MCP_TOKEN") or "", args.timeout)
        return client, client.health()

    env_endpoint = (os.environ.get("EDITOR_MCP_ENDPOINT") or "").strip()
    if env_endpoint and not args.instance:
        client = Client(env_endpoint, args.token or os.environ.get("EDITOR_MCP_TOKEN") or "", args.timeout)
        return client, client.health()

    records = load_records()
    if args.instance:
        records = [rec for rec in records if rec.get("editor_instance_id") == args.instance]
        if not records:
            raise McpError(f"no instance file for {args.instance}")
    else:
        records.sort(
            key=lambda rec: Path(str(rec.get("_file") or "")).stat().st_mtime if rec.get("_file") else 0.0,
            reverse=True,
        )

    alive: list[tuple[Client, dict[str, Any], dict[str, Any]]] = []
    probed_endpoints: set[str] = set()
    for rec in records:
        endpoint = rec["endpoint"]
        if endpoint in probed_endpoints and not args.instance:
            continue
        probed_endpoints.add(endpoint)
        if not args.instance and len(probed_endpoints) > 8:
            break
        probe = Client(endpoint, args.token or str(rec.get("token") or ""), 0.4)
        try:
            health = probe.health()
        except McpError:
            continue
        if health.get("ok") is not True:
            continue
        health_id = str(health.get("editor_instance_id") or "")
        rec_id = str(rec.get("editor_instance_id") or "")
        if health_id and rec_id and health_id != rec_id:
            match = next(
                (
                    item
                    for item in records
                    if item.get("endpoint") == endpoint and item.get("editor_instance_id") == health_id
                ),
                rec,
            )
            rec = match
        token = args.token or str(rec.get("token") or "")
        client = Client(endpoint, token, args.timeout)
        alive.append((client, rec, health))
        if args.instance:
            break

    if not alive:
        raise McpError("No live UrhoXEditor MCP. Start the editor and open a project.")
    if len(alive) > 1 and not args.instance:
        ids = [str(rec.get("editor_instance_id") or "?") for _c, rec, _h in alive]
        raise McpError("Multiple live editors; pass --instance <id>", ids)
    client, _rec, health = alive[0]
    return client, health


def connect(args: argparse.Namespace) -> Session:
    client, health = discover_client(args)
    instance_id = str(health.get("editor_instance_id") or "")
    previous = load_cli_state()
    previous_id = str(previous.get("editor_instance_id") or "")
    restarted = bool(previous_id and instance_id and previous_id != instance_id)
    save_cli_state(instance_id, client.endpoint)
    return Session(client, health, restarted)


def heal_scene_args(arguments: dict[str, Any], generation: str, revision: int) -> bool:
    changed = False

    def walk(value: Any) -> None:
        nonlocal changed
        if isinstance(value, dict):
            if generation and "scene_generation" in value and value.get("scene_generation") != generation:
                value["scene_generation"] = generation
                changed = True
            if "expected_scene_revision" in value and value.get("expected_scene_revision") != revision:
                value["expected_scene_revision"] = revision
                changed = True
            for child in value.values():
                walk(child)
        elif isinstance(value, list):
            for child in value:
                walk(child)

    walk(arguments)
    return changed


def cmd_status(args: argparse.Namespace) -> int:
    session = connect(args)
    try:
        state = session.editor_state()
    except McpError as exc:
        state = {"ok": False, "error": str(exc)}
    return emit(
        stamp(
            {
                "ok": True,
                "endpoint": session.client.endpoint,
                "health": session.health,
                "editor_state": state,
            },
            session,
        )
    )


def cmd_tools(args: argparse.Namespace) -> int:
    session = connect(args)
    listed = session.client.rpc("tools/list")
    tools = listed.get("tools") or []
    if args.schema:
        for tool in tools:
            if isinstance(tool, dict) and tool.get("name") == args.schema:
                return emit(stamp({"ok": True, "tool": tool}, session))
        return fail(f"unknown tool: {args.schema}")
    prefix = args.name or ""
    rows = []
    for tool in tools:
        if not isinstance(tool, dict):
            continue
        name = str(tool.get("name") or "")
        if prefix and prefix not in name:
            continue
        rows.append({"name": name, "description": tool.get("description") or ""})
    return emit(stamp({"ok": True, "count": len(rows), "tools": rows}, session))


def parse_args_json(raw: str | None) -> dict[str, Any]:
    if raw is None or raw == "":
        return {}
    if raw == "-":
        raw = sys.stdin.read()
    data = json.loads(raw)
    if data is None:
        return {}
    if not isinstance(data, dict):
        raise ValueError("call arguments must be a JSON object")
    return data


def cmd_call(args: argparse.Namespace) -> int:
    try:
        arguments = parse_args_json(args.arguments)
    except (ValueError, json.JSONDecodeError) as exc:
        return fail(f"invalid JSON arguments: {exc}")

    session = connect(args)
    extra: dict[str, Any] = {}
    generation, revision = "", 0
    try:
        generation, revision = session.scene_ids()
    except McpError:
        generation, revision = "", 0
    if heal_scene_args(arguments, generation, revision):
        extra["healed_scene_refs"] = True

    try:
        envelope = session.client.call_tool(args.name, arguments)
    except McpError as exc:
        if "connection failed" not in str(exc) and "HTTP" not in str(exc):
            raise
        session = connect(args)
        extra["rediscovered"] = True
        try:
            generation, revision = session.scene_ids()
        except McpError:
            generation, revision = "", 0
        if heal_scene_args(arguments, generation, revision):
            extra["healed_scene_refs"] = True
        envelope = session.client.call_tool(args.name, arguments)

    op_id = None
    data = envelope.get("data") if isinstance(envelope.get("data"), dict) else envelope
    if isinstance(data, dict):
        op_id = data.get("operation_id")
    failed = envelope.get("ok") is False
    should_wait = not failed and bool(op_id) and (args.wait or not args.no_wait)
    if should_wait:
        extra["waited"] = True
        return cmd_wait_impl(session, str(op_id), args.wait_timeout)
    return emit(stamp(envelope, session, extra), 1 if failed else 0)


def cmd_wait(args: argparse.Namespace) -> int:
    session = connect(args)
    return cmd_wait_impl(session, args.operation_id, args.timeout)


def cmd_wait_impl(session: Session, operation_id: str, timeout: float) -> int:
    deadline = time.time() + timeout
    last: dict[str, Any] = {}
    while time.time() < deadline:
        last = session.client.call_tool("get_operation", {"operation_id": operation_id})
        data = last.get("data") if isinstance(last.get("data"), dict) else last
        status = ""
        if isinstance(data, dict):
            status = str(data.get("status") or "")
        if status in {"succeeded", "failed", "cancelled", "complete", "completed", "error"}:
            return emit(stamp(last, session), 0 if status in {"succeeded", "complete", "completed"} else 1)
        time.sleep(0.25)
    return fail("wait timed out", last)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Thin UrhoXEditor MCP CLI")
    parser.add_argument("--instance", help="editor_instance_id when several editors are live")
    parser.add_argument("--endpoint", help="override MCP URL, e.g. http://127.0.0.1:27654/mcp")
    parser.add_argument("--token", help="Bearer token; default from instance file or EDITOR_MCP_TOKEN")
    parser.add_argument("--timeout", type=float, default=30.0, help="HTTP timeout seconds")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("status", help="health + get_editor_state")

    tools = sub.add_parser("tools", help="list tool names (add --schema for one full schema)")
    tools.add_argument("--name", help="substring filter")
    tools.add_argument("--schema", help="print inputSchema for this tool only")

    call = sub.add_parser("call", help="tools/call NAME [JSON object]")
    call.add_argument("name")
    call.add_argument("arguments", nargs="?", help='JSON object, or "-" to read stdin')
    call.add_argument("--wait", action="store_true", help="poll get_operation when the result has operation_id (default)")
    call.add_argument("--no-wait", action="store_true", help="return immediately even if the result has operation_id")
    call.add_argument("--wait-timeout", type=float, default=120.0)

    wait = sub.add_parser("wait", help="poll get_operation until terminal")
    wait.add_argument("operation_id")
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        if args.cmd == "status":
            return cmd_status(args)
        if args.cmd == "tools":
            return cmd_tools(args)
        if args.cmd == "call":
            return cmd_call(args)
        if args.cmd == "wait":
            return cmd_wait(args)
        return fail(f"unknown command: {args.cmd}")
    except McpError as exc:
        extra = getattr(exc, "payload", None)
        code = 2 if extra and isinstance(extra, list) else 1
        return fail(str(exc), extra, code)


if __name__ == "__main__":
    sys.exit(main())
