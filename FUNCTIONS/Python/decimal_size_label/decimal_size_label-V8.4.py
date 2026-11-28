def decimal_size_label(num_bytes: int, unit: str = "size") -> str:
    """V2.2 style size tokens: e.g. '15-Mega' (format) / '15MB' (size)."""
    n = int(num_bytes or 0)
    divs = {"Tera": 1000**4, "Giga": 1000**3, "Mega": 1000**2,
            "Kilo": 1000, "Byte": 1}
    sizes = {"TB": 1000**4, "GB": 1000**3, "MB": 1000**2, "KB": 1000, "B": 1}
    if unit.startswith("format"):
        for name, div in divs.items():
            q = n // div
            if q > 0:
                return f"{q}-{name}"
        return "0-Byte"
    for name, div in sizes.items():
        q = n // div
        if q >= 1:
            return f"{q}{name}"
    return "0B"
