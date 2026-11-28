def resolution_format_label(w: int, h: int) -> str:
    """V2.2 style resolution labels: tier + orientation."""
    if w <= 0 or h <= 0:
        return "ZERO"
    edge = max(w, h)
    tier = next(name for lim, name in RESOLUTION_TIERS if edge <= lim)
    orientation = "SQUARE" if w == h else ("WIDE" if w > h else "HIGH")
    return f"{tier}-{orientation}"
