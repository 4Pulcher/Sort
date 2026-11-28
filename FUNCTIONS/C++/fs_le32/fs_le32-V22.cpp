static unsigned long long fs_le32(const char* p) {
    return (unsigned char)p[0] | ((unsigned long long)(unsigned char)p[1] << 8) |
           ((unsigned long long)(unsigned char)p[2] << 16) |
           ((unsigned long long)(unsigned char)p[3] << 24);
}
