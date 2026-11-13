"""Lease heartbeat and lease-bound subprocess execution for the device signer."""
from __future__ import annotations

import copy
import os
import re
import signal
import subprocess
import threading
import time

from device_provisioning import ProvisioningError

HEARTBEAT_SECONDS = 60
RETRY_SECONDS = 10
MAX_DURATION_SECONDS = 1800
EXPIRY_MARGIN_SECONDS = 15
LOST_RENEWAL = re.compile(r'^signing_(http_4[0-9]{2}|lease_response_invalid)$')


class LeaseLost(ProvisioningError):
    pass


class LeaseKeeper:
    def __init__(self, transport, job, *, now=time.time, interval=HEARTBEAT_SECONDS,
                 retry_interval=RETRY_SECONDS, max_duration=MAX_DURATION_SECONDS):
        self.transport = transport
        self.now = now
        self.interval = interval
        self.retry_interval = retry_interval
        self._job = copy.deepcopy(job)
        self.started = now()
        self.hard_deadline = self.started + max_duration
        self._next = self.started + interval
        self._lock = threading.Lock()
        self._renew_lock = threading.Lock()
        self._lost = threading.Event()
        self._stop = threading.Event()
        self._thread = None
        self.reason = None
        self.renewals = 0

    def snapshot(self) -> dict:
        with self._lock:
            return copy.deepcopy(self._job)

    def lose(self, reason: str) -> None:
        with self._lock:
            if self.reason is None:
                self.reason = reason
        self._lost.set()

    @property
    def lost(self) -> bool:
        return self._lost.is_set()

    def check(self) -> None:
        current = self.now()
        with self._lock:
            deadline = self._job['lease_expires_at']
        if current >= self.hard_deadline:
            self.lose('signing_max_duration_exceeded')
        elif current >= deadline - EXPIRY_MARGIN_SECONDS:
            self.lose('signing_lease_expired')
        if self._lost.is_set():
            raise LeaseLost(self.reason)

    def renew(self) -> int:
        with self._renew_lock:
            self.check()
            try:
                data = self.transport.renew_job(self.snapshot())
            except ProvisioningError as error:
                if LOST_RENEWAL.fullmatch(str(error)):
                    self.lose('signing_lease_lost')
                    raise LeaseLost(self.reason) from None
                raise
            with self._lock:
                regressed = data['lease_expires_at'] < self._job['lease_expires_at']
                if not regressed:
                    self._job['lease_expires_at'] = data['lease_expires_at']
                    self._next = self.now() + self.interval
                    self.renewals += 1
            if regressed:
                self.lose('signing_lease_regressed')
            self.check()
            return data['lease_expires_at']

    def tick(self):
        """Run one heartbeat step; return seconds until the next step, or None once the lease is lost."""
        try:
            self.check()
            if self.now() >= self._next:
                try:
                    self.renew()
                except LeaseLost:
                    raise
                except ProvisioningError:
                    self._next = self.now() + self.retry_interval
            self.check()
        except LeaseLost:
            return None
        except Exception:
            self.lose('signing_heartbeat_failed')
            return None
        return max(0.0, self._next - self.now())

    def _run(self) -> None:
        while not self._stop.is_set():
            wait = self.tick()
            if wait is None:
                return
            self._stop.wait(min(wait, 1.0))

    def start(self) -> None:
        self._thread = threading.Thread(target=self._run, name='zolnit-lease-heartbeat', daemon=True)
        self._thread.start()

    def stop(self) -> None:
        self._stop.set()
        if self._thread is not None:
            self._thread.join(timeout=60)


class CancellableRunner:
    """Drop-in for apple_distribution.run_argv that kills the whole process group once the lease is lost."""

    def __init__(self, keeper, poll=0.5, grace=10):
        self.keeper = keeper
        self.poll = poll
        self.grace = grace
        self.last_pid = None

    def _terminate(self, process) -> None:
        for sig, wait in ((signal.SIGTERM, self.grace), (signal.SIGKILL, None)):
            try:
                os.killpg(process.pid, sig)
            except ProcessLookupError:
                pass
            try:
                process.communicate(timeout=wait)
                return
            except subprocess.TimeoutExpired:
                continue

    def __call__(self, argv) -> subprocess.CompletedProcess:
        command = list(argv)
        self.keeper.check()
        process = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                                   stderr=subprocess.PIPE, text=True, start_new_session=True)
        self.last_pid = process.pid
        try:
            while True:
                try:
                    stdout, stderr = process.communicate(timeout=self.poll)
                    break
                except subprocess.TimeoutExpired:
                    self.keeper.check()
        except BaseException:
            if process.returncode is None:
                self._terminate(process)
            raise
        if process.returncode:
            raise subprocess.CalledProcessError(process.returncode, command, stdout, stderr)
        return subprocess.CompletedProcess(command, 0, stdout, stderr)
