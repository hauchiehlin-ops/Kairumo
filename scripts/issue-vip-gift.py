#!/usr/bin/env python3
"""
Kairumo Pro — Serverless Ed25519 VIP Gift Pass Generator (Method 5)
===================================================================
Generates cryptographically signed `kairumo://vip?gift=<payload>.<sig>` deep links
that unlock Kairumo Pro forever on Apple devices via `CryptoKit.Curve25519.Signing`.

Zero external dependencies: includes a standard RFC 8032 Ed25519 implementation
using Python's built-in `hashlib.sha512`.

Usage examples:
  # Issue a permanent VIP gift pass for a friend / reviewer / educator:
  python3 scripts/issue-vip-gift.py --recipient "Prof. Lin" --note "Academic VIP"

  # Issue a pass with an expiration date (YYYY-MM-DD):
  python3 scripts/issue-vip-gift.py --recipient "Beta Tester" --expires 2027-12-31

  # Verify a generated link:
  python3 scripts/issue-vip-gift.py --verify "kairumo://vip?gift=..."

  # Run RFC 8032 & token self-test:
  python3 scripts/issue-vip-gift.py --self-test
"""

from __future__ import annotations

import argparse
import base64
import datetime as dt
import hashlib
import json
import os
import sys
import urllib.parse
import uuid

# ---------------------------------------------------------------------------
# Pure-Python RFC 8032 Ed25519 Implementation (Zero external dependencies)
#Compatible with Apple CryptoKit `Curve25519.Signing.PublicKey`
# ---------------------------------------------------------------------------

_B = 256
_Q = 2**255 - 19
_L = 2**252 + 27742317777372353535851937790883648493


def _inv(x: int) -> int:
    return pow(x, _Q - 2, _Q)


_D = (-121665 * _inv(121666)) % _Q
_I = pow(2, (_Q - 1) // 4, _Q)


def _xrecover(y: int) -> int:
    xx = (y * y - 1) * _inv(_D * y * y + 1)
    x = pow(xx, (_Q + 3) // 8, _Q)
    if (x * x - xx) % _Q != 0:
        x = (x * _I) % _Q
    if x % 2 != 0:
        x = _Q - x
    return x


_BY = (4 * _inv(5)) % _Q
_BX = _xrecover(_BY)
_B_PT = (_BX % _Q, _BY % _Q, 1, (_BX * _BY) % _Q)
_IDENT = (0, 1, 1, 0)


def _edwards_add(p: tuple[int, int, int, int], q: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    x1, y1, z1, t1 = p
    x2, y2, z2, t2 = q
    a = ((y1 - x1) * (y2 - x2)) % _Q
    b = ((y1 + x1) * (y2 + x2)) % _Q
    c = (t1 * 2 * _D * t2) % _Q
    d = (z1 * 2 * z2) % _Q
    e = (b - a) % _Q
    f = (d - c) % _Q
    g = (d + c) % _Q
    h = (b + a) % _Q
    return (e * f) % _Q, (g * h) % _Q, (f * g) % _Q, (e * h) % _Q


def _scalarmult(p: tuple[int, int, int, int], e: int) -> tuple[int, int, int, int]:
    res = _IDENT
    cur = p
    while e > 0:
        if e & 1:
            res = _edwards_add(res, cur)
        cur = _edwards_add(cur, cur)
        e >>= 1
    return res


def _encodepoint(p: tuple[int, int, int, int]) -> bytes:
    x, y, z, _ = p
    zi = _inv(z)
    x = (x * zi) % _Q
    y = (y * zi) % _Q
    bits = y | ((x & 1) << 255)
    return bits.to_bytes(32, "little")


def _decodepoint(s: bytes) -> tuple[int, int, int, int]:
    if len(s) != 32:
        raise ValueError("Invalid public key length")
    unclamped = int.from_bytes(s, "little")
    sign = (unclamped >> 255) & 1
    y = unclamped & ((1 << 255) - 1)
    if y >= _Q:
        raise ValueError("Public key y out of range")
    x = _xrecover(y)
    if (x & 1) != sign:
        x = _Q - x
    p = (x, y, 1, (x * y) % _Q)
    return p


def ed25519_publickey(sk_seed: bytes) -> bytes:
    if len(sk_seed) != 32:
        raise ValueError("Ed25519 private seed must be 32 bytes")
    h = hashlib.sha512(sk_seed).digest()
    a = int.from_bytes(h[:32], "little")
    a &= (1 << 254) - 8
    a |= 1 << 254
    return _encodepoint(_scalarmult(_B_PT, a))


def ed25519_sign(msg: bytes, sk_seed: bytes) -> bytes:
    h = hashlib.sha512(sk_seed).digest()
    a = int.from_bytes(h[:32], "little")
    a &= (1 << 254) - 8
    a |= 1 << 254
    prefix = h[32:]
    pk = _encodepoint(_scalarmult(_B_PT, a))
    r = int.from_bytes(hashlib.sha512(prefix + msg).digest(), "little") % _L
    r_pt = _encodepoint(_scalarmult(_B_PT, r))
    k = int.from_bytes(hashlib.sha512(r_pt + pk + msg).digest(), "little") % _L
    s = (r + k * a) % _L
    return r_pt + s.to_bytes(32, "little")


def ed25519_verify(msg: bytes, sig: bytes, pk: bytes) -> bool:
    if len(sig) != 64 or len(pk) != 32:
        return False
    try:
        a_pt = _decodepoint(pk)
        r_pt = _decodepoint(sig[:32])
    except ValueError:
        return False
    s = int.from_bytes(sig[32:], "little")
    if s >= _L:
        return False
    k = int.from_bytes(hashlib.sha512(sig[:32] + pk + msg).digest(), "little") % _L
    lhs = _scalarmult(_B_PT, s)
    # rhs = R + k * A
    rhs = _edwards_add(r_pt, _scalarmult(a_pt, k))
    return _encodepoint(lhs) == _encodepoint(rhs)


# ---------------------------------------------------------------------------
# Default Kairumo Developer VIP Seed & Public Key
# Override in production via env `KAIRUMO_VIP_SEED_HEX` (64 hex chars).
# Corresponding public key Base64 is embedded in `EntitlementManager.swift`:
#   Public Key (Base64): "F+SF0OIF+lUDASUaK4Hi3Iu1kYTUmDfbmF0kdOATeYc="
# ---------------------------------------------------------------------------

DEFAULT_DEV_SEED_HEX = "4b616972756d6f50726f5649504d617374657249737375657253656564323032"


def _get_seed_bytes(custom_hex: str | None = None) -> bytes:
    hex_str = custom_hex or os.environ.get("KAIRUMO_VIP_SEED_HEX") or DEFAULT_DEV_SEED_HEX
    seed = bytes.fromhex(hex_str.strip())
    if len(seed) != 32:
        raise ValueError("Seed must be exactly 32 bytes (64 hex characters)")
    return seed


def _b64url_encode(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).decode("ascii").rstrip("=")


def _b64url_decode(text: str) -> bytes:
    padded = text + "=" * ((4 - len(text) % 4) % 4)
    return base64.urlsafe_b64decode(padded.encode("ascii"))


def issue_vip_gift_url(
    recipient: str,
    note: str = "",
    expires_date: str | None = None,
    seed_hex: str | None = None,
) -> tuple[str, dict, str]:
    seed = _get_seed_bytes(seed_hex)
    pk = ed25519_publickey(seed)
    pk_b64 = base64.b64encode(pk).decode("ascii")

    now_ts = int(dt.datetime.now(dt.timezone.utc).timestamp())
    payload: dict[str, object] = {
        "tier": "pro_lifetime",
        "id": str(uuid.uuid4())[:8],
        "to": recipient,
        "iat": now_ts,
    }
    if note:
        payload["note"] = note
    if expires_date:
        exp_dt = dt.datetime.strptime(expires_date, "%Y-%m-%d").replace(
            hour=23, minute=59, second=59, tzinfo=dt.timezone.utc
        )
        payload["exp"] = int(exp_dt.timestamp())

    payload_bytes = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
    sig_bytes = ed25519_sign(payload_bytes, seed)

    token = f"{_b64url_encode(payload_bytes)}.{_b64url_encode(sig_bytes)}"
    url = f"kairumo://vip?gift={token}"
    return url, payload, pk_b64


def verify_vip_gift_url(url_or_token: str, seed_hex: str | None = None) -> tuple[bool, str, dict | None]:
    seed = _get_seed_bytes(seed_hex)
    pk = ed25519_publickey(seed)

    token = url_or_token.strip()
    if "://" in token:
        parsed = urllib.parse.urlparse(token)
        qs = urllib.parse.parse_qs(parsed.query)
        gift_vals = qs.get("gift", [])
        if not gift_vals:
            return False, "Missing `gift` query parameter in URL", None
        token = gift_vals[0]

    parts = token.split(".")
    if len(parts) != 2:
        return False, "Invalid token format (expected <payload>.<sig>)", None

    try:
        payload_bytes = _b64url_decode(parts[0])
        sig_bytes = _b64url_decode(parts[1])
    except Exception as exc:
        return False, f"Base64URL decode error: {exc}", None

    if not ed25519_verify(payload_bytes, sig_bytes, pk):
        return False, "Ed25519 signature verification FAILED", None

    try:
        payload = json.loads(payload_bytes.decode("utf-8"))
    except Exception as exc:
        return False, f"JSON decode error: {exc}", None

    if payload.get("tier") != "pro_lifetime":
        return False, f"Unsupported tier: {payload.get('tier')}", payload

    exp = payload.get("exp")
    if isinstance(exp, (int, float)):
        now_ts = int(dt.datetime.now(dt.timezone.utc).timestamp())
        if now_ts > int(exp):
            return False, "Token has expired", payload

    return True, "Valid Ed25519 VIP Gift Pass", payload


def _run_self_test() -> int:
    # RFC 8032 Section 7.1 TEST 1 vector
    rfc_sk = bytes.fromhex("9d61b19deffd5a60ba844af492ec2cc44449c5697b326919703bac031cae7f60")
    rfc_pk_expected = bytes.fromhex("d75a980182b10ab7d54bfed3c964073a0ee172f3daa62325af021a68f707511a")
    rfc_sig_expected = bytes.fromhex(
        "e5564300c360ac729086e2cc806e828a84877f1eb8e5d974d873e06522490155"
        "5fb8821590a33bacc61e39701cf9b46bd25bf5f0595bbe24655141438e7a100b"
    )
    assert ed25519_publickey(rfc_sk) == rfc_pk_expected, "RFC 8032 public key mismatch"
    assert ed25519_sign(b"", rfc_sk) == rfc_sig_expected, "RFC 8032 signature mismatch"
    assert ed25519_verify(b"", rfc_sig_expected, rfc_pk_expected), "RFC 8032 verify failed"

    url, payload, pk_b64 = issue_vip_gift_url("SelfTest User", note="Automated check")
    ok, msg, decoded = verify_vip_gift_url(url)
    assert ok and decoded == payload, f"Roundtrip verification failed: {msg}"

    # Tamper check
    tampered = url[:-4] + "AAAA"
    ok_bad, _, _ = verify_vip_gift_url(tampered)
    assert not ok_bad, "Tampered signature must be rejected"

    print(f"OK: RFC 8032 Ed25519 & Kairumo VIP Gift Pass self-test passed.")
    print(f"Embedded Public Key (Base64): {pk_b64}")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Issue or verify Kairumo Pro VIP Gift Pass links.")
    parser.add_argument("--recipient", "-r", default="VIP Guest", help="Recipient name or label")
    parser.add_argument("--note", "-n", default="", help="Optional memo attached to the pass")
    parser.add_argument("--expires", "-e", default=None, help="Optional expiration date (YYYY-MM-DD)")
    parser.add_argument("--seed-hex", default=None, help="Custom 64-char hex Ed25519 private seed")
    parser.add_argument("--verify", "-v", default=None, help="Verify a kairumo://vip?gift=... URL or token")
    parser.add_argument("--self-test", action="store_true", help="Run RFC 8032 & roundtrip verification tests")
    args = parser.parse_args()

    if args.self_test:
        return _run_self_test()

    if args.verify:
        ok, msg, payload = verify_vip_gift_url(args.verify, args.seed_hex)
        print(f"Status : {'VALID' if ok else 'INVALID'} ({msg})")
        if payload:
            print(f"Payload: {json.dumps(payload, ensure_ascii=False, indent=2)}")
        return 0 if ok else 1

    url, payload, pk_b64 = issue_vip_gift_url(
        recipient=args.recipient,
        note=args.note,
        expires_date=args.expires,
        seed_hex=args.seed_hex,
    )
    print("=" * 72)
    print("Kairumo Pro — VIP Gift Pass Issued")
    print("=" * 72)
    print(f"Recipient         : {payload.get('to')}")
    print(f"Pass ID           : {payload.get('id')}")
    if payload.get("note"):
        print(f"Note              : {payload.get('note')}")
    print(f"Expiration        : {args.expires or 'Never (Lifetime)'}")
    print(f"Public Key (B64)  : {pk_b64}")
    print("-" * 72)
    print("Send this link to the recipient (tap in iMessage / Mail / Safari / QR):")
    print(f"\n  {url}\n")
    print("=" * 72)
    return 0


if __name__ == "__main__":
    sys.exit(main())
