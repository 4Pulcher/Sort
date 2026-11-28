static unsigned syncsafe(const std::string& h, size_t at) {
    return (((unsigned)(unsigned char)h[at] & 0x7F) << 21) |
           (((unsigned)(unsigned char)h[at+1] & 0x7F) << 14) |
           (((unsigned)(unsigned char)h[at+2] & 0x7F) << 7) |
           ((unsigned)(unsigned char)h[at+3] & 0x7F);
}
