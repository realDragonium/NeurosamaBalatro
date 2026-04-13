"""
Integration Test Harness for NeurosamaBalatro
Acts as a Neuro-sama SDK WebSocket server on localhost:8000.
Validates protocol correctness, tracks state, runs test scenarios.

Usage:
    python test_harness.py                                # run all scenarios, exit 0/1
    python test_harness.py --interactive                  # REPL mode
    python test_harness.py --scenario startup             # run one scenario, exit 0/1
    python test_harness.py --scenario startup --interactive  # scenario then REPL
    python test_harness.py --port 8000                    # custom port
    python test_harness.py --verbose                      # show all raw messages
"""

import argparse
import asyncio
import json
import sys
import time
import uuid
from dataclasses import dataclass, field
from enum import Enum
from typing import Any

import websockets
from websockets.asyncio.server import serve


# ─── ANSI colors ──────────────────────────────────────────────────────────────

class C:
    RESET = "\033[0m"
    BOLD = "\033[1m"
    DIM = "\033[2m"
    RED = "\033[31m"
    GREEN = "\033[32m"
    YELLOW = "\033[33m"
    BLUE = "\033[34m"
    MAGENTA = "\033[35m"
    CYAN = "\033[36m"


def log_info(msg: str):
    print(f"{C.BLUE}[INFO]{C.RESET} {msg}")

def log_recv(msg: str):
    print(f"{C.CYAN}[RECV]{C.RESET} {msg}")

def log_send(msg: str):
    print(f"{C.MAGENTA}[SEND]{C.RESET} {msg}")

def log_pass(msg: str):
    print(f"{C.GREEN}[PASS]{C.RESET} {msg}")

def log_fail(msg: str):
    print(f"{C.RED}[FAIL]{C.RESET} {msg}")

def log_warn(msg: str):
    print(f"{C.YELLOW}[WARN]{C.RESET} {msg}")

def log_verbose(msg: str, verbose: bool):
    if verbose:
        print(f"{C.DIM}[VERBOSE] {msg}{C.RESET}")


# ─── Protocol Validator ──────────────────────────────────────────────────────

KNOWN_INBOUND_COMMANDS = {
    "startup", "context", "action/result", "actions/register", "actions/unregister"
}


class ProtocolValidator:
    """Validates incoming messages from the mod against the protocol spec."""

    def validate(self, msg: dict) -> list[str]:
        errors = []

        if "command" not in msg:
            errors.append("Missing 'command' field")
            return errors

        cmd = msg["command"]
        if not isinstance(cmd, str):
            errors.append(f"'command' must be string, got {type(cmd).__name__}")
            return errors

        if "game" not in msg:
            errors.append("Missing 'game' field")
        elif msg["game"] != "Balatro":
            errors.append(f"Expected game='Balatro', got '{msg['game']}'")

        if cmd not in KNOWN_INBOUND_COMMANDS:
            errors.append(f"Unknown command '{cmd}' (may be a new command)")
            return errors

        # Command-specific validation
        validator = getattr(self, f"_validate_{cmd.replace('/', '_')}", None)
        if validator:
            errors.extend(validator(msg))

        return errors

    def _validate_startup(self, msg: dict) -> list[str]:
        return []

    def _validate_context(self, msg: dict) -> list[str]:
        errors = []
        data = msg.get("data")
        if not data:
            errors.append("context: missing 'data' field")
            return errors
        if "message" not in data:
            errors.append("context: missing 'data.message'")
        elif not isinstance(data["message"], str):
            errors.append("context: 'data.message' must be string")
        if "silent" not in data:
            errors.append("context: missing 'data.silent'")
        elif not isinstance(data["silent"], bool):
            errors.append("context: 'data.silent' must be boolean")
        return errors

    def _validate_action_result(self, msg: dict) -> list[str]:
        errors = []
        data = msg.get("data")
        if not data:
            errors.append("action/result: missing 'data' field")
            return errors
        if "id" not in data:
            errors.append("action/result: missing 'data.id'")
        if "success" not in data:
            errors.append("action/result: missing 'data.success'")
        elif not isinstance(data["success"], bool):
            errors.append("action/result: 'data.success' must be boolean")
        if "message" not in data:
            errors.append("action/result: missing 'data.message'")
        return errors

    def _validate_actions_register(self, msg: dict) -> list[str]:
        errors = []
        data = msg.get("data")
        if not data:
            errors.append("actions/register: missing 'data' field")
            return errors
        actions = data.get("actions")
        if not isinstance(actions, list):
            errors.append("actions/register: 'data.actions' must be a list")
            return errors
        for i, action in enumerate(actions):
            if "name" not in action:
                errors.append(f"actions/register: action[{i}] missing 'name'")
            elif not isinstance(action["name"], str):
                errors.append(f"actions/register: action[{i}].name must be string")
            if "description" not in action:
                errors.append(f"actions/register: action[{i}] missing 'description'")
        return errors

    def _validate_actions_unregister(self, msg: dict) -> list[str]:
        errors = []
        data = msg.get("data")
        if not data:
            errors.append("actions/unregister: missing 'data' field")
            return errors
        names = data.get("action_names")
        if not isinstance(names, list):
            errors.append("actions/unregister: 'data.action_names' must be a list")
            return errors
        for i, name in enumerate(names):
            if not isinstance(name, str):
                errors.append(f"actions/unregister: action_names[{i}] must be string")
        return errors


# ─── State Tracker ────────────────────────────────────────────────────────────

@dataclass
class MessageEntry:
    timestamp: float
    direction: str  # "recv" or "send"
    message: dict


class StateTracker:
    """Tracks the mod's state as observed through its messages."""

    def __init__(self):
        self.registered_actions: dict[str, dict] = {}
        self.last_context: str | None = None
        self.last_context_time: float | None = None
        self.startup_received: bool = False
        self.startup_time: float | None = None
        self.connection_time: float | None = None
        self.message_log: list[MessageEntry] = []
        self.pending_results: dict[str, asyncio.Future] = {}
        self.validation_errors: list[tuple[float, list[str]]] = []
        # Coverage tracking
        self.all_actions_ever_seen: set[str] = set()
        self.actions_executed: set[str] = set()
        self.game_states_seen: set[str] = set()

    def on_connect(self):
        self.connection_time = time.time()

    def on_message(self, direction: str, msg: dict):
        self.message_log.append(MessageEntry(time.time(), direction, msg))

    def on_startup(self):
        self.startup_received = True
        self.startup_time = time.time()

    def on_register(self, actions: list[dict]):
        for action in actions:
            name = action.get("name", "")
            self.registered_actions[name] = action
            self.all_actions_ever_seen.add(name)

    def on_unregister(self, names: list[str]):
        for name in names:
            self.registered_actions.pop(name, None)

    def on_context(self, message: str, silent: bool):
        self.last_context = message
        self.last_context_time = time.time()
        # Extract game state from context for coverage tracking
        import re
        state_match = re.search(r"Game State: (\w+)", message)
        if state_match:
            self.game_states_seen.add(state_match.group(1))

    def on_action_result(self, action_id: str, success: bool, message: str):
        future = self.pending_results.pop(action_id, None)
        if future and not future.done():
            future.set_result({"id": action_id, "success": success, "message": message})

    def register_pending(self, action_id: str) -> asyncio.Future:
        loop = asyncio.get_event_loop()
        future = loop.create_future()
        self.pending_results[action_id] = future
        return future

    def get_summary(self) -> str:
        lines = []
        elapsed = time.time() - self.connection_time if self.connection_time else 0
        lines.append(f"Connection duration: {elapsed:.1f}s")
        lines.append(f"Messages received: {sum(1 for e in self.message_log if e.direction == 'recv')}")
        lines.append(f"Messages sent: {sum(1 for e in self.message_log if e.direction == 'send')}")
        lines.append(f"Startup received: {self.startup_received}")
        lines.append(f"Registered actions ({len(self.registered_actions)}): {', '.join(sorted(self.registered_actions.keys()))}")
        ctx_age = f"{time.time() - self.last_context_time:.1f}s ago" if self.last_context_time else "never"
        lines.append(f"Last context ({ctx_age}): {(self.last_context or '')[:100]}...")
        lines.append(f"Validation errors: {len(self.validation_errors)}")
        return "\n".join(lines)

    def get_coverage_report(self) -> str:
        lines = []
        lines.append(f"Actions seen (registered at any point): {len(self.all_actions_ever_seen)}")
        if self.all_actions_ever_seen:
            lines.append(f"  {', '.join(sorted(self.all_actions_ever_seen))}")
        lines.append(f"Actions executed: {len(self.actions_executed)}")
        if self.actions_executed:
            lines.append(f"  {', '.join(sorted(self.actions_executed))}")
        never_executed = self.all_actions_ever_seen - self.actions_executed
        lines.append(f"Actions seen but never executed: {len(never_executed)}")
        if never_executed:
            lines.append(f"  {', '.join(sorted(never_executed))}")
        lines.append(f"Game states observed: {len(self.game_states_seen)}")
        if self.game_states_seen:
            lines.append(f"  {', '.join(sorted(self.game_states_seen))}")
        return "\n".join(lines)


# ─── Action Sender ────────────────────────────────────────────────────────────

class ActionSender:
    """Builds properly formatted outbound messages."""

    @staticmethod
    def build_action(name: str, params: dict | None = None) -> tuple[str, dict]:
        """Returns (action_id, message_dict). Note: data.data is double-encoded."""
        action_id = str(uuid.uuid4())[:8]
        msg = {
            "command": "action",
            "data": {
                "id": action_id,
                "name": name,
                "data": json.dumps(params) if params else None,
            }
        }
        return action_id, msg

    @staticmethod
    def build_query() -> dict:
        return {"command": "query"}

    @staticmethod
    def build_reregister_all() -> dict:
        return {"command": "actions/reregister_all"}


# ─── Scenario Runner ─────────────────────────────────────────────────────────

class StepType(Enum):
    WAIT_FOR_COMMAND = "wait_for_command"
    WAIT_FOR_ACTION_REGISTERED = "wait_for_action_registered"
    WAIT_FOR_CONTEXT = "wait_for_context"
    SEND_ACTION = "send_action"
    SEND_QUERY = "send_query"
    SEND_REREGISTER_ALL = "send_reregister_all"
    ASSERT_REGISTERED = "assert_registered"
    ASSERT_NOT_REGISTERED = "assert_not_registered"
    DELAY = "delay"
    LOG = "log"


@dataclass
class Step:
    type: StepType
    # Fields vary by type
    command: str | None = None           # WAIT_FOR_COMMAND
    action_name: str | None = None       # WAIT_FOR_ACTION_REGISTERED, SEND_ACTION
    contains: str | None = None          # WAIT_FOR_CONTEXT
    params: dict | None = None           # SEND_ACTION
    expect_success: bool = True          # SEND_ACTION
    actions: list[str] = field(default_factory=list)  # ASSERT_REGISTERED / NOT_REGISTERED
    seconds: float = 0                   # DELAY
    message: str = ""                    # LOG
    timeout: float = 30.0               # for wait steps


@dataclass
class StepResult:
    step_index: int
    step: Step
    passed: bool
    message: str


class ScenarioRunner:
    """Executes scripted test step sequences."""

    def __init__(self, state: StateTracker, verbose: bool = False):
        self.state = state
        self.verbose = verbose
        self.incoming_queue: asyncio.Queue[dict] = asyncio.Queue()
        self.ws = None
        self.results: list[StepResult] = []

    def set_ws(self, ws):
        self.ws = ws

    def feed_message(self, msg: dict):
        """Called by server handler for every received message."""
        self.incoming_queue.put_nowait(msg)

    # ── High-level helpers for dynamic scenarios ──

    async def wait_for_action(self, name: str, timeout: float = 30) -> bool:
        """Wait until an action is registered. Returns True if found."""
        if name in self.state.registered_actions:
            return True
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                remaining = max(0.1, deadline - time.time())
                msg = await asyncio.wait_for(self.incoming_queue.get(), timeout=remaining)
                if msg.get("command") == "actions/register":
                    actions = msg.get("data", {}).get("actions", [])
                    for a in actions:
                        if a.get("name") == name:
                            return True
            except asyncio.TimeoutError:
                break
        return False

    async def wait_for_any_action(self, names: list[str], timeout: float = 30) -> str | None:
        """Wait until any of the named actions is registered. Returns which one, or None."""
        # Check already registered first
        for name in names:
            if name in self.state.registered_actions:
                return name
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                remaining = max(0.1, deadline - time.time())
                msg = await asyncio.wait_for(self.incoming_queue.get(), timeout=remaining)
                if msg.get("command") == "actions/register":
                    actions = msg.get("data", {}).get("actions", [])
                    for a in actions:
                        if a.get("name") in names:
                            return a.get("name")
                # Also re-check state after any message (actions may have been registered separately)
                for name in names:
                    if name in self.state.registered_actions:
                        return name
            except asyncio.TimeoutError:
                break
        return None

    async def send_and_expect(self, name: str, params: dict | None = None,
                               expect_success: bool = True, timeout: float = 10,
                               retries: int = 3, retry_delay: float = 2.0) -> dict | None:
        """Send an action and wait for result. Retries on failure. Returns result dict or None."""
        if not self.ws:
            log_fail(f"Cannot send '{name}': no connection")
            return None

        self.state.actions_executed.add(name)

        for attempt in range(1, retries + 1):
            action_id, msg = ActionSender.build_action(name, params)
            future = self.state.register_pending(action_id)

            await self.ws.send(json.dumps(msg))
            self.state.on_message("send", msg)
            log_send(f"action '{name}' (id={action_id})" + (f" [attempt {attempt}/{retries}]" if attempt > 1 else ""))

            try:
                result = await asyncio.wait_for(future, timeout=timeout)
                success = result["success"]
                result_msg = result["message"]

                if success:
                    log_pass(f"  {name}: {result_msg}")
                    if not expect_success:
                        raise RuntimeError(f"Action '{name}' unexpectedly succeeded: {result_msg}")
                    return result

                # Action failed
                if not expect_success:
                    log_pass(f"  {name}: failed as expected - {result_msg}")
                    return result

                # Unexpected failure - retry if we have attempts left
                if attempt < retries:
                    log_warn(f"  {name}: failed ({result_msg}), retrying in {retry_delay}s...")
                    await self.drain_queue(retry_delay)
                else:
                    log_fail(f"  {name}: failed after {retries} attempts - {result_msg}")
                    raise RuntimeError(f"Action '{name}' failed after {retries} attempts: {result_msg}")

            except asyncio.TimeoutError:
                if attempt < retries:
                    log_warn(f"  {name}: timeout, retrying in {retry_delay}s...")
                    await self.drain_queue(retry_delay)
                else:
                    log_fail(f"  {name}: timeout after {retries} attempts ({timeout}s)")
                    return None

        return None

    def is_registered(self, name: str) -> bool:
        """Check if an action is currently registered."""
        return name in self.state.registered_actions

    async def drain_queue(self, seconds: float = 1.0):
        """Drain the message queue for a duration, letting state update."""
        deadline = time.time() + seconds
        while time.time() < deadline:
            try:
                await asyncio.wait_for(self.incoming_queue.get(), timeout=0.1)
            except asyncio.TimeoutError:
                pass

    # ── Scenario execution ──

    async def run_scenario(self, name: str, scenario) -> bool:
        """Run a scenario. Accepts either a list[Step] or an async function."""
        log_info(f"Running scenario: {C.BOLD}{name}{C.RESET}")
        self.results = []

        # Dynamic scenario (async function)
        if callable(scenario):
            try:
                await scenario(self)
                log_info(f"Scenario '{name}': {C.GREEN}PASSED{C.RESET}")
                return True
            except Exception as e:
                log_fail(f"Scenario '{name}' failed: {e}")
                return False

        # Static scenario (list of steps)
        all_passed = True
        steps = scenario
        for i, step in enumerate(steps):
            result = await self._execute_step(i, step)
            self.results.append(result)
            if result.passed:
                log_pass(f"  Step {i+1}/{len(steps)}: {result.message}")
            else:
                log_fail(f"  Step {i+1}/{len(steps)}: {result.message}")
                all_passed = False

        status = f"{C.GREEN}PASSED{C.RESET}" if all_passed else f"{C.RED}FAILED{C.RESET}"
        passed_count = sum(1 for r in self.results if r.passed)
        log_info(f"Scenario '{name}': {status} ({passed_count}/{len(steps)} steps)")
        return all_passed

    async def _execute_step(self, index: int, step: Step) -> StepResult:
        try:
            match step.type:
                case StepType.WAIT_FOR_COMMAND:
                    return await self._wait_for_command(index, step)
                case StepType.WAIT_FOR_ACTION_REGISTERED:
                    return await self._wait_for_action_registered(index, step)
                case StepType.WAIT_FOR_CONTEXT:
                    return await self._wait_for_context(index, step)
                case StepType.SEND_ACTION:
                    return await self._send_action(index, step)
                case StepType.SEND_QUERY:
                    return await self._send_query(index, step)
                case StepType.SEND_REREGISTER_ALL:
                    return await self._send_reregister_all(index, step)
                case StepType.ASSERT_REGISTERED:
                    return self._assert_registered(index, step)
                case StepType.ASSERT_NOT_REGISTERED:
                    return self._assert_not_registered(index, step)
                case StepType.DELAY:
                    await asyncio.sleep(step.seconds)
                    return StepResult(index, step, True, f"Delayed {step.seconds}s")
                case StepType.LOG:
                    log_info(f"  {step.message}")
                    return StepResult(index, step, True, step.message)
                case _:
                    return StepResult(index, step, False, f"Unknown step type: {step.type}")
        except Exception as e:
            return StepResult(index, step, False, f"Exception: {e}")

    async def _wait_for_command(self, index: int, step: Step) -> StepResult:
        deadline = time.time() + step.timeout
        while time.time() < deadline:
            try:
                remaining = max(0.1, deadline - time.time())
                msg = await asyncio.wait_for(self.incoming_queue.get(), timeout=remaining)
                if msg.get("command") == step.command:
                    return StepResult(index, step, True, f"Received '{step.command}'")
            except asyncio.TimeoutError:
                break
        return StepResult(index, step, False, f"Timeout waiting for command '{step.command}' ({step.timeout}s)")

    async def _wait_for_action_registered(self, index: int, step: Step) -> StepResult:
        # First check if already registered
        if step.action_name in self.state.registered_actions:
            return StepResult(index, step, True, f"Action '{step.action_name}' already registered")

        deadline = time.time() + step.timeout
        while time.time() < deadline:
            try:
                remaining = max(0.1, deadline - time.time())
                msg = await asyncio.wait_for(self.incoming_queue.get(), timeout=remaining)
                # Check if this register message contains our action
                if msg.get("command") == "actions/register":
                    actions = msg.get("data", {}).get("actions", [])
                    for a in actions:
                        if a.get("name") == step.action_name:
                            return StepResult(index, step, True, f"Action '{step.action_name}' registered")
            except asyncio.TimeoutError:
                break
        return StepResult(index, step, False,
                         f"Timeout waiting for action '{step.action_name}' to be registered ({step.timeout}s)")

    async def _wait_for_context(self, index: int, step: Step) -> StepResult:
        # Check last context first
        if self.state.last_context and step.contains in self.state.last_context:
            return StepResult(index, step, True, f"Context contains '{step.contains}'")

        deadline = time.time() + step.timeout
        while time.time() < deadline:
            try:
                remaining = max(0.1, deadline - time.time())
                msg = await asyncio.wait_for(self.incoming_queue.get(), timeout=remaining)
                if msg.get("command") == "context":
                    text = msg.get("data", {}).get("message", "")
                    if step.contains in text:
                        return StepResult(index, step, True, f"Context contains '{step.contains}'")
            except asyncio.TimeoutError:
                break
        return StepResult(index, step, False,
                         f"Timeout waiting for context containing '{step.contains}' ({step.timeout}s)")

    async def _send_action(self, index: int, step: Step) -> StepResult:
        if not self.ws:
            return StepResult(index, step, False, "No WebSocket connection")

        action_id, msg = ActionSender.build_action(step.action_name, step.params)
        future = self.state.register_pending(action_id)
        self.state.actions_executed.add(step.action_name)

        await self.ws.send(json.dumps(msg))
        self.state.on_message("send", msg)
        log_send(f"action '{step.action_name}' (id={action_id})")

        # Wait for result
        try:
            result = await asyncio.wait_for(future, timeout=step.timeout)
            success = result["success"]
            result_msg = result["message"]

            if step.expect_success and success:
                return StepResult(index, step, True,
                                 f"Action '{step.action_name}' succeeded: {result_msg}")
            elif not step.expect_success and not success:
                return StepResult(index, step, True,
                                 f"Action '{step.action_name}' failed as expected: {result_msg}")
            elif step.expect_success and not success:
                return StepResult(index, step, False,
                                 f"Action '{step.action_name}' unexpectedly failed: {result_msg}")
            else:
                return StepResult(index, step, False,
                                 f"Action '{step.action_name}' unexpectedly succeeded: {result_msg}")
        except asyncio.TimeoutError:
            return StepResult(index, step, False,
                             f"Timeout waiting for result of '{step.action_name}' ({step.timeout}s)")

    async def _send_query(self, index: int, step: Step) -> StepResult:
        if not self.ws:
            return StepResult(index, step, False, "No WebSocket connection")

        msg = ActionSender.build_query()
        await self.ws.send(json.dumps(msg))
        self.state.on_message("send", msg)
        log_send("query")

        # Wait for a context response
        deadline = time.time() + step.timeout
        while time.time() < deadline:
            try:
                remaining = max(0.1, deadline - time.time())
                incoming = await asyncio.wait_for(self.incoming_queue.get(), timeout=remaining)
                if incoming.get("command") == "context":
                    return StepResult(index, step, True, "Received context response to query")
            except asyncio.TimeoutError:
                break
        return StepResult(index, step, False, f"Timeout waiting for context after query ({step.timeout}s)")

    async def _send_reregister_all(self, index: int, step: Step) -> StepResult:
        if not self.ws:
            return StepResult(index, step, False, "No WebSocket connection")

        msg = ActionSender.build_reregister_all()
        await self.ws.send(json.dumps(msg))
        self.state.on_message("send", msg)
        log_send("actions/reregister_all")

        # Wait for a register response
        deadline = time.time() + step.timeout
        while time.time() < deadline:
            try:
                remaining = max(0.1, deadline - time.time())
                incoming = await asyncio.wait_for(self.incoming_queue.get(), timeout=remaining)
                if incoming.get("command") == "actions/register":
                    return StepResult(index, step, True, "Received re-registration response")
            except asyncio.TimeoutError:
                break
        return StepResult(index, step, False,
                         f"Timeout waiting for re-registration ({step.timeout}s)")

    def _assert_registered(self, index: int, step: Step) -> StepResult:
        missing = [a for a in step.actions if a not in self.state.registered_actions]
        if not missing:
            return StepResult(index, step, True,
                             f"All actions registered: {', '.join(step.actions)}")
        return StepResult(index, step, False,
                         f"Actions not registered: {', '.join(missing)}")

    def _assert_not_registered(self, index: int, step: Step) -> StepResult:
        present = [a for a in step.actions if a in self.state.registered_actions]
        if not present:
            return StepResult(index, step, True,
                             f"Actions correctly not registered: {', '.join(step.actions)}")
        return StepResult(index, step, False,
                         f"Actions should not be registered: {', '.join(present)}")


# ─── Built-in Scenarios ──────────────────────────────────────────────────────

SCENARIOS: dict[str, list[Step]] = {
    "startup": [
        Step(type=StepType.LOG, message="Waiting for mod to connect and send startup..."),
        Step(type=StepType.WAIT_FOR_COMMAND, command="startup", timeout=60),
        Step(type=StepType.LOG, message="Startup received. Waiting for action registration..."),
        Step(type=StepType.WAIT_FOR_COMMAND, command="actions/register", timeout=15),
        Step(type=StepType.LOG, message="Actions registered. Waiting for context update..."),
        Step(type=StepType.WAIT_FOR_COMMAND, command="context", timeout=15),
        Step(type=StepType.LOG, message="Startup sequence complete."),
    ],

    "protocol": [
        Step(type=StepType.LOG, message="Testing query command..."),
        Step(type=StepType.SEND_QUERY, timeout=10),
        Step(type=StepType.LOG, message="Testing reregister_all command..."),
        Step(type=StepType.SEND_REREGISTER_ALL, timeout=10),
        Step(type=StepType.LOG, message="Testing action with unknown name..."),
        Step(type=StepType.SEND_ACTION, action_name="__nonexistent_action__",
             expect_success=False, timeout=10),
        Step(type=StepType.LOG, message="Protocol validation complete."),
    ],

    "menu_to_game": [
        Step(type=StepType.LOG, message="Waiting for menu actions..."),
        Step(type=StepType.WAIT_FOR_ACTION_REGISTERED, action_name="press_play", timeout=60),
        Step(type=StepType.LOG, message="Sending press_play..."),
        Step(type=StepType.SEND_ACTION, action_name="press_play", timeout=10),
        Step(type=StepType.LOG, message="Waiting for start_run to become available..."),
        Step(type=StepType.WAIT_FOR_ACTION_REGISTERED, action_name="start_run", timeout=15),
        Step(type=StepType.LOG, message="Sending start_run..."),
        Step(type=StepType.SEND_ACTION, action_name="start_run", timeout=10),
        Step(type=StepType.LOG, message="Waiting for blind select state..."),
        Step(type=StepType.WAIT_FOR_ACTION_REGISTERED, action_name="play_blind", timeout=15),
        Step(type=StepType.LOG, message="Game started, in blind select."),
    ],

    "play_round": [
        Step(type=StepType.LOG, message="Waiting for gameplay state (SELECTING_HAND)..."),
        Step(type=StepType.WAIT_FOR_ACTION_REGISTERED, action_name="select_specific_cards", timeout=30),
        Step(type=StepType.LOG, message="Selecting cards [1, 2, 3, 4, 5]..."),
        Step(type=StepType.SEND_ACTION, action_name="select_specific_cards",
             params={"indices": [1, 2, 3, 4, 5]}, timeout=10),
        Step(type=StepType.DELAY, seconds=0.5),
        Step(type=StepType.LOG, message="Playing hand..."),
        Step(type=StepType.SEND_ACTION, action_name="play_hand", timeout=10),
        Step(type=StepType.LOG, message="Hand played."),
    ],

    "shop": [
        Step(type=StepType.LOG, message="Waiting for shop state..."),
        Step(type=StepType.WAIT_FOR_ACTION_REGISTERED, action_name="end_shop", timeout=60),
        Step(type=StepType.LOG, message="In shop. Sending end_shop..."),
        Step(type=StepType.SEND_ACTION, action_name="end_shop", timeout=10),
        Step(type=StepType.LOG, message="Shop exited."),
    ],
}

# full_run chains everything together
SCENARIOS["full_run"] = (
    SCENARIOS["startup"]
    + SCENARIOS["protocol"]
    + SCENARIOS["menu_to_game"]
    + SCENARIOS["play_round"]
    + SCENARIOS["shop"]
)


# ─── Dynamic Gameplay Scenarios ──────────────────────────────────────────────

async def scenario_start_game(runner: "ScenarioRunner"):
    """Adaptively start a game: continue if save exists, otherwise new game."""
    log_info("  Waiting for main menu...")
    found = await runner.wait_for_action("press_play", timeout=60)
    if not found:
        raise RuntimeError("Never saw press_play action")

    # Let the menu fully settle before interacting (splash transition, animations)
    log_info("  Letting menu settle...")
    await runner.drain_queue(3.0)

    await runner.send_and_expect("press_play")

    # Wait for menu overlay to appear with its actions
    log_info("  Waiting for menu overlay...")
    await runner.drain_queue(2.0)

    # Check what's available: continue or new run
    if runner.is_registered("continue_run"):
        log_info("  Save file found, continuing existing run...")
        await runner.send_and_expect("continue_run")
    else:
        log_info("  No save file, starting new run...")
        if runner.is_registered("switch_to_new_run"):
            await runner.send_and_expect("switch_to_new_run")
            await runner.drain_queue(1.0)

        found = await runner.wait_for_action("start_run", timeout=10)
        if not found:
            raise RuntimeError("start_run never became available")
        await runner.send_and_expect("start_run")

    # Wait for the game to start (blind select or hand select)
    log_info("  Waiting for game to start...")
    which = await runner.wait_for_any_action(
        ["play_blind", "select_specific_cards"], timeout=30
    )
    if not which:
        raise RuntimeError("Game never reached blind select or hand select")
    log_info(f"  Game started! (reached {which})")


async def scenario_play_full_round(runner: "ScenarioRunner"):
    """Play hands until the blind is beaten (or we run out of hands)."""
    hands_played = 0
    max_hands = 10

    while hands_played < max_hands:
        which = await runner.wait_for_any_action(
            ["select_specific_cards", "cash_out", "end_shop", "play_blind",
             "restart_run", "go_to_menu"],
            timeout=60
        )

        if which is None:
            raise RuntimeError(f"Stuck after {hands_played} hands - no expected action available")

        if which in ("cash_out", "end_shop", "play_blind", "restart_run", "go_to_menu"):
            log_info(f"  Round over after {hands_played} hands (reached {which})")
            return

        if which == "select_specific_cards":
            # Select first 5 cards (or fewer if hand is smaller)
            await runner.send_and_expect("select_specific_cards", {"indices": [1, 2, 3, 4, 5]})
            await asyncio.sleep(0.5)
            await runner.send_and_expect("play_hand")
            hands_played += 1
            log_info(f"  Hand {hands_played} played")
            # Wait a bit for scoring animation
            await runner.drain_queue(3.0)

    log_info(f"  Played maximum {max_hands} hands")


async def scenario_shop_phase(runner: "ScenarioRunner"):
    """Handle the shop: just exit for now."""
    found = await runner.wait_for_action("end_shop", timeout=30)
    if not found:
        log_info("  No shop phase detected, skipping")
        return

    log_info("  In shop, exiting...")
    await runner.send_and_expect("end_shop")
    await runner.drain_queue(1.0)


async def scenario_full_ante(runner: "ScenarioRunner"):
    """Play through one complete ante (up to 3 blinds + shops)."""
    for blind_num in range(1, 4):  # Small, Big, Boss
        # Wait for blind select
        found = await runner.wait_for_action("play_blind", timeout=30)
        if not found:
            # Might have reached endgame or game over
            if runner.is_registered("restart_run") or runner.is_registered("go_to_menu"):
                log_info(f"  Game ended before blind {blind_num}")
                return
            raise RuntimeError(f"play_blind never available for blind {blind_num}")

        blind_name = ["Small", "Big", "Boss"][blind_num - 1]
        log_info(f"  Playing {blind_name} Blind...")
        await runner.send_and_expect("play_blind")

        # Play the round
        await scenario_play_full_round(runner)

        # Handle shop (not after boss blind's shop if ante is over)
        if runner.is_registered("end_shop"):
            await scenario_shop_phase(runner)
        elif runner.is_registered("cash_out"):
            log_info("  Cashing out...")
            await runner.send_and_expect("cash_out")
            await runner.drain_queue(2.0)
            # Shop should appear after cash out
            if runner.is_registered("end_shop"):
                await scenario_shop_phase(runner)

        # Check if game ended
        if runner.is_registered("restart_run") or runner.is_registered("go_to_menu"):
            log_info(f"  Game ended after {blind_name} Blind")
            return

    log_info("  Ante complete!")


async def scenario_full_game(runner: "ScenarioRunner"):
    """Start a game and play through multiple antes until win or lose."""
    # Start the game (start_game handles its own waiting and settling)
    await scenario_start_game(runner)

    # Play antes
    max_antes = 8
    for ante_num in range(1, max_antes + 1):
        log_info(f"  === Ante {ante_num} ===")

        # Check if we're at blind select
        if not runner.is_registered("play_blind"):
            found = await runner.wait_for_action("play_blind", timeout=30)
            if not found:
                if runner.is_registered("restart_run") or runner.is_registered("go_to_menu"):
                    log_info(f"  Game over at ante {ante_num}!")
                    break
                raise RuntimeError(f"play_blind not available at ante {ante_num}")

        await scenario_full_ante(runner)

        # Check for game end
        which = await runner.wait_for_any_action(
            ["play_blind", "restart_run", "go_to_menu", "continue_run"],
            timeout=30
        )
        if which in ("restart_run", "go_to_menu"):
            log_info(f"  Game over after ante {ante_num}!")
            break
        elif which == "continue_run":
            log_info(f"  Won at ante {ante_num}! Continuing...")
            await runner.send_and_expect("continue_run")
            await runner.drain_queue(2.0)
        elif which is None:
            log_info(f"  No next state after ante {ante_num}, ending")
            break

    log_info("  Full game scenario complete")


# Register dynamic scenarios
SCENARIOS["start_game"] = scenario_start_game
SCENARIOS["play_full_round"] = scenario_play_full_round
SCENARIOS["shop_phase"] = scenario_shop_phase
SCENARIOS["full_ante"] = scenario_full_ante
SCENARIOS["full_game"] = scenario_full_game


# ─── Interactive Console ─────────────────────────────────────────────────────

class InteractiveConsole:
    """Async REPL for manual testing."""

    def __init__(self, state: StateTracker, scenario_runner: ScenarioRunner):
        self.state = state
        self.scenario_runner = scenario_runner
        self.ws = None
        self.running = True

    def set_ws(self, ws):
        self.ws = ws

    async def run(self):
        log_info("Interactive mode. Type 'help' for commands.")
        loop = asyncio.get_event_loop()

        while self.running:
            try:
                prompt = self._build_prompt()
                line = await loop.run_in_executor(None, lambda: input(prompt))
                line = line.strip()
                if not line:
                    continue
                await self._handle_command(line)
            except EOFError:
                break
            except KeyboardInterrupt:
                break

    def _build_prompt(self) -> str:
        n_actions = len(self.state.registered_actions)
        connected = "connected" if self.ws else "disconnected"
        ctx_age = ""
        if self.state.last_context_time:
            age = time.time() - self.state.last_context_time
            ctx_age = f" | ctx {age:.0f}s ago"
        return f"\n{C.DIM}[{connected} | {n_actions} actions{ctx_age}]{C.RESET}\n> "

    async def _handle_command(self, line: str):
        parts = line.split(None, 1)
        cmd = parts[0].lower()
        args = parts[1] if len(parts) > 1 else ""

        match cmd:
            case "help":
                self._print_help()
            case "send":
                await self._cmd_send(args)
            case "query":
                await self._cmd_query()
            case "reregister":
                await self._cmd_reregister()
            case "actions":
                self._cmd_actions()
            case "context":
                self._cmd_context()
            case "log":
                self._cmd_log(args)
            case "state":
                self._cmd_state()
            case "scenario":
                await self._cmd_scenario(args)
            case "quit" | "exit":
                self.running = False
            case _:
                log_warn(f"Unknown command: '{cmd}'. Type 'help' for commands.")

    def _print_help(self):
        print(f"""
{C.BOLD}Available commands:{C.RESET}
  send <action> [json_params]  Send an action (e.g., send play_hand)
  query                        Send query command
  reregister                   Send actions/reregister_all
  actions                      List registered actions
  context                      Show last context message
  log [n]                      Show last N messages (default 20)
  state                        Show full state summary
  scenario <name>              Run a scenario ({', '.join(SCENARIOS.keys())})
  help                         Show this help
  quit                         Exit
""")

    async def _cmd_send(self, args: str):
        if not self.ws:
            log_warn("No WebSocket connection")
            return

        parts = args.split(None, 1)
        if not parts:
            log_warn("Usage: send <action_name> [json_params]")
            return

        action_name = parts[0]
        params = None
        if len(parts) > 1:
            try:
                params = json.loads(parts[1])
            except json.JSONDecodeError as e:
                log_warn(f"Invalid JSON params: {e}")
                return

        # Check if action is registered
        if action_name not in self.state.registered_actions:
            log_warn(f"Action '{action_name}' is not currently registered. Sending anyway.")

        action_id, msg = ActionSender.build_action(action_name, params)
        future = self.state.register_pending(action_id)

        await self.ws.send(json.dumps(msg))
        self.state.on_message("send", msg)
        log_send(f"action '{action_name}' (id={action_id})")

        # Wait for result with timeout
        try:
            result = await asyncio.wait_for(future, timeout=10.0)
            if result["success"]:
                log_pass(f"Result: {result['message']}")
            else:
                log_fail(f"Result: {result['message']}")
        except asyncio.TimeoutError:
            log_warn("Timeout waiting for action result (10s)")

    async def _cmd_query(self):
        if not self.ws:
            log_warn("No WebSocket connection")
            return
        msg = ActionSender.build_query()
        await self.ws.send(json.dumps(msg))
        self.state.on_message("send", msg)
        log_send("query")

    async def _cmd_reregister(self):
        if not self.ws:
            log_warn("No WebSocket connection")
            return
        msg = ActionSender.build_reregister_all()
        await self.ws.send(json.dumps(msg))
        self.state.on_message("send", msg)
        log_send("actions/reregister_all")

    def _cmd_actions(self):
        if not self.state.registered_actions:
            print("No actions registered.")
            return
        print(f"\n{C.BOLD}Registered actions ({len(self.state.registered_actions)}):{C.RESET}")
        for name in sorted(self.state.registered_actions.keys()):
            action = self.state.registered_actions[name]
            desc = action.get("description", "")[:80]
            has_schema = "schema" in action or "parameters" in action
            schema_indicator = f" {C.DIM}[params]{C.RESET}" if has_schema else ""
            print(f"  {C.CYAN}{name}{C.RESET}{schema_indicator} - {desc}")

    def _cmd_context(self):
        if not self.state.last_context:
            print("No context received yet.")
            return
        age = time.time() - self.state.last_context_time if self.state.last_context_time else 0
        print(f"\n{C.BOLD}Last context ({age:.1f}s ago):{C.RESET}")
        print(self.state.last_context)

    def _cmd_log(self, args: str):
        n = 20
        if args:
            try:
                n = int(args)
            except ValueError:
                pass
        entries = self.state.message_log[-n:]
        if not entries:
            print("No messages logged.")
            return
        print(f"\n{C.BOLD}Last {len(entries)} messages:{C.RESET}")
        for entry in entries:
            ts = time.strftime("%H:%M:%S", time.localtime(entry.timestamp))
            direction = f"{C.CYAN}RECV{C.RESET}" if entry.direction == "recv" else f"{C.MAGENTA}SEND{C.RESET}"
            cmd = entry.message.get("command", "?")
            detail = ""
            if cmd == "actions/register":
                actions = entry.message.get("data", {}).get("actions", [])
                names = [a.get("name", "?") for a in actions]
                detail = f" [{', '.join(names)}]"
            elif cmd == "actions/unregister":
                names = entry.message.get("data", {}).get("action_names", [])
                detail = f" [{', '.join(names)}]"
            elif cmd == "context":
                text = entry.message.get("data", {}).get("message", "")[:60]
                detail = f" \"{text}...\""
            elif cmd == "action":
                name = entry.message.get("data", {}).get("name", "?")
                detail = f" [{name}]"
            elif cmd == "action/result":
                data = entry.message.get("data", {})
                status = "ok" if data.get("success") else "fail"
                detail = f" [{status}: {data.get('message', '')[:40]}]"
            print(f"  {ts} {direction} {cmd}{detail}")

    def _cmd_state(self):
        print(f"\n{C.BOLD}State Summary:{C.RESET}")
        print(self.state.get_summary())

    async def _cmd_scenario(self, name: str):
        name = name.strip()
        if name not in SCENARIOS:
            log_warn(f"Unknown scenario '{name}'. Available: {', '.join(sorted(SCENARIOS.keys()))}")
            return
        await self.scenario_runner.run_scenario(name, SCENARIOS[name])


# ─── Main Server ─────────────────────────────────────────────────────────────

class NeuroSDKServer:
    """WebSocket server impersonating the Neuro-sama SDK."""

    def __init__(self, port: int = 8000, verbose: bool = False,
                 scenario: str | None = None, interactive: bool = False):
        self.port = port
        self.verbose = verbose
        self.scenario_name = scenario
        self.interactive = interactive
        self.validator = ProtocolValidator()
        self.state = StateTracker()
        self.scenario_runner = ScenarioRunner(self.state, verbose)
        self.console = InteractiveConsole(self.state, self.scenario_runner)
        self.ws = None
        self.scenario_passed = True
        self._scenarios_done = False

    async def handler(self, websocket):
        log_info(f"Client connected from {websocket.remote_address}")
        self.ws = websocket
        self.state.on_connect()
        self.scenario_runner.set_ws(websocket)
        self.console.set_ws(websocket)

        # Run scenario as fire-and-forget (don't kill connection when it finishes)
        scenario_task = None
        if self.scenario_name and not self._scenarios_done:
            scenarios_to_run = (
                list(SCENARIOS.keys()) if self.scenario_name == "all"
                else [self.scenario_name]
            )
            scenario_task = asyncio.create_task(
                self._run_scenarios(scenarios_to_run)
            )

        # The receive loop is the primary task - connection lives as long as it does
        try:
            await self._receive_loop(websocket)
        except Exception as e:
            log_warn(f"Handler error: {e}")
        finally:
            self.ws = None
            self.scenario_runner.set_ws(None)
            self.console.set_ws(None)
            if scenario_task and not scenario_task.done():
                scenario_task.cancel()
            log_info("Client disconnected")

    async def _receive_loop(self, websocket):
        try:
            async for raw_message in websocket:
                try:
                    msg = json.loads(raw_message)
                except json.JSONDecodeError:
                    log_warn(f"Invalid JSON: {raw_message[:100]}")
                    continue

                # Validate
                errors = self.validator.validate(msg)
                if errors:
                    self.state.validation_errors.append((time.time(), errors))
                    for err in errors:
                        log_warn(f"Protocol error: {err}")

                # Track state
                cmd = msg.get("command", "")
                self.state.on_message("recv", msg)

                match cmd:
                    case "startup":
                        self.state.on_startup()
                        log_recv("startup")
                    case "context":
                        data = msg.get("data", {})
                        message = data.get("message", "")
                        silent = data.get("silent", False)
                        self.state.on_context(message, silent)
                        silent_tag = " [silent]" if silent else ""
                        log_verbose(f"context{silent_tag}: {message[:100]}...", self.verbose)
                        if not self.verbose:
                            log_recv(f"context{silent_tag} ({len(message)} chars)")
                    case "actions/register":
                        actions = msg.get("data", {}).get("actions", [])
                        self.state.on_register(actions)
                        names = [a.get("name", "?") for a in actions]
                        log_recv(f"actions/register: {', '.join(names)}")
                    case "actions/unregister":
                        names = msg.get("data", {}).get("action_names", [])
                        self.state.on_unregister(names)
                        log_recv(f"actions/unregister: {', '.join(names)}")
                    case "action/result":
                        data = msg.get("data", {})
                        aid = data.get("id", "")
                        success = data.get("success", False)
                        result_msg = data.get("message", "")
                        self.state.on_action_result(aid, success, result_msg)
                        status = f"{C.GREEN}success{C.RESET}" if success else f"{C.RED}failure{C.RESET}"
                        log_recv(f"action/result (id={aid}): {status} - {result_msg}")
                    case _:
                        log_recv(f"unknown command: {cmd}")

                # Feed to scenario runner
                self.scenario_runner.feed_message(msg)

        except websockets.exceptions.ConnectionClosed:
            pass

    async def _run_scenarios(self, scenario_names: list[str]):
        # Small delay to let initial messages arrive
        await asyncio.sleep(0.5)

        all_passed = True
        for name in scenario_names:
            if name not in SCENARIOS:
                log_warn(f"Unknown scenario: '{name}'. Available: {', '.join(SCENARIOS.keys())}")
                all_passed = False
                continue
            passed = await self.scenario_runner.run_scenario(name, SCENARIOS[name])
            if not passed:
                all_passed = False

        self.scenario_passed = all_passed
        self._scenarios_done = True
        self._print_report()

        # If not interactive, signal shutdown
        if not self.interactive:
            log_info("Scenarios complete. Shutting down.")
            await asyncio.sleep(0.5)
            # Close the WebSocket to trigger clean exit
            if self.ws:
                await self.ws.close()

    def _print_report(self):
        print(f"\n{'='*60}")
        print(f"{C.BOLD}Test Harness Report{C.RESET}")
        print(f"{'='*60}")
        print(self.state.get_summary())
        print()

        if self.state.validation_errors:
            print(f"{C.BOLD}Protocol Validation Errors:{C.RESET}")
            for ts, errors in self.state.validation_errors:
                t = time.strftime("%H:%M:%S", time.localtime(ts))
                for err in errors:
                    print(f"  {C.RED}[{t}] {err}{C.RESET}")
            print()

        if self.scenario_runner.results:
            print(f"{C.BOLD}Scenario Step Results:{C.RESET}")
            for r in self.scenario_runner.results:
                icon = f"{C.GREEN}PASS{C.RESET}" if r.passed else f"{C.RED}FAIL{C.RESET}"
                print(f"  [{icon}] {r.message}")

        if self.scenario_runner.results:
            passed_count = sum(1 for r in self.scenario_runner.results if r.passed)
            total = len(self.scenario_runner.results)
            overall = f"{C.GREEN}ALL PASSED{C.RESET}" if self.scenario_passed else f"{C.RED}FAILURES{C.RESET}"
            print(f"\n{C.BOLD}Overall: {overall} ({passed_count}/{total} steps){C.RESET}")
        else:
            overall = f"{C.GREEN}PASSED{C.RESET}" if self.scenario_passed else f"{C.RED}FAILED{C.RESET}"
            print(f"\n{C.BOLD}Overall: {overall}{C.RESET}")

        # Coverage report
        print(f"\n{C.BOLD}Coverage Report:{C.RESET}")
        print(self.state.get_coverage_report())
        print(f"{'='*60}\n")

    async def run(self):
        log_info(f"Neuro SDK Test Harness starting on port {self.port}")
        log_info(f"Mode: {'interactive' if self.interactive else 'automated'}")
        if self.scenario_name:
            log_info(f"Scenario: {self.scenario_name}")
        log_info("Waiting for Balatro mod to connect...\n")

        # Disable automatic ping/pong - the mod has its own ping mechanism
        # and its custom WebSocket client may not respond to the library's pings
        async with serve(self.handler, "localhost", self.port,
                         ping_interval=None, ping_timeout=None):
            if self.interactive:
                # In interactive mode, run console until user quits
                await self.console.run()
            else:
                # In auto mode, wait for scenarios to complete
                while not self._scenarios_done:
                    await asyncio.sleep(0.5)


# ─── Entry Point ─────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(
        description="NeurosamaBalatro Integration Test Harness"
    )
    parser.add_argument("--port", type=int, default=8000,
                        help="WebSocket server port (default: 8000)")
    parser.add_argument("--scenario", type=str, default=None,
                        help=f"Run a specific scenario (default: all). Available: {', '.join(list(SCENARIOS.keys()) + ['all'])}")
    parser.add_argument("--interactive", action="store_true",
                        help="Enable interactive REPL mode")
    parser.add_argument("--verbose", action="store_true",
                        help="Show all raw message contents")

    args = parser.parse_args()

    # Default behavior: run all scenarios if no scenario specified and not interactive-only
    scenario = args.scenario
    if not args.interactive and scenario is None:
        scenario = "all"

    server = NeuroSDKServer(
        port=args.port,
        verbose=args.verbose,
        scenario=scenario,
        interactive=args.interactive,
    )

    try:
        asyncio.run(server.run())
    except KeyboardInterrupt:
        log_info("Interrupted. Shutting down.")

    sys.exit(0 if server.scenario_passed else 1)


if __name__ == "__main__":
    main()
