static std::string raw_first_ext(const std::string& exts) {
    if (exts.empty()) return "bin";
    size_t c = exts.find(',');
    return c == std::string::npos ? exts : exts.substr(0, c);
}
