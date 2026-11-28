static std::string decode_id3_text(int enc, std::string raw) {
    if (enc == 0 || enc == 3) {
        size_t z = raw.find('\0');
        if (z != std::string::npos) raw = raw.substr(0, z);
    }
    return raw;   // the practical subset: treat as latin-1/utf-8 passthrough
}
