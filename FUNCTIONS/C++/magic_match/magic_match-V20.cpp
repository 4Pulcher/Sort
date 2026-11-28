static bool magic_match(const std::string& h, int off, const char* sig) {
    size_t pos = (size_t)off * 2;
    size_t n = std::strlen(sig);
    if (h.size() < pos + n) return false;
    for (size_t i = 0; i < n; ++i)
        if (sig[i] != '?' && h[pos + i] != sig[i]) return false;
    return true;
}
