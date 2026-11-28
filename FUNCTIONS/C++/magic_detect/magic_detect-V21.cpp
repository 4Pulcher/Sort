static std::pair<std::string, std::string> magic_detect(const std::string& h) {
    // MPEG transport stream: 0x47 sync bytes at offsets 0, 188 and 376
    if (h.size() >= 754 && h.compare(0, 2, "47") == 0 &&
        h.compare(376, 2, "47") == 0 && h.compare(752, 2, "47") == 0)
        return {"MPEG-TS", "ts,m2ts,mts"};
    for (const auto& e : MAGIC_TABLE) {
        if (magic_match(h, e.off, e.sig)) return {e.name, e.exts};
    }
    return {"?", ""};
}
