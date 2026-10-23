"""Encodes the music and ambience WAVs to Ogg Vorbis for the game (ADR-083).

    .venv/bin/python game/tools/encode_ogg.py DST SRC.wav...

Writes DST/<name>.ogg for each SRC. q4 (audio/compare/README.md has the
comparison). The output is byte-for-byte reproducible: libsndfile picks a
random stream serial, so it is set to one derived from the name and every
page's CRC redone. A file whose WAV hasn't changed isn't rewritten.

Needs soundfile in .venv (`.venv/bin/pip install soundfile`).
"""

import os
import sys
import zlib

import soundfile as sf

QUALITY = 4                       # oggenc's -q scale, 0..10


def _crc_table():
    table = []
    for i in range(256):
        r = i << 24
        for _ in range(8):
            r = ((r << 1) ^ 0x04C11DB7) if r & 0x80000000 else r << 1
        table.append(r & 0xFFFFFFFF)
    return table


_CRC = _crc_table()


def _ogg_crc(page):
    crc = 0
    for b in page:
        crc = ((crc << 8) & 0xFFFFFFFF) ^ _CRC[((crc >> 24) ^ b) & 0xFF]
    return crc


def fix_serial(data, serial):
    """Every page's stream serial set to `serial`, its CRC recomputed."""
    out = bytearray(data)
    pos = 0
    while pos < len(out):
        assert out[pos:pos + 4] == b"OggS", "not an Ogg page at %d" % pos
        nseg = out[pos + 26]
        size = 27 + nseg + sum(out[pos + 27:pos + 27 + nseg])
        out[pos + 14:pos + 18] = serial.to_bytes(4, "little")
        out[pos + 22:pos + 26] = b"\0\0\0\0"
        out[pos + 22:pos + 26] = _ogg_crc(out[pos:pos + size]).to_bytes(4, "little")
        pos += size
    return bytes(out)


def encode(src, dst):
    data, sr = sf.read(src, dtype="float64")
    sf.write(dst, data, sr, format="OGG", subtype="VORBIS",
             compression_level=1 - QUALITY / 10)
    name = os.path.splitext(os.path.basename(dst))[0]
    with open(dst, "rb") as fh:
        raw = fh.read()
    with open(dst, "wb") as fh:
        fh.write(fix_serial(raw, zlib.crc32(name.encode())))
    st = os.stat(src)
    os.utime(dst, (st.st_atime, st.st_mtime))   # "unchanged" = same mtime


def main():
    dst_dir, srcs = sys.argv[1], sys.argv[2:]
    os.makedirs(dst_dir, exist_ok=True)
    n = 0
    for src in srcs:
        name = os.path.splitext(os.path.basename(src))[0]
        dst = os.path.join(dst_dir, name + ".ogg")
        if os.path.exists(dst) and int(os.stat(dst).st_mtime) == int(os.stat(src).st_mtime):
            continue
        encode(src, dst)
        n += 1
    print("encoded %d of %d to Ogg q%d" % (n, len(srcs), QUALITY))


if __name__ == "__main__":
    main()
