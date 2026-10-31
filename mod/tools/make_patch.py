# Undertale Essentials. Copyright (C) 2026 Pixeo.
# Free software under the GNU GPL version 3 or later: see LICENSE.
"""Makes a binary patch that turns the original data.win into the modded one.

    python make_patch.py <original data.win> <modded .win> <out .patch>

Format (applied by installer/install.ps1):
    b"UTFLPATCH1\\n", SHA-1 of the original (20 bytes), SHA-1 of the result (20 bytes),
    result length (uint64 LE), then a raw-deflate stream of operations:
        b"C" offset:uint64 length:uint64   copy from the original
        b"I" length:uint64 bytes...        insert new bytes
The patch holds only the bytes that changed, so it can be shared without the game's files.
"""
import hashlib
import struct
import sys
import zlib

KEY = 32        # bytes hashed to find a match
STEP = 16       # original is indexed every STEP bytes
MIN_COPY = 64   # shorter matches are cheaper as plain bytes


def make_patch(orig, new):
    index = {}
    for i in range(0, len(orig) - KEY + 1, STEP):
        index.setdefault(hash(orig[i:i + KEY]), i)

    ops = []
    lit_start = 0
    p = 0
    n = len(new)
    while p <= n - KEY:
        q = index.get(hash(new[p:p + KEY]))
        if q is None or orig[q:q + KEY] != new[p:p + KEY]:
            p += 1
            continue
        # extend forward in shrinking strides
        length = KEY
        stride = 1 << 16
        while stride >= 1:
            a, b = p + length, q + length
            if a + stride <= n and b + stride <= len(orig) and new[a:a + stride] == orig[b:b + stride]:
                length += stride
            else:
                stride //= 2
        # extend backward into the pending literal
        back = 0
        while p - back - 1 >= lit_start and q - back - 1 >= 0 and new[p - back - 1] == orig[q - back - 1]:
            back += 1
        if length + back < MIN_COPY:
            p += 1
            continue
        if p - back > lit_start:
            ops.append(('I', new[lit_start:p - back]))
        ops.append(('C', q - back, length + back))
        p += length
        lit_start = p
    if lit_start < n:
        ops.append(('I', new[lit_start:]))
    return ops


def encode(ops):
    out = bytearray()
    for op in ops:
        if op[0] == 'C':
            out += b'C' + struct.pack('<QQ', op[1], op[2])
        else:
            out += b'I' + struct.pack('<Q', len(op[1])) + op[1]
    comp = zlib.compressobj(9, zlib.DEFLATED, -15)
    return comp.compress(bytes(out)) + comp.flush()


def apply(orig, data):
    """Reference implementation, used to check every patch right after making it."""
    raw = zlib.decompress(data, -15)
    out = bytearray()
    i = 0
    while i < len(raw):
        t = raw[i:i + 1]
        if t == b'C':
            off, ln = struct.unpack_from('<QQ', raw, i + 1)
            out += orig[off:off + ln]
            i += 17
        else:
            (ln,) = struct.unpack_from('<Q', raw, i + 1)
            out += raw[i + 9:i + 9 + ln]
            i += 9 + ln
    return bytes(out)


def main():
    orig_path, new_path, out_path = sys.argv[1:4]
    orig = open(orig_path, 'rb').read()
    new = open(new_path, 'rb').read()
    ops = make_patch(orig, new)
    body = encode(ops)
    header = b'UTFLPATCH1\n' + hashlib.sha1(orig).digest() + hashlib.sha1(new).digest() + struct.pack('<Q', len(new))
    if apply(orig, body) != new:
        raise SystemExit('patch check failed')
    with open(out_path, 'wb') as f:
        f.write(header + body)
    copied = sum(op[2] for op in ops if op[0] == 'C')
    print(f'{len(ops)} operations, {copied / len(new):.1%} copied from the original, '
          f'patch {len(header) + len(body):,} bytes')


if __name__ == '__main__':
    main()
