def _meta_facts(facts):
    """Attach exif / id3 dicts lazily (once per file)."""
    if getattr(facts, "_meta_done", False):
        return facts
    facts.exif = {}
    facts.id3 = {}
    try:
        if facts.mime_main == "image" and facts.mime_sub == "jpeg":
            facts.exif = read_exif(facts.path)
        if facts.mime_sub == "mpeg" or facts.path.suffix.lower() in (".mp3", ".mpga"):
            facts.id3 = read_id3(facts.path)
    except OSError:
        pass
    facts._meta_done = True
    return facts
