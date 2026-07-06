"""Low-level Unix socket client for the DOSBox-X MCP debug interface."""

import socket
import threading
from typing import Optional


class ResponseTimeout(Exception):
    """No response within the timeout. The connection is kept open and the
    response stays *pending* — collect it later with wait_response()."""


class PendingResponse(Exception):
    """A previous command's response has not been collected yet."""


class DebugSocketClient:
    """
    Connects to the DOSBox-X MCP debug socket and provides synchronous
    command/response communication.

    Protocol: client sends "COMMAND\n", server replies with output lines
    terminated by a bare "END\n" line.

    The DOSBox-X side processes commands only while its emulation thread is
    inside the debugger loop; while the game free-runs, a sent command sits
    queued until the next debugger entry (breakpoint hit / BREAK request).
    A read timeout therefore must NOT tear down the connection — the reply
    will still arrive later.  This client keeps the response *pending* on
    timeout and lets the caller collect it with wait_response().
    """

    END_MARKER = b'\nEND\n'

    def __init__(self, sock_path: str, timeout: float = 60.0):
        self._path = sock_path
        self._timeout = timeout
        self._sock: Optional[socket.socket] = None
        self._lock = threading.Lock()
        self._rxbuf = b''
        self._pending = False

    def connect(self) -> None:
        if self._sock is not None:
            return
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.settimeout(self._timeout)
        s.connect(self._path)
        self._sock = s
        self._rxbuf = b''
        self._pending = False

    def disconnect(self) -> None:
        if self._sock:
            try:
                self._sock.close()
            except OSError:
                pass
            self._sock = None
        self._rxbuf = b''
        self._pending = False

    def is_connected(self) -> bool:
        return self._sock is not None

    def has_pending(self) -> bool:
        return self._pending

    def command(self, cmd: str, timeout: Optional[float] = None) -> str:
        """Send a command and wait for its response.

        Raises PendingResponse if an earlier response is still outstanding,
        ResponseTimeout if the reply doesn't arrive in time (response stays
        pending; use wait_response() to collect it later).
        """
        with self._lock:
            if self._pending:
                raise PendingResponse(
                    "a previous command's response is still pending — "
                    "collect it first (wait_response)")
            if self._sock is None:
                self.connect()
            self._send_locked(cmd)
            self._pending = True
            return self._recv_locked(timeout)

    def send_only(self, cmd: str) -> None:
        """Send a command without waiting; response becomes pending."""
        with self._lock:
            if self._pending:
                raise PendingResponse(
                    "a previous command's response is still pending")
            if self._sock is None:
                self.connect()
            self._send_locked(cmd)
            self._pending = True

    def send_raw(self, cmd: str) -> None:
        """Send a command with NO response tracking — shutdown path only.
        The QUIT command kills the emulator before a reply is written, and a
        BREAK sent while already paused never gets one; normal pending
        bookkeeping would wedge on either."""
        with self._lock:
            if self._sock is None:
                self.connect()
            self._send_locked(cmd)

    def wait_response(self, timeout: Optional[float] = None) -> str:
        """Collect the pending response (e.g. a RUN's break notification)."""
        with self._lock:
            if not self._pending:
                raise PendingResponse("no response is pending")
            return self._recv_locked(timeout)

    # -- internals (call with self._lock held) --

    def _send_locked(self, cmd: str) -> None:
        try:
            self._sock.sendall((cmd.strip() + '\n').encode())
        except OSError:
            self.disconnect()
            raise

    def _recv_locked(self, timeout: Optional[float]) -> str:
        sock = self._sock
        old_timeout = sock.gettimeout()
        if timeout is not None:
            sock.settimeout(timeout)
        try:
            while self.END_MARKER not in self._rxbuf and self._rxbuf != b'END\n':
                chunk = sock.recv(4096)
                if not chunk:
                    self.disconnect()
                    raise ConnectionError("DOSBox-X closed the connection")
                self._rxbuf += chunk
        except socket.timeout:
            raise ResponseTimeout(
                "no response yet — DOSBox-X is executing (the reply arrives "
                "at the next debugger entry)")
        except OSError:
            self.disconnect()
            raise
        finally:
            if self._sock:
                self._sock.settimeout(old_timeout)

        if self._rxbuf == b'END\n':
            raw, self._rxbuf = self._rxbuf, b''
        else:
            end = self._rxbuf.index(self.END_MARKER) + len(self.END_MARKER)
            raw, self._rxbuf = self._rxbuf[:end], self._rxbuf[end:]
        self._pending = False
        text = raw.decode(errors='replace')
        if text.endswith('END\n'):
            text = text[:-len('END\n')]
        return text.strip()
