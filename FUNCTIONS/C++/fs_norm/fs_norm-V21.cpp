static std::string fs_norm(const std::string& f) {
    std::string s = f;
    for (auto& c : s) c = (char)tolower((unsigned char)c);
    if (s == "ext2" || s == "ext3" || s == "ext4") s = "ext";
    if (s == "hfs+" || s == "hfsx" || s == "hfsplus") s = "hfs";
    return s;
}
