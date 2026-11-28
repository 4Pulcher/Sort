static std::string be32(unsigned v) {
    std::string s;
    s += (char)((v >> 24) & 0xFF); s += (char)((v >> 16) & 0xFF);
    s += (char)((v >> 8) & 0xFF);  s += (char)(v & 0xFF);
    return s;
}
