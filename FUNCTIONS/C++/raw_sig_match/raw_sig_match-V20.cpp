static bool raw_sig_match(const std::string& buf, size_t pos, const RawPat& p) {
    // buf is hex; sig nibbles are matched against buf starting at hex index pos
    if (buf.size() < pos + p.sig.size()) return false;
    for (size_t i = 0; i < p.sig.size(); ++i)
        if (p.sig[i] != '?' && buf[pos + i] != p.sig[i]) return false;
    return true;
}
