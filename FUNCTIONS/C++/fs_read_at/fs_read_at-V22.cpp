static size_t fs_read_at(std::ifstream& f, unsigned long long off,
                         void* buf, size_t n) {
    f.clear();
    f.seekg((std::streamoff)off);
    if (!f.good()) return 0;
    f.read((char*)buf, (std::streamsize)n);
    return f.gcount() > 0 ? (size_t)f.gcount() : 0;
}
