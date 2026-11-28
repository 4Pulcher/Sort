def _meta_keyword_value(self, facts, kw):
    _meta_facts(facts)
    if kw.startswith("exif-"):
        field = kw[5:]
        if field == "make":
            return str(facts.exif.get("make") or "")
        if field == "model":
            return str(facts.exif.get("model") or "")
        if field == "datetime":
            return str(facts.exif.get("datetime") or facts.exif.get("dt_original") or "")
        if field == "date":
            v = str(facts.exif.get("datetime") or facts.exif.get("dt_original") or "")
            return v[:10]
        if field == "orientation":
            o = facts.exif.get("orientation")
            return str(o) if o not in ("", None) else ""
        return ""
    if kw.startswith("id3-"):
        return str(facts.id3.get(kw[4:]) or "")
    if kw == "title":
        return (facts.id3.get("title") or facts.exif.get("model") or facts.stem or "")
    return _orig_keyword_value(self, facts, kw)
