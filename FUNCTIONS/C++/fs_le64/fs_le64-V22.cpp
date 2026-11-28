static unsigned long long fs_le64(const char* p) {
    unsigned long long v = 0;
    for (int i = 0; i < 8; ++i)
        v |= (unsigned long long)(unsigned char)p[i] << (8 * i);
    return v;
}
