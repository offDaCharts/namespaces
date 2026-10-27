#!/usr/bin/env python3
"""Exercise the exact packaged stdio binary without printing user content.

Default: protocol only, no GUI required. --live: read-only GUI + preview checks.
--apply-round-trip: explicit temporary edit, restores names/colors/icons in finally.
No dependencies beyond Python's standard library (test-time only).
"""
import argparse
import json
import selectors
import subprocess
import sys
import time
import uuid

parser = argparse.ArgumentParser()
parser.add_argument("executable")
parser.add_argument("--live", action="store_true")
parser.add_argument("--apply-round-trip", action="store_true")
parser.add_argument("--check-context", action="store_true", help="Verify opt-in app context locally; print no window/app content")
parser.add_argument("--launch-app", action="store_true", help="Launch a temporary test GUI; requires no other DeskOrbit copy running")
parser.add_argument("--allow-headless-fallback", action="store_true", help="CI only: if native discovery is unavailable, require safe read-only fallback and rejected mutations")
parser.add_argument("--restore-styling-from", help="Recovery only: restore available profile styling from a local JSON backup")
args = parser.parse_args()
gui = None
if args.launch_app:
    args.live = True
    gui = subprocess.Popen([args.executable, "-DeskOrbit.agents.enabled", "YES", "-DeskOrbit.agents.windowContext", "YES" if args.check_context else "NO", "-DeskOrbit.agents.windowTitles", "NO"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
process = subprocess.Popen([args.executable, "--mcp"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, bufsize=0)
selector = selectors.DefaultSelector()
selector.register(process.stdout, selectors.EVENT_READ)
request_id = 0


def rpc(method, params=None, notification=False):
    global request_id
    request_id += 1
    request = {"jsonrpc": "2.0", "method": method}
    if not notification:
        request["id"] = request_id
    if params is not None:
        request["params"] = params
    process.stdin.write((json.dumps(request) + "\n").encode())
    process.stdin.flush()
    if notification:
        return None
    assert selector.select(timeout=12), "Timed out waiting for MCP response"
    response = json.loads(process.stdout.readline())
    assert response["id"] == request_id, "Unexpected response/notification output"
    return response


def tool(name, arguments=None, expect_error=False):
    response = rpc("tools/call", {"name": name, "arguments": arguments or {}})
    result = response["result"]
    assert result["isError"] == expect_error, f"Unexpected tool status: {name}: " + (result["content"][0]["text"] if result["isError"] else "expected rejection")
    return result if expect_error else json.loads(result["content"][0]["text"])


try:
    assert rpc("tools/list")["error"]["code"] == -32002
    init = rpc("initialize", {"protocolVersion": "2025-11-25", "capabilities": {}, "clientInfo": {"name": "deskorbit-smoke", "version": "1"}})
    assert init["result"]["serverInfo"]["version"] == "0.3.0"
    rpc("notifications/initialized", notification=True)
    definitions = rpc("tools/list")["result"]["tools"]
    assert len(definitions) == 6
    assert rpc("ping")["result"] == {}
    tool("deskorbit_status", {"unexpected": True}, expect_error=True)
    if gui:
        for attempt in range(40):
            assert gui.poll() is None, "Test GUI exited during startup"
            readiness = rpc("tools/call", {"name": "deskorbit_status", "arguments": {}})["result"]
            if not readiness["isError"]:
                break
            time.sleep(0.25)
        else:
            raise AssertionError("Test GUI did not enable agent connection")
    if args.restore_styling_from:
        with open(args.restore_styling_from) as backup_file:
            saved = json.load(backup_file)["spaces"]
        available_ids = {s["space_id"] for s in tool("deskorbit_list_spaces")["spaces"] if s["available"]}
        recovery = [{"space_id": s["id"], "name": s["name"], "color": s["colorHex"], "symbol": s["symbol"]} for s in saved if s["id"] in available_ids]
        assert recovery
        result = tool("deskorbit_configure_spaces", {"spaces": recovery, "apply": True})
        assert result["applied"] and result["persisted"]
        print("PASS: recovered available Space styling from backup")
    if args.live or args.apply_round_trip:
        status = tool("deskorbit_status")
        assert status["version"] == "0.3.0"
        if not status["window_context_enabled"]:
            tool("deskorbit_window_context", expect_error=True)
        elif args.check_context:
            context = tool("deskorbit_window_context")
            assert not context["titles_included"]
            assert all("title" not in w for w in context["windows"])
            assert all(isinstance(w["space_ids"], list) for w in context["windows"])
            print("PASS: opt-in app/Space context, titles omitted (content not logged)")
        if not status["window_titles_enabled"]:
            tool("deskorbit_window_context", {"include_titles": True}, expect_error=True)
        before = tool("deskorbit_list_spaces")["spaces"]
        available = [s for s in before if s["available"]][:2]
        if not available and args.allow_headless_fallback:
            assert not status["can_discover_spaces"], "Discovery claims availability but returned no Spaces"
            unknown = str(uuid.uuid4())
            tool("deskorbit_configure_spaces", {"spaces": [{"space_id": unknown, "name": "Must not apply"}], "apply": True}, expect_error=True)
            tool("deskorbit_switch_space", {"space_id": unknown}, expect_error=True)
            assert tool("deskorbit_list_spaces")["spaces"] == before
            assert len(tool("deskorbit_palette")["colors"]) == 8
            print("PASS: live GUI IPC, permission denial, headless fallback, unavailable mutations rejected")
            print("PASS: packaged MCP initialization, discovery, notifications, validation, ping")
            print("NOT EXERCISED: real-desktop preview/apply/restore; this runner exposes no native Spaces")
            sys.exit(0)
        assert available, "No available Spaces for preview test"
        edits = [{"space_id": s["space_id"], "name": "MCP verification " + str(i)} for i, s in enumerate(available)]
        preview = tool("deskorbit_configure_spaces", {"spaces": edits})
        assert not preview["applied"] and len(preview["changes"]) == len(edits)
        assert tool("deskorbit_list_spaces")["spaces"] == before, "Preview changed a Space"
        invalid = edits + [{"space_id": str(uuid.uuid4()), "name": "Invalid"}]
        tool("deskorbit_configure_spaces", {"spaces": invalid, "apply": True}, expect_error=True)
        assert tool("deskorbit_list_spaces")["spaces"] == before, "Invalid batch changed a Space"
        assert len(tool("deskorbit_palette")["colors"]) == 8
        if args.apply_round_trip:
            restore = [{k: s[k] for k in ("space_id", "name", "color", "symbol")} for s in available]
            try:
                result = tool("deskorbit_configure_spaces", {"spaces": edits, "apply": True})
                assert result["applied"] and result["persisted"]
                current = {s["space_id"]: s for s in tool("deskorbit_list_spaces")["spaces"]}
                for edit in edits:
                    assert current[edit["space_id"]]["name"] == edit["name"]
            finally:
                result = tool("deskorbit_configure_spaces", {"spaces": restore, "apply": True})
                assert result["applied"] and result["persisted"], "Restore failed"
            assert tool("deskorbit_list_spaces")["spaces"] == before, "Restored styling differs"
        print("PASS: live GUI preview, invalid-batch isolation, palette" + (", apply/persist/restore" if args.apply_round_trip else ""))
    print("PASS: packaged MCP initialization, discovery, notifications, validation, ping")
finally:
    process.stdin.close()
    try:
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait()
    selector.close()
    if gui:
        gui.terminate()
        try:
            gui.wait(timeout=5)
        except subprocess.TimeoutExpired:
            gui.kill()
            gui.wait()
    assert process.returncode == 0, "MCP helper did not exit cleanly on EOF"
