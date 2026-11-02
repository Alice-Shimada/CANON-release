#!/usr/bin/env python3
"""Internal, byte-preserving target view for large canonical WL rule exports.

This is a restricted representation reader, never an IBP checker or a workflow
step. Unsupported syntax falls back to the native reader. Every selected view
has its own file identity and must pass the existing native IBP audit.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import tempfile
import time

SYMBOL = rb"[A-Za-z$][A-Za-z0-9$]*(?:`[A-Za-z0-9$]+)*"
INTEGRAL = re.compile(rb"(" + SYMBOL + rb")\s*\[\s*(-?\d+(?:\s*,\s*-?\d+)*)\s*\]")
TOKEN = re.compile(rb"\s*(\d+|" + SYMBOL + rb"|[-+*/^(),\[\]])")
STRUCTURE = re.compile(rb"[\[\](){} ,\";:=']".replace(b" ", b""))
WHITESPACE = re.compile(rb"\s*")


class Unsupported(ValueError):
    pass


class InputChanged(Unsupported):
    """A bound input changed; native loading must not use different bytes."""


def integer_token(raw: bytes) -> int:
    try:
        return int(raw)
    except ValueError as exc:
        raise Unsupported("integer token exceeds the native reader's supported range") from exc


def integral(raw: bytes, head: str, arity: int) -> tuple[int, ...]:
    match = INTEGRAL.fullmatch(raw.strip())
    if not match or match[1].decode() != head:
        raise Unsupported("expected explicit declared integral head")
    indices = tuple(integer_token(x) for x in match[2].split(b","))
    if len(indices) != arity:
        raise Unsupported("integral arity mismatch")
    return indices


def integral_list(raw: bytes, head: str, arity: int) -> list[tuple[int, ...]]:
    raw = raw.strip()
    if not (raw.startswith(b"{") and raw.endswith(b"}")):
        raise Unsupported("expected integral list")
    inside, pos, values = raw[1:-1], 0, []
    while True:
        pos = WHITESPACE.match(inside, pos).end()
        if pos == len(inside):
            break
        match = INTEGRAL.match(inside, pos)
        if not match:
            raise Unsupported("noncanonical integral list")
        values.append(integral(match[0], head, arity))
        pos = match.end()
        pos = WHITESPACE.match(inside, pos).end()
        if pos == len(inside):
            break
        if inside[pos:pos + 1] != b",":
            raise Unsupported("integral list separator")
        pos += 1
        if WHITESPACE.match(inside, pos).end() == len(inside):
            raise Unsupported("trailing comma")
    if len(set(values)) != len(values):
        raise Unsupported("duplicate declared integral")
    return values


def named_integral_list(raw: bytes, name: str, head: str, arity: int):
    match = re.search(rb'"' + name.encode() + rb'"\s*->\s*(\{[^{}]*\})', raw)
    if not match:
        raise Unsupported("missing canonical list: " + name)
    return integral_list(match[1], head, arity)


class RHS:
    """Small rational-expression shape parser; never evaluates coefficients.

    States are zero Z, scalar S and homogeneous master-linear L. Rejects
    nonlinearity, master denominators, unknown functions/symbols and noninteger
    powers. Nonzero denominator proof remains a native CHECK_IBP obligation.
    """
    def __init__(self, raw, contract):
        # Put wraps sufficiently long exact integer tokens with WL line continuations.
        # Normalize only for this shape check; output and range hashes retain source bytes.
        self.raw, self.pos, self.current = re.sub(rb"\\\r?\n", b"", raw), 0, None
        self.head = contract["integral_head"].encode()
        self.arity = contract["index_count"]
        self.masters = {tuple(x) for x in contract["expected_masters"]}
        self.symbols = {x.encode() for x in contract["coefficient_symbols"]}
        self.advance()

    def advance(self):
        self.pos = WHITESPACE.match(self.raw, self.pos).end()
        if self.pos == len(self.raw):
            self.current = None
            return
        match = TOKEN.match(self.raw, self.pos)
        if not match:
            raise Unsupported("unsupported coefficient token at " + str(self.pos) + ": " + repr(self.raw[self.pos:self.pos + 70]))
        self.current, self.pos = match[1], match.end()

    def take(self, value):
        if self.current != value:
            raise Unsupported("expected " + value.decode())
        self.advance()

    def atom(self):
        value = self.current
        if value in (b"+", b"-"):
            self.advance()
            return self.atom()
        if value == b"(":
            self.advance()
            kind = self.sum()
            self.take(b")")
            return kind
        if value and value.isdigit():
            self.advance()
            return "Z" if not value.strip(b"0") else "S"
        if value == self.head:
            self.advance()
            self.take(b"[")
            indices = []
            while True:
                sign = 1
                if self.current == b"-":
                    sign = -1
                    self.advance()
                if not self.current or not self.current.isdigit():
                    raise Unsupported("noninteger integral index")
                indices.append(sign * integer_token(self.current))
                self.advance()
                if self.current != b",":
                    break
                self.advance()
            self.take(b"]")
            if len(indices) != self.arity or tuple(indices) not in self.masters:
                raise Unsupported("RHS integral is outside declared master space")
            return "L"
        if value in self.symbols:
            self.advance()
            return "S"
        raise Unsupported("undeclared symbol or unsupported function")

    def power(self):
        kind = self.atom()
        if self.current == b"^":
            self.advance()
            sign = 1
            if self.current == b"-":
                sign = -1
                self.advance()
            if not self.current or not self.current.isdigit():
                raise Unsupported("only integer powers supported")
            exponent = sign * integer_token(self.current)
            self.advance()
            if kind == "L" and exponent != 1:
                raise Unsupported("nonlinear master power")
            if kind == "Z" and exponent < 0:
                raise Unsupported("explicit zero denominator")
            if exponent == 0:
                kind = "S"
        return kind

    def product(self):
        kind = self.power()
        while self.current in (b"*", b"/"):
            op = self.current
            self.advance()
            right = self.power()
            if op == b"/":
                if right != "S":
                    raise Unsupported("zero or master-bearing denominator")
            else:
                if kind == right == "L":
                    raise Unsupported("nonlinear master product")
                kind = "Z" if "Z" in (kind, right) else "L" if "L" in (kind, right) else "S"
        return kind

    def sum(self):
        kind = self.product()
        while self.current in (b"+", b"-"):
            self.advance()
            right = self.product()
            if kind == "Z":
                kind = right
            elif right != "Z" and kind != right:
                raise Unsupported("inhomogeneous master expression")
        return kind

    def check(self):
        kind = self.sum()
        if self.current is not None or kind not in ("Z", "L"):
            raise Unsupported("unsupported or inhomogeneous RHS")


def create_view(source: Path, contract: dict, output: Path, *, chunk_bytes=1024 * 1024,
                max_rule_bytes=16 * 1024 * 1024, max_seconds=600):
    started = time.monotonic()
    before = source.stat()
    digest = hashlib.sha256()
    seen, selected = set(), set()
    if (not re.fullmatch(SYMBOL, contract["integral_head"].encode()) or
            type(contract["index_count"]) is not int or contract["index_count"] < 1 or
            not re.fullmatch(r"[0-9a-f]{64}", contract["source_sha256"])):
        raise Unsupported("invalid independent contract")
    masters = [tuple(x) for x in contract["expected_masters"]]
    if len(set(masters)) != len(masters):
        raise Unsupported("duplicate expected master")
    requested = [tuple(x) for x in contract["required_targets"]]
    if not masters or any(len(x) != contract["index_count"] or
            any(type(i) is not int for i in x) for x in masters + requested):
        raise Unsupported("invalid integral contract")
    if len(set(requested)) != len(requested):
        raise Unsupported("duplicate required target")
    wanted = set(requested) - set(masters)
    master_set = set(masters)
    rules_started, closed, stack, pending = False, False, [], bytearray()
    total_bytes, max_rule_size = 0, 0
    if output.exists():
        raise FileExistsError(output)
    temp = None

    def accept(raw, destination):
        nonlocal max_rule_size
        max_rule_size = max(max_rule_size, len(raw))
        if len(raw) > max_rule_bytes:
            raise Unsupported("rule exceeds byte budget")
        match = INTEGRAL.match(raw.lstrip())
        if not match:
            raise Unsupported("rule LHS is not an explicit integral")
        stripped = raw.lstrip()
        lhs = integral(match[0], contract["integral_head"], contract["index_count"])
        remainder = stripped[match.end():].lstrip()
        if not remainder.startswith(b"->") or remainder.startswith(b"->>"):
            raise Unsupported("only explicit immediate rules supported")
        if lhs in seen or lhs in master_set:
            raise Unsupported("duplicate rule or source master redefinition")
        seen.add(lhs)
        if lhs in wanted:
            try:
                RHS(remainder[2:], contract).check()
            except Unsupported as exc:
                raise Unsupported("selected LHS " + str(lhs) + ": " + str(exc)) from exc
            if selected:
                destination.write(b",\n")
            destination.write(raw)
            selected.add(lhs)

    try:
        with source.open("rb") as stream, tempfile.NamedTemporaryFile(
                mode="wb", dir=output.parent, prefix=output.name + ".", delete=False) as dest:
            temp = Path(dest.name)
            while chunk := stream.read(chunk_bytes):
                digest.update(chunk)
                total_bytes += len(chunk)
                if time.monotonic() - started > max_seconds:
                    raise Unsupported("rule view time budget reached")
                if not rules_started:
                    pending.extend(chunk)
                    marker = re.search(rb'"rules"\s*->\s*\{', pending)
                    if not marker:
                        if len(pending) > 1024 * 1024:
                            raise Unsupported("header exceeds bounded canonical envelope")
                        continue
                    prefix = bytes(pending[:marker.end()])
                    # Deliberately narrow export envelope; arbitrary metadata is unsupported.
                    header = re.fullmatch(rb'\s*<\|\s*"schema"\s*->\s*"canon-neu/ibp-reduction/v1"\s*,\s*'
                        rb'"family_ref"\s*->\s*"([^"\\]*)"\s*,\s*"basis_ref"\s*->\s*"([^"\\]*)"\s*,\s*'
                        rb'"masters"\s*->\s*(\{[^{}]*\})\s*,\s*"rules"\s*->\s*\{', prefix)
                    if not header:
                        raise Unsupported("unsupported canonical export envelope")
                    if header[1].decode() != contract["family_ref"] or header[2].decode() != contract["basis_ref"]:
                        raise Unsupported("family/basis identity mismatch")
                    if set(integral_list(header[3], contract["integral_head"], contract["index_count"])) != master_set:
                        raise Unsupported("source master set mismatch")
                    dest.write(prefix)
                    chunk = bytes(pending[marker.end():])
                    pending.clear()
                    rules_started = True
                if closed:
                    pending.extend(chunk)
                    if len(pending) > 1024:
                        raise Unsupported("unsupported trailing payload")
                    continue
                segment = 0
                for token in STRUCTURE.finditer(chunk):
                    ch, position = token[0], token.start()
                    if ch in (b"[", b"("):
                        stack.append(b"]" if ch == b"[" else b")")
                    elif ch in (b"]", b")"):
                        if not stack or stack.pop() != ch:
                            raise Unsupported("unbalanced export delimiters")
                    elif ch == b"," and not stack:
                        pending.extend(chunk[segment:position])
                        accept(bytes(pending), dest)
                        pending.clear()
                        segment = position + 1
                    elif ch == b"}" and not stack:
                        pending.extend(chunk[segment:position])
                        if pending.strip():
                            accept(bytes(pending), dest)
                        elif seen:
                            raise Unsupported("trailing rule comma")
                        pending = bytearray(chunk[position + 1:])
                        closed = True
                        break
                    elif ch not in (b",",):
                        raise Unsupported("unsupported export syntax")
                if not closed:
                    pending.extend(chunk[segment:])
                    if len(pending) > max_rule_bytes:
                        raise Unsupported("rule exceeds byte budget")
            if not closed or pending.strip() != b"|>":
                raise Unsupported("truncated or trailing export")
            after = source.stat()
            if (before.st_dev, before.st_ino, before.st_size, before.st_mtime_ns) != (
                    after.st_dev, after.st_ino, after.st_size, after.st_mtime_ns):
                raise InputChanged("source changed during scan")
            if digest.hexdigest() != contract["source_sha256"]:
                raise InputChanged("trusted source SHA256 mismatch")
            missing = wanted - selected
            if missing:
                raise Unsupported("missing required targets: " + str(sorted(missing)[:20]))
            dest.write(b"}|>\n")
            dest.flush()
            os.fsync(dest.fileno())
        # Atomic no-overwrite publication; simultaneous independent callers cannot clobber.
        os.link(temp, output)
        temp.unlink()
        temp = None
        output_digest = hashlib.sha256()
        with output.open("rb") as published:
            while block := published.read(chunk_bytes):
                output_digest.update(block)
        return {"schema": "canon-neu/ibp-rule-view/v1", "status": "VIEW_EXTRACTED_UNCHECKED",
            "source": str(source), "source_sha256": digest.hexdigest(), "source_bytes": total_bytes,
            "source_rules": len(seen), "masters": len(masters), "required_targets": len(requested),
            "selected_rules": len(selected), "largest_rule_bytes": max_rule_size,
            "output": str(output), "output_bytes": output.stat().st_size,
            "output_sha256": output_digest.hexdigest(),
            "elapsed_seconds": time.monotonic() - started,
            "scientific_scope": "Byte selection and restricted syntax/closure only; native IBP audit required."}
    finally:
        if temp is not None:
            temp.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("contract", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    try:
        report = create_view(args.source, json.loads(args.contract.read_text()), args.output)
    except InputChanged as exc:
        report = {"status": "INPUT_CHANGED", "reason": str(exc)}
    except (Unsupported, RecursionError, UnicodeError) as exc:
        # The Wolfram caller retains its normal reader and all acceptance gates.
        report = {"status": "UNSUPPORTED", "reason": str(exc)}
    print(json.dumps(report))


if __name__ == "__main__":
    main()
