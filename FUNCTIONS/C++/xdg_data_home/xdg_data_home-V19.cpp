static std::string xdg_data_home() {
    const char* x = std::getenv("XDG_DATA_HOME");
    if (x && *x) return x;
    const char* home = std::getenv("HOME");
    return std::string(home ? home : ".") + "/.local/share";
}
