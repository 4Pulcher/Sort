static std::string be16(unsigned v) { std::string s; s += (char)(v >> 8); s += (char)(v & 0xFF); return s; }
