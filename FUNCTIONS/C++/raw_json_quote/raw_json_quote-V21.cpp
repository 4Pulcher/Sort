static std::string raw_json_quote(const std::string& s) {
    std::string out = "\"";
    for (char c : s) {
        if (c == '"' || c == '\\') out += '\\';
        if ((unsigned char)c < 0x20) { char b[8]; std::snprintf(b, 8, "\\u%04x", (unsigned)c); out += b; }
        else out += c;
    }
    return out + "\"";
}
