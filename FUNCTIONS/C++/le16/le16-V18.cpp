static std::string le16(unsigned v) { std::string s; s += (char)(v & 0xFF); s += (char)(v >> 8); return s; }
