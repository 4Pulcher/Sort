static std::string resolution_format_label(int w, int h) {
    if (w <= 0 || h <= 0) return "ZERO";
    unsigned edge = (unsigned)std::max(w, h);
    for (const auto& t : RESOLUTION_TIERS)
        if (edge <= t.first) {
            std::string orient = (w == h) ? "SQUARE" : (w > h ? "WIDE" : "HIGH");
            return std::string(t.second) + "-" + orient;
        }
    return "HUGE-?";     // unreachable
}
