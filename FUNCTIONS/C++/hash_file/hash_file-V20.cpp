static std::string hash_file(const fs::path& p, const std::string& algo_key) {
    std::ifstream f(p, std::ios::binary);
    if (!f) return "";
    Hasher h(algo_key);
    char buf[1 << 20];
    while (f.read(buf, sizeof buf) || f.gcount() > 0) {
        h.update(reinterpret_cast<const unsigned char*>(buf), f.gcount());
    }
    return h.hexdigest();
}
