def slugify(text: str) -> str:
    """Slug used for path segments (V17)."""
    text = unicodedata.normalize("NFKD", text)
    kept = "".join(ch if (ch.isalnum() or ch in "-_.") else "-" for ch in text)
    kept = re.sub(r"-+", "-", kept).strip("-")
    return kept
