static std::string raw_hex(const std::string& bytes) {
    static const char* hexd = "0123456789abcdef";
    std::string out;
    out.reserve(bytes.size() * 2);
    for (unsigned char c : bytes) { out += hexd[c >> 4]; out += hexd[c & 15]; }
    return out;
}
