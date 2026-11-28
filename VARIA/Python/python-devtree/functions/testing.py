"""functions.testing - test suite (V9.x / V16 self-test heritage).

Runs the engine's built-in suite plus native-parser checks for the new
modules: exif (JPEG APP1/TIFF), tags (ID3v1/ID3v2), compression
(zip/tar inspection) and the era gating in functions.editions.
Run:  python3 -m functions           (from the python/ directory)
"""

import struct
import tempfile
import zipfile
from pathlib import Path

from . import ENGINE
from . import exif, tags, compression, deps, editions


def make_jpeg_with_exif(path: Path) -> None:
    """Minimal JPEG with an APP1 EXIF segment (Make, Model, Orientation, DateTime)."""
    def tiff():
        entries = [
            (0x010F, 2, b"Cannon-X\x00"),          # Make
            (0x0110, 2, b"PyLens 42\x00"),         # Model
            (0x0112, 3, struct.pack("<H", 6)),     # Orientation
            (0x0132, 2, b"2026:11:24 10:00:00\x00"),  # DateTime
        ]
        data_area = b""
        out = b"II*\x00" + struct.pack("<I", 8)
        out += struct.pack("<H", len(entries))
        header_len = 8 + 2 + 12 * len(entries) + 4
        fixed = b""
        for tag, typ, val in entries:
            if typ == 2:
                off = header_len + len(data_area)
                fixed += struct.pack("<HHI", tag, typ, len(val)) + \
                    struct.pack("<I", off) + b"\x00\x00"
                data_area += val
            else:
                fixed += struct.pack("<HHI", tag, typ, 1)
                fixed += val + b"\x00\x00"
        out += fixed + struct.pack("<I", 0) + data_area
        return out

    exif_seg = b"Exif\x00\x00" + tiff()
    jpg = (b"\xff\xd8" + b"\xff\xe1" + struct.pack(">H", len(exif_seg) + 2)
           + exif_seg + b"\xff\xd9")
    path.write_bytes(jpg)


def make_mp3_with_id3(path: Path) -> None:
    """ID3v2.3 header (title/artist/album) + ID3v1 tail."""
    def frame(fid: bytes, text: str) -> bytes:
        raw = text.encode("latin-1")
        return fid + struct.pack(">I", len(raw) + 1) + b"\x00\x00" + b"\x00" + raw

    frames = (frame(b"TIT2", "Test Song") + frame(b"TPE1", "Test Artist")
              + frame(b"TALB", "Test Album"))
    body = b"ID3" + bytes([3, 0, 0]) + struct.pack(">I", len(frames)) + frames
    v1 = b"TAG" + b"v1 Song".ljust(30, b"\x00") + \
        b"v1 Artist".ljust(30, b"\x00") + b"v1 Album".ljust(30, b"\x00") + b"2026"
    v1 += b"\x00" * 28 + b"\x00" + b"\x02" + b"\x11"
    path.write_bytes(body + b"\x00" * 64 + v1[:128])


def run_module_tests() -> tuple[int, int]:
    passed = failed = 0

    def check(name: str, cond: bool, extra: str = "") -> None:
        nonlocal passed, failed
        if cond:
            passed += 1
            print(f"[PASS] {name} {extra}")
        else:
            failed += 1
            print(f"[FAIL] {name} {extra}")

    tmp = Path(tempfile.mkdtemp(prefix="sort-func-selftest-"))
    try:
        # ---- exif ----
        jpg = tmp / "cam.jpg"
        make_jpeg_with_exif(jpg)
        x = exif.read_exif(jpg)
        check("exif make", x.get("make") == "Cannon-X", str(x))
        check("exif model", x.get("model") == "PyLens 42", str(x))
        check("exif orientation", x.get("orientation") == 6, str(x))
        check("exif datetime", x.get("datetime", "").startswith("2026:11:24"),
              str(x))

        # ---- tags ----
        mp3 = tmp / "song.mp3"
        make_mp3_with_id3(mp3)
        t = tags.read_id3(mp3)
        check("id3v2 title", t.get("title") == "Test Song", str(t))
        check("id3v2 artist", t.get("artist") == "Test Artist", str(t))
        check("id3v2 album", t.get("album") == "Test Album", str(t))

        # ---- compression ----
        zf = tmp / "pack.zip"
        with zipfile.ZipFile(zf, "w") as z:
            z.writestr("a.txt", "hi")
            z.writestr("b.txt", "there")
        c = compression.sniff_archive(zf)
        check("zip entries", c.get("kind") == "zip" and c.get("entries") == 2,
              str(c))

        # ---- deps ----
        d = deps.report()
        check("deps python ok", d.get("python_ok") is True, str(d))

        # ---- editions gating ----
        bad_kw = editions.analyze_spec("exif-model")
        check("era gate v2x no exif",
              not (bad_kw[0] - editions.MI_EPOCHS[6]))
        e7 = editions.keywords_for("media-intelligent", 7)
        check("era v7 has exif keyword", "exif-model" in e7)

        # ---- engine + extended keywords end-to-end ----
        facts = editions._gather_with_extras(jpg, set())
        tpl = editions.EditionTemplate("exif-make/exif-orientation", "path")
        got = tpl.resolve(facts)
        check("edition template exif", got == "Cannon-X/6", got)

        # era runner: v1 must reject exif keyword, v7 accept it
        rc_bad = editions.run(["--dirs=exif-model", str(jpg)],
                              "media-intelligent", 3)
        check("era rejects foreign keyword", rc_bad == 64, str(rc_bad))
    finally:
        import shutil
        shutil.rmtree(tmp, ignore_errors=True)
    return passed, failed


def run_all() -> int:
    print("== engine self-test ==")
    rc = ENGINE.run_self_test()
    print("\n== functions package self-test ==")
    p, f = run_module_tests()
    print(f"\nModule checks: {p} passed, {f} failed")
    return rc or (2 if f else 0)


__all__ = ["run_all", "run_module_tests"]
