def gather_facts(path: Path, want_hashes: set) -> FileFacts:
    main, sub = sniff_mime(path)
    st = path.stat()
    b = getattr(st, "st_birthtime", None) or st.st_mtime
    facts = FileFacts(
        path=path, mime_main=main, mime_sub=sub, size=st.st_size,
        created=datetime.datetime.fromtimestamp(b),
        modified=datetime.datetime.fromtimestamp(st.st_mtime),
        accessed=datetime.datetime.fromtimestamp(st.st_atime),
    )
    if main == "image" or sub in ("webm", "mp4", "avi", "quicktime", "matroska"):
        facts.dims = image_dimensions(path)
    for kw in want_hashes:
        if path.is_file() and path.stat().st_size:
            facts.hashes[kw] = hash_file(path, kw)
    return facts
