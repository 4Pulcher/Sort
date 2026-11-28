static std::string le24(unsigned v) {
    std::string s;
    s += (char)(v & 0xFF); s += (char)((v >> 8) & 0xFF); s += (char)((v >> 16) & 0xFF);
    return s;
}
