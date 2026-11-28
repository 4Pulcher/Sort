static void st_write(const fs::path& p, const std::string& bytes) {
    std::ofstream f(p, std::ios::binary);
    f.write(bytes.data(), (std::streamsize)bytes.size());
}
