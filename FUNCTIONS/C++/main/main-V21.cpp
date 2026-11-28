int main(int argc, char** argv) {
    std::vector<std::string> args(argv + 1, argv + argc);
    try {
        return era_main(args);
    } catch (const std::exception& exc) {
        std::cerr << "Sort.cpp: " << exc.what() << "\n";
        return 70;
    }
}
