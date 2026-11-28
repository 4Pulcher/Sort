static bool starts_with(const std::string& h, size_t at, const char* pre, size_t n) {
    return h.size() >= at + n && h.compare(at, n, pre, n) == 0;
}
