def _check_template(value, arg):
    for seg in value.split("/"):
        for cand in seg.split("|"):
            expr = cand.strip()
            if not expr:
                continue
            while True:
                low = expr.lower()
                hit = next((p for p in ("lower:", "upper:", "raw:")
                            if low.startswith(p) and p[:-1] in EDITION["modifiers"]), None)
                if hit:
                    expr = expr[len(hit):]
                    continue
                break
            if "fallbacks" not in EDITION:
                continue
            kw = expr.strip().lower()
            if kw in CANONICAL_KEYWORDS and kw not in EDITION["keywords"]:
                raise SystemExit(_era_error(
                    "keyword '%s' is not part of Sort-%s (argument %s)" % (kw, EDITION["version"], arg)))
