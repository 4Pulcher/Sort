static std::string hex_to_bytes(const std::string& hx) {
    std::string out;
    for (size_t i = 0; i + 1 < hx.size(); i += 2)
        out += (char)strtol(hx.substr(i, 2).c_str(), nullptr, 16);
    return out;
}
