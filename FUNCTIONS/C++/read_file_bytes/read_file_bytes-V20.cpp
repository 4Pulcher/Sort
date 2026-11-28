static std::string read_file_bytes(const fs::path& p, size_t limit) {
    std::ifstream f(p, std::ios::binary);
    if (!f) return "";
    std::string out(limit, '\0');
    f.read(out.data(), limit);
    out.resize(f.gcount());
    return out;
}
