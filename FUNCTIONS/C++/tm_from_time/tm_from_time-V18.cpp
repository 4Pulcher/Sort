static std::tm tm_from_time(std::time_t t) {
    std::tm out{};
    localtime_r(&t, &out);
    return out;
}
