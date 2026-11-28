def run_self_test() -> int:
    t = tempfile.mkdtemp(prefix="sort-py-selftest-")
    root = Path(t)
    passed = failed = 0

    def check(name: str, cond: bool, extra: str = "") -> None:
        nonlocal passed, failed
        if cond:
            passed += 1
            print(f"[PASS] {name} {extra}")
        else:
            failed += 1
            print(f"[FAIL] {name} {extra}")

    # fixtures
    png = root / "a.png"
    png.write_bytes(b"\x89PNG\r\n\x1a\n" + b"\x00\x00\x00\rIHDR" +
                    struct.pack(">II", 640, 480) + b"\x08\x06\x00\x00\x00")
    gif = root / "b.gif"
    gif.write_bytes(b"GIF89a" + struct.pack("<HH", 320, 200))
    jpeg = root / "c.jpg"
    jpeg.write_bytes(b"\xff\xd8\xff\xe0" + b"\x00\x10JFIF\x00\x01\x02\x00\x00\x01\x00\x01\x00\x00" +
                     b"\xff\xc0\x00\x11\x08" + struct.pack(">HH", 600, 800) + b"\x03\x01\x22\x00")
    webp = root / "d.webp"
    webp.write_bytes(b"RIFF\x30\x00\x00\x00WEBPVP8X" + b"\x0a\x00\x00\x00" +
                     b"\x00\x00\x00\x00" + (1919).to_bytes(3, "little") +
                     (1079).to_bytes(3, "little"))
    pdf = root / "doc.pdf"
    pdf.write_bytes(b"%PDF-1.4\n%\xe2\xe3\xcf\xd3\n1 0 obj\n<<>>\nendobj\ntrailer<<>>\n%%EOF")
    zipp = root / "arc.zip"
    zipp.write_bytes(b"PK\x03\x04" + b"\x14\x00\x00\x00\x08\x00" + b"\x00" * 64)
    mp3 = root / "song.mp3"
    mp3.write_bytes(b"ID3\x04\x00\x00\x00\x00\x00\x00" + b"\xff\xfb\x90\x44" + b"\x00" * 256)
    jsn = root / "data.json"
    jsn.write_text('{"a": 1}\n')
    shellf = root / "run.sh"
    shellf.write_text("#!/bin/sh\necho hi\n")
    txtf = root / "note.txt"
    txtf.write_text("just text\n")

    # MIME checks
    for f, expect in [(png, ("image", "png")), (gif, ("image", "gif")),
                      (jpeg, ("image", "jpeg")), (webp, ("image", "webp")),
                      (pdf, ("document", "pdf")), (zipp, ("archive", "zip")),
                      (mp3, ("audio", "mpeg")), (jsn, ("text", "json")),
                      (shellf, ("text", "x-shellscript")),
                      (txtf, ("text", "plain"))]:
        got = sniff_mime(f)
        check(f"mime {f.name}", got == expect, f"got={got}")

    # dimensions
    check("png dims", image_dimensions(png) == (640, 480), str(image_dimensions(png)))
    check("gif dims", image_dimensions(gif) == (320, 200), str(image_dimensions(gif)))
    check("jpeg dims", image_dimensions(jpeg) == (800, 600), str(image_dimensions(jpeg)))
    check("webp dims", image_dimensions(webp) == (1920, 1080), str(image_dimensions(webp)))

    # hashes
    check("md5", len(hash_file(png, "md5sum")) == 32)
    check("sha256", len(hash_file(png, "sha256sum")) == 64)

    # template engine
    facts = gather_facts(png, {"sha256sum"})
    got = TemplateEngine("mime-main/year+month/size", "path").resolve(facts)
    check("template path", bool(re.match(r"^IMAGE/\d{4}-\d{2}/\d+[KMGT]?B$", got)), got)
    eng3 = TemplateEngine("missing|mime-main", "extension")
    check("fallback", eng3.segment(facts, "missing|mime-main") == "image",
          eng3.segment(facts, "missing|mime-main"))
    eng4 = TemplateEngine("raw:filename", "name")
    check("raw prefix", eng4.segment(facts, "raw:filename") == "a.png",
          eng4.segment(facts, "raw:filename"))
    eng5 = TemplateEngine("year+month+day/pixel-format", "path")
    check("pixel-format", eng5.resolve(facts).count("/") == 1, eng5.resolve(facts))

    # organizer smoke test (copy with threads)
    src_dir = root / "in"
    src_dir.mkdir()
    (src_dir / "x.png").write_bytes(png.read_bytes())
    (src_dir / "y.pdf").write_bytes(pdf.read_bytes())
    (src_dir / "z.pdf").write_bytes(mpv := pdf.read_bytes())
    target = root / "out"
    opts = Options(mode="copy", dirs="mime-main", type_filter="image", target=target,
                  inputs=[src_dir], recursive=True, jobs=2, quiet=True, replace="always")
    org = Organizer(opts)
    rc = org.run()
    check("copy run", rc == 0)
    check("copy result", (target / "IMAGE" / "x.png").exists())

    # undo smoke test
    logf = root / "actions.jsonl"
    logf.write_text(json.dumps({"action": "copied", "src": str(src_dir / "x.png"),
                                "dst": str(target / "IMAGE" / "x.png")}) + "\n")
    before = (target / "IMAGE" / "x.png").exists()
    undo_log(logf)
    check("undo copy", before and not (target / "IMAGE" / "x.png").exists())

    print(f"\nPassed: {passed}  Failed: {failed}")
    shutil.rmtree(root, ignore_errors=True)
    return 2 if failed else 0
