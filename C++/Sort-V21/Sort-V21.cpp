// ===========================================================================
// Sort.cpp - Media-Intelligent File Organizer (C++17 edition)
// ===========================================================================
// A pure C++17 (standard library only) port of the complete Sort.sh
// lineage (V1.0 -> V21), matching the feature union of the family:
//
//   * no `file`, no ImageMagick, no FFmpeg, no ExifTool, no OpenSSL:
//     MIME sniffing, media dimensions, hashing (MD5 + SHA-1/2 family),
//     EXIF and ID3 parsing and text detection are all native.
//   * modes: dummy (default dry run), copy, move, remove, trash, shred
//   * V17 template language: lower:/upper:/raw: prefixes, a|b|c fallbacks,
//     slugified names, keyword union of the whole lineage
//   * V17.5 --magic: 237-signature detection report (identical output
//     to the Bash/Pascal/Python editions)
//   * V15 undo log (JSONL), V14 freedesktop trash + shred, V12 --jobs
//
// Build:  g++ -std=c++17 -O2 -pthread -o Sort Sort.cpp
// (also compiles with clang++ -std=c++17; needs nothing but libstdc++
// and a POSIX userland for fsync/trash paths - i.e. any Linux/macOS)
//
// Safety: like the whole lineage, with no --mode the tool performs a
// DRY RUN and only prints intended destinations.
// ===========================================================================

#include <algorithm>
#include <array>
#include <cctype>
#include <chrono>
#include <condition_variable>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <map>
#include <mutex>
#include <optional>
#include <queue>
#include <random>
#include <regex>
#include <set>
#include <sstream>
#include <string>
#include <string_view>
#include <thread>
#include <functional>
#include <unordered_map>
#include <vector>

#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

namespace fs = std::filesystem;

static const char* CPP_VERSION = "cpp-21";
static const char* LINEAGE_NOTE =
    "C++17 port of the Sort.sh V1.0-V21 lineage (std library only)";

// ===========================================================================
// 1. UI: COLORS, ICONS, INTERNATIONALIZATION
// ===========================================================================

static const std::map<std::string, std::string> ICONS = {
    {"info", "\u2139\ufe0f"}, {"ok", "\u2705"}, {"warn", "\u26a0\ufe0f"},
    {"error", "\u274c"}, {"skip", "\u23ed\ufe0f"}, {"dir", "\U0001f4c1"},
    {"file", "\U0001f4c4"}, {"link", "\U0001f517"}, {"copy", "\U0001f4cb"},
    {"move", "\U0001f69a"}, {"remove", "\U0001f5d1\ufe0f"}, {"mime", "\U0001f3f7"},
    {"target", "\U0001f3af"}, {"name", "\U0001f4dd"}, {"hash", "\U0001f511"},
    {"clean", "\U0001f9f9"}, {"done", "\U0001f3c1"}, {"test", "\U0001f9ea"},
};

struct LangStrings {
    const char* start; const char* dry; const char* target; const char* mode;
    const char* files; const char* copied; const char* moved; const char* removed;
    const char* trashed; const char* shredded; const char* skipped;
    const char* failed; const char* empty; const char* done; const char* notfound;
    const char* filtered; const char* confirm; const char* noinput;
};
static const std::map<std::string, LangStrings> TRANSLATIONS = {
    {"en", {"Starting action:", "DRY RUN - no changes made",
            "Target", "Mode", "files processed",
            "copied", "moved", "removed", "trashed", "shredded", "skipped",
            "failed", "empty directory removed: ", "Complete", "Path not found: ",
            "filtered by type: ",
            "Action: [C]ancel, [S]kip, Skip [A]ll, [R]eplace, Replace a[L]l: ",
            "No input files or directories provided."}},
    {"nl", {"Actie gestart:", "TESTMODUS - geen wijzigingen doorgevoerd",
            "Doel", "Modus", "bestanden verwerkt",
            "gekopieerd", "verplaatst", "verwijderd", "naar prullenbak",
            "vernietigd", "overgeslagen", "mislukt", "lege map verwijderd: ",
            "Klaar", "Pad niet gevonden: ", "gefilterd op type: ",
            "Actie: [A]nnuleren, [O]verslaan, Overslaan a[L]le, [V]ervangen, Vervangen a[L]le: ",
            "Geen invoerbestanden of mappen opgegeven."}},
    {"fr", {"Action commenc\303\251e :", "SIMULATION - aucun changement effectu\303\251",
            "Cible", "Mode", "fichiers trait\303\251s",
            "copi\303\251s", "d\303\251plac\303\251s", "supprim\303\251s",
            "\303\240 la corbeille", "d\303\251truits", "ignor\303\251s",
            "\303\251chou\303\251s", "r\303\251pertoire vide supprim\303\251 : ",
            "Termin\303\251", "Chemin introuvable : ", "filtr\303\251 par type : ",
            "Action : [A]nnuler, [I]gnorer, Ignorer [T]out, [R]emplacer, Remplacer [T]out : ",
            "Aucun fichier ou r\303\251pertoire fourni."}},
    {"de", {"Aktion gestartet:", "TESTLAUF - keine \303\204nderungen durchgef\303\274hrt",
            "Ziel", "Modus", "Dateien verarbeitet",
            "kopiert", "verschoben", "gel\303\266scht", "in den Papierkorb",
            "vernichtet", "\303\274bersprungen", "fehlgeschlagen",
            "leeres Verzeichnis entfernt: ", "Fertig", "Pfad nicht gefunden: ",
            "nach Typ gefiltert: ",
            "Aktion: [A]bbrechen, [C\303\234]berspringen, [C\303\234]berspringen a[L]le, [E]rsetzen, Ersetzen a[L]le: ",
            "Keine Eingabedateien oder -verzeichnisse angegeben."}},
    {"tr", {"Eylem ba\305\237lad\304\261:", "KURU \303\207ALI\305\236MA - de\304\237i\305\237iklik yap\304\261lmad\304\261",
            "Hedef", "Mod", "dosya i\305\237lendi",
            "kopyaland\304\261", "ta\305\237\304\261nd\304\261", "silindi",
            "\303\247\303\266pe at\304\261ld\304\261", "imha edildi", "atland\304\261",
            "ba\305\237ar\304\261s\304\261z", "bo\305\237 klas\303\266r kald\304\261r\304\261ld\304\261: ",
            "Tamamland\304\261", "Yol bulunamad\304\261: ", "t\303\274re g\303\266re filtrelendi: ",
            "Eylem: [\304\260]ptal, [A]tla, Atla [H]epsi, [D]e\304\237i\305\237tir, De\304\237i\305\237tir [H]epsi: ",
            "Girdi dosyas\304\261 veya dizin verilmedi."}},
};

class UI {
public:
    explicit UI(bool colors = true, bool icons = true,
                const std::string& lang = "en", bool quiet = false)
        : icons_(icons), quiet_(quiet) {
        on_ = colors && isatty(STDOUT_FILENO);
        auto it = TRANSLATIONS.find(lang);
        t_ = (it != TRANSLATIONS.end()) ? &it->second : &TRANSLATIONS.at("en");
    }
    bool quiet() const { return quiet_; }
    std::string T(const std::string& key) const {
        if (key == "start") return t_->start;
        if (key == "dry") return t_->dry;
        if (key == "target") return t_->target;
        if (key == "mode") return t_->mode;
        if (key == "files") return t_->files;
        if (key == "copied") return t_->copied;
        if (key == "moved") return t_->moved;
        if (key == "removed") return t_->removed;
        if (key == "trashed") return t_->trashed;
        if (key == "shredded") return t_->shredded;
        if (key == "skipped") return t_->skipped;
        if (key == "failed") return t_->failed;
        if (key == "empty") return t_->empty;
        if (key == "done") return t_->done;
        if (key == "notfound") return t_->notfound;
        if (key == "filtered") return t_->filtered;
        if (key == "confirm") return t_->confirm;
        if (key == "noinput") return t_->noinput;
        return key;
    }
    std::string icon(const std::string& key) const {
        if (!icons_) return "";
        auto it = ICONS.find(key);
        return (it != ICONS.end()) ? it->second + " " : "";
    }
    std::string c(const char* code, const std::string& s) const {
        return on_ ? "\033[" + std::string(code) + "m" + s + "\033[0m" : s;
    }
    std::string bold(const std::string& s)   { return c("1", s); }
    std::string info(const std::string& s)  { return c("36", s); }
    std::string ok(const std::string& s)     { return c("32", s); }
    std::string warn(const std::string& s)  { return c("33", s); }
    std::string err(const std::string& s)   { return c("31", s); }
    std::string label(const std::string& s) { return c("94", s); }
    std::string dim(const std::string& s)   { return c("2", s); }
    std::string path(const std::string& s)  { return c("37", s); }
    void say(const std::string& msg) { if (!quiet_) std::cout << msg << "\n"; }
private:
    bool on_ = false, icons_ = true, quiet_ = false;
    const LangStrings* t_;
};

// ===========================================================================
// 2. HASHING (V5.x heritage: checksum keywords) - native, no OpenSSL
// ===========================================================================

class Hasher {
public:
    explicit Hasher(const std::string& algo) {
        std::string a = algo;
        // strip a trailing "sum" like the Python edition
        if (a.size() > 3 && a.compare(a.size() - 3, 3, "sum") == 0) a = a.substr(0, a.size() - 3);
        if (a.empty()) a = "md5";
        algo_ = a;
        init();
    }
    void update(const unsigned char* p, size_t n) {
        total_ += n;
        for (size_t i = 0; i < n; ++i) absorb(p[i]);
    }
    void update(const std::string& s) {
        update(reinterpret_cast<const unsigned char*>(s.data()), s.size());
    }
    std::string hexdigest() {
        if (!finalized_) { finalize(); finalized_ = true; }
        std::string out;
        out.reserve(digest_.size() * 2);
        static const char* hd = "0123456789abcdef";
        for (unsigned char b : digest_) { out += hd[b >> 4]; out += hd[b & 15]; }
        return out;
    }
private:
    std::string algo_;
    unsigned long long total_ = 0;
    unsigned char buf_[128]{};
    size_t buflen_ = 0;
    std::vector<unsigned long long> state_;
    std::vector<unsigned char> digest_;
    bool finalized_ = false;
    bool wide_ = false;   // SHA-384/512 use 64-bit words and 128-byte blocks

    void init() {
        if (algo_ == "md5") {
            state_ = {0x67452301ull, 0xefcdab89ull, 0x98badcfeull, 0x10325476ull};
            digest_.assign(16, 0);
        } else if (algo_ == "sha1") {
            state_ = {0x67452301ull, 0xefcdab89ull, 0x98badcfeull,
                      0x10325476ull, 0xc3d2e1f0ull};
            digest_.assign(20, 0);
        } else if (algo_ == "sha224") {
            state_ = {0xc1059ed8ull, 0x367cd507ull, 0x3070dd17ull, 0xf70e5939ull,
                      0xffc00b31ull, 0x68581511ull, 0x64f98fa7ull, 0xbefa4fa4ull};
            digest_.assign(28, 0);
        } else if (algo_ == "sha256") {
            state_ = {0x6a09e667ull, 0xbb67ae85ull, 0x3c6ef372ull, 0xa54ff53aull,
                      0x510e527full, 0x9b05688cull, 0x1f83d9abull, 0x5be0cd19ull};
            digest_.assign(32, 0);
        } else if (algo_ == "sha384") {
            wide_ = true;
            state_ = {0xcbbb9d5dc1059ed8ull, 0x629a292a367cd507ull,
                      0x9159015a3070dd17ull, 0x152fecd8f70e5939ull,
                      0x67332667ffc00b31ull, 0x8eb44a8768581511ull,
                      0xdb0c2e0d64f98fa7ull, 0x47b5481dbefa4fa4ull};
            digest_.assign(48, 0);
        } else if (algo_ == "sha512") {
            wide_ = true;
            state_ = {0x6a09e667f3bcc908ull, 0xbb67ae8584caa73bull,
                      0x3c6ef372fe94f82bull, 0xa54ff53a5f1d36f1ull,
                      0x510e527fade682d1ull, 0x9b05688c2b3e6c1full,
                      0x1f83d9abfb41bd6bull, 0x5be0cd19137e2179ull};
            digest_.assign(64, 0);
        } else {
            algo_ = "md5";
            init();
        }
    }
    static unsigned long long rotr(unsigned long long x, int n) {
        return (x >> n) | (x << (64 - n));
    }
    static unsigned int rotr32(unsigned int x, int n) {
        return ((unsigned int)(x >> n)) | (x << (32 - n));
    }
    static unsigned int rotl32(unsigned int x, int n) {
        return ((unsigned int)(x << n)) | (x >> (32 - n));
    }
    void absorb(unsigned char b) {
        buf_[buflen_++] = b;
        if (buflen_ == (wide_ ? 128 : 64)) { process(buf_); buflen_ = 0; }
    }
    void process(const unsigned char* blk) {
        if (algo_ == "md5") { md5_block(blk); return; }
        if (algo_ == "sha1") { sha1_block(blk); return; }
        if (wide_) { sha512_block(blk); return; }
        sha256_block(blk);
    }
    void md5_block(const unsigned char* p) {
        static const unsigned int K[64] = {
            0xd76aa478,0xe8c7b756,0x242070db,0xc1bdceee,0xf57c0faf,0x4787c62a,
            0xa8304613,0xfd469501,0x698098d8,0x8b44f7af,0xffff5bb1,0x895cd7be,
            0x6b901122,0xfd987193,0xa679438e,0x49b40821,0xf61e2562,0xc040b340,
            0x265e5a51,0xe9b6c7aa,0xd62f105d,0x02441453,0xd8a1e681,0xe7d3fbc8,
            0x21e1cde6,0xc33707d6,0xf4d50d87,0x455a14ed,0xa9e3e905,0xfcefa3f8,
            0x676f02d9,0x8d2a4c8a,0xfffa3942,0x8771f681,0x6d9d6122,0xfde5380c,
            0xa4beea44,0x4bdecfa9,0xf6bb4b60,0xbebfbc70,0x289b7ec6,0xeaa127fa,
            0xd4ef3085,0x04881d05,0xd9d4d039,0xe6db99e5,0x1fa27cf8,0xc4ac5665,
            0xf4292244,0x432aff97,0xab9423a7,0xfc93a039,0x655b59c3,0x8f0ccc92,
            0xffeff47d,0x85845dd1,0x6fa87e4f,0xfe2ce6e0,0xa3014314,0x4e0811a1,
            0xf7537e82,0xbd3af235,0x2ad7d2bb,0xeb86d391};
        unsigned int w[16];
        for (int i = 0; i < 16; ++i)
            w[i] = ((unsigned int)p[i*4]) | ((unsigned int)p[i*4+1] << 8) |
                   ((unsigned int)p[i*4+2] << 16) | ((unsigned int)p[i*4+3] << 24);
        unsigned int a = (unsigned int)state_[0], b = (unsigned int)state_[1],
                     c = (unsigned int)state_[2], d = (unsigned int)state_[3];
        for (int i = 0; i < 64; ++i) {
            unsigned int f;
            int g;
            if (i < 16)      { f = (b & c) | (~b & d);            g = i; }
            else if (i < 32) { f = (d & b) | (~d & c);            g = (5*i + 1) % 16; }
            else if (i < 48) { f = b ^ c ^ d;                     g = (3*i + 5) % 16; }
            else             { f = c ^ (b | ~d);                  g = (7*i) % 16; }
            static const int S[64] = {
                7,12,17,22, 7,12,17,22, 7,12,17,22, 7,12,17,22,
                5, 9,14,20, 5, 9,14,20, 5, 9,14,20, 5, 9,14,20,
                4,11,16,23, 4,11,16,23, 4,11,16,23, 4,11,16,23,
                6,10,15,21, 6,10,15,21, 6,10,15,21, 6,10,15,21};
            unsigned int tmp = d;
            d = c; c = b;
            unsigned int x = a + f + K[i] + w[g];
            b = b + ((x << S[i]) | (x >> (32 - S[i])));
            a = tmp;
        }
        state_[0] += a; state_[1] += b; state_[2] += c; state_[3] += d;
    }
    void sha1_block(const unsigned char* p) {
        unsigned int w[80];
        for (int i = 0; i < 16; ++i)
            w[i] = ((unsigned int)p[i*4] << 24) | ((unsigned int)p[i*4+1] << 16) |
                   ((unsigned int)p[i*4+2] << 8) | ((unsigned int)p[i*4+3]);
        for (int i = 16; i < 80; ++i)
            w[i] = rotl32(w[i-3] ^ w[i-8] ^ w[i-14] ^ w[i-16], 1);
        unsigned int a = (unsigned int)state_[0], b = (unsigned int)state_[1],
                     c = (unsigned int)state_[2], d = (unsigned int)state_[3],
                     e = (unsigned int)state_[4];
        for (int i = 0; i < 80; ++i) {
            unsigned int f;
            unsigned int k;
            if (i < 20)      { f = (b & c) | (~b & d); k = 0x5a827999; }
            else if (i < 40) { f = b ^ c ^ d;          k = 0x6ed9eba1; }
            else if (i < 60) { f = (b & c) | (b & d) | (c & d); k = 0x8f1bbcdc; }
            else             { f = b ^ c ^ d;          k = 0xca62c1d6; }
            unsigned int tmp = rotl32(a, 5) + f + e + k + w[i];
            e = d; d = c; c = rotl32(b, 30); b = a; a = tmp;
        }
        state_[0] += a; state_[1] += b; state_[2] += c; state_[3] += d; state_[4] += e;
    }
    void sha256_block(const unsigned char* p) {
        static const unsigned int K[64] = {
            0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,
            0x923f82a4,0xab1c5ed5,0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,
            0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,0xe49b69c1,0xefbe4786,
            0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
            0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,
            0x06ca6351,0x14292967,0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,
            0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,0xa2bfe8a1,0xa81a664b,
            0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
            0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,
            0x5b9cca4f,0x682e6ff3,0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,
            0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2};
        unsigned int w[64];
        for (int i = 0; i < 16; ++i)
            w[i] = ((unsigned int)p[i*4] << 24) | ((unsigned int)p[i*4+1] << 16) |
                   ((unsigned int)p[i*4+2] << 8) | ((unsigned int)p[i*4+3]);
        for (int i = 16; i < 64; ++i) {
            unsigned int s0 = rotr32(w[i-15],7) ^ rotr32(w[i-15],18) ^ (w[i-15] >> 3);
            unsigned int s1 = rotr32(w[i-2],17) ^ rotr32(w[i-2],19) ^ (w[i-2] >> 10);
            w[i] = w[i-16] + s0 + w[i-7] + s1;
        }
        unsigned int a = (unsigned int)state_[0], b = (unsigned int)state_[1],
                     c = (unsigned int)state_[2], d = (unsigned int)state_[3],
                     e = (unsigned int)state_[4], f = (unsigned int)state_[5],
                     g = (unsigned int)state_[6], h = (unsigned int)state_[7];
        for (int i = 0; i < 64; ++i) {
            unsigned int S1 = rotr32(e,6) ^ rotr32(e,11) ^ rotr32(e,25);
            unsigned int ch = (e & f) ^ (~e & g);
            unsigned int t1 = h + S1 + ch + K[i] + w[i];
            unsigned int S0 = rotr32(a,2) ^ rotr32(a,13) ^ rotr32(a,22);
            unsigned int mj = (a & b) ^ (a & c) ^ (b & c);
            unsigned int t2 = S0 + mj;
            h = g; g = f; f = e; e = d + t1;
            d = c; c = b; b = a; a = t1 + t2;
        }
        state_[0] += a; state_[1] += b; state_[2] += c; state_[3] += d;
        state_[4] += e; state_[5] += f; state_[6] += g; state_[7] += h;
    }
    void sha512_block(const unsigned char* p) {
        static const unsigned long long K[80] = {
            0x428a2f98d728ae22ull,0x7137449123ef65cdull,0xb5c0fbcfec4d3b2full,
            0xe9b5dba58189dbbcull,0x3956c25bf348b538ull,0x59f111f1b605d019ull,
            0x923f82a4af194f9bull,0xab1c5ed5da6d8118ull,0xd807aa98a3030242ull,
            0x12835b0145706fbeull,0x243185be4ee4b28cull,0x550c7dc3d5ffb4e2ull,
            0x72be5d74f27b896full,0x80deb1fe3b1696b1ull,0x9bdc06a725c71235ull,
            0xc19bf174cf692694ull,0xe49b69c19ef14ad2ull,0xefbe4786384f25e3ull,
            0x0fc19dc68b8cd5b5ull,0x240ca1cc77ac9c65ull,0x2de92c6f592b0275ull,
            0x4a7484aa6ea6e483ull,0x5cb0a9dcbd41fbd4ull,0x76f988da831153b5ull,
            0x983e5152ee66dfabull,0xa831c66d2db43210ull,0xb00327c898fb213full,
            0xbf597fc7beef0ee4ull,0xc6e00bf33da88fc2ull,0xd5a79147930aa725ull,
            0x06ca6351e003826full,0x142929670a0e6e70ull,0x27b70a8546d22ffcull,
            0x2e1b21385c26c926ull,0x4d2c6dfc5ac42aedull,0x53380d139d95b3dfull,
            0x650a73548baf63deull,0x766a0abb3c77b2a8ull,0x81c2c92e47edaee6ull,
            0x92722c851482353bull,0xa2bfe8a14cf10364ull,0xa81a664bbc423001ull,
            0xc24b8b70d0f89791ull,0xc76c51a30654be30ull,0xd192e819d6ef5218ull,
            0xd69906245565a910ull,0xf40e35855771202aull,0x106aa07032bbd1b8ull,
            0x19a4c116b8d2d0c8ull,0x1e376c085141ab53ull,0x2748774cdf8eeb99ull,
            0x34b0bcb5e19b48a8ull,0x391c0cb3c5c95a63ull,0x4ed8aa4ae3418acbull,
            0x5b9cca4f7763e373ull,0x682e6ff3d6b2b8a3ull,0x748f82ee5defb2fcull,
            0x78a5636f43172f60ull,0x84c87814a1f0ab72ull,0x8cc702081a6439ecull,
            0x90befffa23631e28ull,0xa4506cebde82bde9ull,0xbef9a3f7b2c67915ull,
            0xc67178f2e372532bull,0xca273eceea26619cull,0xd186b8c721c0c207ull,
            0xeada7dd6cde0eb1eull,0xf57d4f7fee6ed178ull,0x06f067aa72176fbaull,
            0x0a637dc5a2c898a6ull,0x113f9804bef90daeull,0x1b710b35131c471bull,
            0x28db77f523047d84ull,0x32caab7b40c72493ull,0x3c9ebe0a15c9bebcull,
            0x431d67c49c100d4cull,0x4cc5d4becb3e42b6ull,0x597f299cfc657e2aull,
            0x5fcb6fab3ad6faecull,0x6c44198c4a475817ull};
        unsigned long long w[80];
        for (int i = 0; i < 16; ++i) {
            w[i] = 0;
            for (int j = 0; j < 8; ++j)
                w[i] = (w[i] << 8) | p[i*8+j];
        }
        for (int i = 16; i < 80; ++i) {
            unsigned long long s0 = rotr(w[i-15],1) ^ rotr(w[i-15],8) ^ (w[i-15] >> 7);
            unsigned long long s1 = rotr(w[i-2],19) ^ rotr(w[i-2],61) ^ (w[i-2] >> 6);
            w[i] = w[i-16] + s0 + w[i-7] + s1;
        }
        unsigned long long a = state_[0], b = state_[1], c = state_[2],
                            d = state_[3], e = state_[4], f = state_[5],
                            g = state_[6], h = state_[7];
        for (int i = 0; i < 80; ++i) {
            unsigned long long S1 = rotr(e,14) ^ rotr(e,18) ^ rotr(e,41);
            unsigned long long ch = (e & f) ^ (~e & g);
            unsigned long long t1 = h + S1 + ch + K[i] + w[i];
            unsigned long long S0 = rotr(a,28) ^ rotr(a,34) ^ rotr(a,39);
            unsigned long long mj = (a & b) ^ (a & c) ^ (b & c);
            unsigned long long t2 = S0 + mj;
            h = g; g = f; f = e; e = d + t1;
            d = c; c = b; b = a; a = t1 + t2;
        }
        state_[0] += a; state_[1] += b; state_[2] += c; state_[3] += d;
        state_[4] += e; state_[5] += f; state_[6] += g; state_[7] += h;
    }
    void finalize() {
        size_t block = wide_ ? 128 : 64;
        unsigned long long bits = total_ * 8;
        absorb(0x80);
        while (buflen_ != block - (wide_ ? 16 : 8)) absorb(0x00);
        // length field is big-endian; feed byte by byte
        int lenbytes = wide_ ? 16 : 8;
        unsigned long long v = bits;
        unsigned char lb[16];
        for (int i = lenbytes - 1; i >= 0; --i) { lb[i] = (unsigned char)(v & 0xff); v >>= 8; }
        if (algo_ == "md5") {          // MD5 stores the length little-endian
            for (int i = 0; i < lenbytes / 2; ++i)
                std::swap(lb[i], lb[lenbytes - 1 - i]);
        }
        for (int i = 0; i < lenbytes; ++i) absorb(lb[i]);
        size_t out = digest_.size();
        for (size_t i = 0; i < out; ++i) {
            size_t word = i / (wide_ ? 8 : 4);
            int shift = (wide_ ? 8 : 4) - 1 - (i % (wide_ ? 8 : 4));
            int sh = shift * 8;
            unsigned long long sw = state_[word];
            digest_[i] = (unsigned char)((sw >> sh) & 0xff);
        }
    }
};

// ===========================================================================
// 3. MIME SNIFFING (native magic-byte engine - Pascal FindMime heritage)
// ===========================================================================

struct Sig { int off; const char* magic; size_t len; const char* main; const char* sub; };
#define SIG(o, m, ma, su) {o, m, sizeof(m)-1, ma, su}
static const std::vector<Sig> BINARY_SIGNATURES = {
    SIG(0, "\x89PNG\r\n\x1a\n", "image", "png"),
    SIG(0, "\xff\xd8\xff", "image", "jpeg"),
    SIG(0, "GIF87a", "image", "gif"),
    SIG(0, "GIF89a", "image", "gif"),
    SIG(0, "BM", "image", "bmp"),
    SIG(0, "II*\x00", "image", "tiff"),
    SIG(0, "MM\x00*", "image", "tiff"),
    SIG(0, "\x1f\x8b", "archive", "gzip"),
    SIG(0, "BZh", "archive", "bzip2"),
    SIG(0, "\xfd" "7zXZ\x00", "archive", "xz"),
    SIG(0, "7z\xbc\xaf\x27\x1c", "archive", "7z"),
    SIG(0, "Rar!\x1a\x07", "archive", "rar"),
    SIG(0, "%PDF", "document", "pdf"),
    SIG(0, "{\\rtf", "document", "rtf"),
    SIG(0, "\x7f" "ELF", "binary", "elf"),
    SIG(0, "MZ", "binary", "exe"),
    SIG(0, "\xca\xfe\xba\xbe", "binary", "java-class"),
    SIG(0, "FLV\x01", "video", "flv"),
    SIG(4, "ftypisom", "video", "mp4"),
    SIG(4, "ftypmp4", "video", "mp4"),
    SIG(4, "ftypavc1", "video", "mp4"),
    SIG(4, "ftypisd ", "video", "mp4"),
    SIG(4, "ftypM4A ", "audio", "mp4a"),
    SIG(4, "ftypqt  ", "video", "quicktime"),
    SIG(0, ".snd", "audio", "au"),
    SIG(0, "ID3", "audio", "mpeg"),
    SIG(0, "\xff\xfb", "audio", "mpeg"),
    SIG(0, "\xff\xf3", "audio", "mpeg"),
    SIG(0, "\xff\xf2", "audio", "mpeg"),
    SIG(0, "OggS", "audio", "ogg"),
    SIG(0, "fLaC", "audio", "flac"),
    SIG(0, "RIFF", "audio", "wav"),
    SIG(0, "PK\x03\x04", "archive", "zip"),
    SIG(0, "PK\x05\x06", "archive", "zip"),
    SIG(0, "PK\x07\x08", "archive", "zip"),
};
#undef SIG

static bool starts_with(const std::string& h, size_t at, const char* pre, size_t n) {
    return h.size() >= at + n && h.compare(at, n, pre, n) == 0;
}

static std::pair<std::string, std::string> sniff_mime(const fs::path& path,
                                                     const std::string* head_in = nullptr) {
    std::string head;
    if (head_in) {
        head = *head_in;
    } else {
        std::ifstream f(path, std::ios::binary);
        if (!f) return {"unknown", "unknown"};
        head.resize(512);
        f.read(head.data(), 512);
        head.resize(f.gcount());
    }
    if (head.empty()) return {"empty", "empty"};

    const Sig* hit = nullptr;
    for (const auto& s : BINARY_SIGNATURES) {
        if (starts_with(head, s.off, s.magic, s.len)) { hit = &s; break; }
    }
    if (hit) {
        if (starts_with(head, 0, "RIFF", 4)) {
            if (starts_with(head, 8, "WAVE", 4)) return {"audio", "wav"};
            if (starts_with(head, 8, "AVI ", 4)) return {"video", "avi"};
            if (starts_with(head, 8, "WEBP", 4)) return {"image", "webp"};
            return {hit->main, hit->sub};
        }
        if (starts_with(head, 0, "\x1a" "E\xdf\xa3", 4)) {
            if (head.find("webm") != std::string::npos &&
                head.find("webm") < 64) return {"video", "webm"};
            return {"video", "matroska"};
        }
        if (starts_with(head, 0, "PK\x03\x04", 4)) return {"archive", "zip"};
        return {hit->main, hit->sub};
    }

    // binary oracle failed: text heuristics (Pascal SniffTextMime heritage)
    bool printable = true;
    for (size_t i = 0; i < head.size() && i < 256; ++i) {
        unsigned char b = head[i];
        if (!(b >= 32 && b < 127) && b != 9 && b != 10 && b != 13) { printable = false; break; }
    }
    char first = head.empty() ? 0 : head[0];
    bool lead = (first == '\n' || first == '\r' || first == ' ' || first == '\t');
    if (printable || lead) {
        std::string sample = head.substr(0, 512);
        auto has = [&](const std::string& needle) { return sample.find(needle) != std::string::npos; };
        auto lower = sample;
        for (auto& ch : lower) ch = (char)std::tolower((unsigned char)ch);
        size_t ws = 0;
        while (ws < sample.size() && std::isspace((unsigned char)sample[ws])) ++ws;
        if (ws < sample.size() && sample[ws] == '{') return {"text", "json"};
        if (has("<?xml")) return {"text", "xml"};
        if (lower.find("<!doctype html") != std::string::npos ||
            lower.find("<html") != std::string::npos) return {"text", "html"};
        if (sample.compare(0, 3, "---") == 0 &&
            sample.find("\n---", 3) != std::string::npos) return {"text", "yaml"};
        if (has("#!/bin/sh") || has("#!/bin/bash") || has("#!/usr/bin/env sh") ||
            has("#!/usr/bin/env bash") || has("#!/bin/dash")) return {"text", "x-shellscript"};
        if (sample.compare(0, 2, "#!") == 0 && lower.find("python") != std::string::npos)
            return {"text", "x-python"};
        return {"text", "plain"};
    }

    // fall back to a small extension map (python-mimetypes heritage)
    static const std::map<std::string, std::pair<std::string, std::string>> EXT_MAP = {
        {"txt", {"text", "plain"}}, {"md", {"text", "markdown"}}, {"json", {"text", "json"}},
        {"xml", {"text", "xml"}}, {"html", {"text", "html"}}, {"htm", {"text", "html"}},
        {"css", {"text", "css"}}, {"js", {"text", "javascript"}},
        {"png", {"image", "png"}}, {"jpg", {"image", "jpeg"}}, {"jpeg", {"image", "jpeg"}},
        {"gif", {"image", "gif"}}, {"svg", {"image", "svg"}}, {"webp", {"image", "webp"}},
        {"mp3", {"audio", "mpeg"}}, {"wav", {"audio", "wav"}}, {"flac", {"audio", "flac"}},
        {"ogg", {"audio", "ogg"}}, {"mp4", {"video", "mp4"}}, {"mkv", {"video", "matroska"}},
        {"zip", {"archive", "zip"}}, {"gz", {"archive", "gzip"}}, {"pdf", {"document", "pdf"}},
        {"c", {"text", "x-c"}}, {"h", {"text", "x-c"}}, {"cpp", {"text", "x-c++"}},
        {"py", {"text", "x-python"}}, {"sh", {"text", "x-shellscript"}},
    };
    std::string ext = path.extension().string();
    if (!ext.empty() && ext[0] == '.') ext = ext.substr(1);
    for (auto& ch : ext) ch = (char)std::tolower((unsigned char)ch);
    auto it = EXT_MAP.find(ext);
    if (it != EXT_MAP.end()) return it->second;
    return {"binary", "unknown"};
}

// ===========================================================================
// 4. MEDIA DIMENSIONS (native PNG/GIF/BMP/JPEG/WEBP parsing)
// ===========================================================================

static std::optional<std::pair<unsigned, unsigned>> image_dimensions(const fs::path& path) {
    std::ifstream f(path, std::ios::binary);
    if (!f) return std::nullopt;
    std::error_code ec_fsize;
        auto size = fs::file_size(path, ec_fsize);
        if (ec_fsize)
            return std::nullopt;
    std::string head(64, '\0');
    f.read(head.data(), 64);
    head.resize(f.gcount());
    if (size < 8) return std::nullopt;

    auto be32 = [&](const std::string& s, size_t at) -> unsigned {
        return ((unsigned)(unsigned char)s[at] << 24) | ((unsigned)(unsigned char)s[at+1] << 16) |
               ((unsigned)(unsigned char)s[at+2] << 8) | (unsigned)(unsigned char)s[at+3];
    };
    auto le16 = [&](const std::string& s, size_t at) -> unsigned {
        return (unsigned)(unsigned char)s[at] | ((unsigned)(unsigned char)s[at+1] << 8);
    };
    auto le32 = [&](const std::string& s, size_t at) -> long {
        return (long)(unsigned)(unsigned char)s[at] |
               ((long)(unsigned)(unsigned char)s[at+1] << 8) |
               ((long)(unsigned)(unsigned char)s[at+2] << 16) |
               ((long)(unsigned)(unsigned char)s[at+3] << 24);
    };

    if (starts_with(head, 0, "\x89PNG", 4) && size >= 24)
        return std::make_pair(be32(head, 16), be32(head, 24));
    if (starts_with(head, 0, "GIF87a", 6) || starts_with(head, 0, "GIF89a", 6))
        return std::make_pair(le16(head, 6), le16(head, 8));
    if (starts_with(head, 0, "BM", 2) && size > 26) {
        long w = le32(head, 18), h = le32(head, 22);
        return std::make_pair((unsigned)std::labs(w), (unsigned)std::labs(h));
    }
    if (starts_with(head, 0, "RIFF", 4) && starts_with(head, 8, "WEBP", 4)) {
        if (starts_with(head, 12, "VP8X", 4)) {
            unsigned w = ((unsigned)(unsigned char)head[24]) |
                          ((unsigned)(unsigned char)head[25] << 8) |
                          ((unsigned)(unsigned char)head[26] << 16);
            unsigned h = ((unsigned)(unsigned char)head[27]) |
                          ((unsigned)(unsigned char)head[28] << 8) |
                          ((unsigned)(unsigned char)head[29] << 16);
            return std::make_pair(w + 1, h + 1);
        }
        if (starts_with(head, 12, "VP8 ", 4)) {
            f.clear(); f.seekg(26);
            char b[4];
            f.read(b, 4);
            if (f.gcount() == 4)
                return std::make_pair((unsigned char)b[0] | ((unsigned char)b[1] << 8),
                                      (unsigned char)b[2] | ((unsigned char)b[3] << 8));
        }
        if (starts_with(head, 12, "VP8L", 4)) {
            unsigned bits = (unsigned)(unsigned char)head[21] |
                            ((unsigned)(unsigned char)head[22] << 8) |
                            ((unsigned)(unsigned char)head[23] << 16) |
                            ((unsigned)(unsigned char)head[24] << 24);
            return std::make_pair((bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1);
        }
    }
    if (starts_with(head, 0, "\xff\xd8\xff", 3)) {
        f.clear(); f.seekg(2);
        while (f.good()) {
            char mk[2];
            f.read(mk, 2);
            if (f.gcount() < 2) return std::nullopt;
            if (mk[0] != (char)0xFF) return std::nullopt;
            unsigned char code = (unsigned char)mk[1];
            if (code == 0xD8 || code == 0x01 || (code >= 0xD0 && code <= 0xD7)) continue;
            char lb[2];
            f.read(lb, 2);
            if (f.gcount() < 2) return std::nullopt;
            unsigned seglen = ((unsigned)(unsigned char)lb[0] << 8) | (unsigned)(unsigned char)lb[1];
            bool isSOF = (code == 0xC0 || code == 0xC1 || code == 0xC2 || code == 0xC3 ||
                          code == 0xC5 || code == 0xC6 || code == 0xC7 || code == 0xC9 ||
                          code == 0xCA || code == 0xCB || code == 0xCD || code == 0xCE ||
                          code == 0xCF);
            if (isSOF) {
                char d[5];
                f.read(d, 5);
                if (f.gcount() < 5) return std::nullopt;
                unsigned h = ((unsigned)(unsigned char)d[1] << 8) | (unsigned)(unsigned char)d[2];
                unsigned w = ((unsigned)(unsigned char)d[3] << 8) | (unsigned)(unsigned char)d[4];
                return std::make_pair(w, h);
            }
            f.seekg((long)seglen - 2, std::ios::cur);
        }
    }
    return std::nullopt;
}

static const std::vector<std::pair<unsigned, const char*>> RESOLUTION_TIERS = {
    {240, "TINY"}, {360, "MINI"}, {480, "SMALLER"}, {600, "SMALL"},
    {900, "MEDIUM"}, {1280, "BIG"}, {1920, "BIGGER"}, {0xFFFFFFFFu, "HUGE"},
};

static std::string resolution_format_label(int w, int h) {
    if (w <= 0 || h <= 0) return "ZERO";
    unsigned edge = (unsigned)std::max(w, h);
    for (const auto& t : RESOLUTION_TIERS)
        if (edge <= t.first) {
            std::string orient = (w == h) ? "SQUARE" : (w > h ? "WIDE" : "HIGH");
            return std::string(t.second) + "-" + orient;
        }
    return "HUGE-?";     // unreachable
}

static std::string decimal_size_label(unsigned long long n, bool format_style) {
    static const std::pair<const char*, unsigned long long> divs[] = {
        {"Tera", 1000000000000ull}, {"Giga", 1000000000ull}, {"Mega", 1000000ull},
        {"Kilo", 1000ull}, {"Byte", 1ull}};
    static const std::pair<const char*, unsigned long long> sizes[] = {
        {"TB", 1000000000000ull}, {"GB", 1000000000ull}, {"MB", 1000000ull},
        {"KB", 1000ull}, {"B", 1ull}};
    if (format_style) {
        for (const auto& d : divs) {
            unsigned long long q = n / d.second;
            if (q > 0) return std::to_string(q) + "-" + d.first;
        }
        return "0-Byte";
    }
    for (const auto& s : sizes) {
        unsigned long long q = n / s.second;
        if (q >= 1) return std::to_string(q) + s.first;
    }
    return "0B";
}

// ===========================================================================
// 5. FILE METADATA (V2.x getters, unified into one record)
// ===========================================================================

struct FileFacts {
    fs::path path;
    std::string mime_main, mime_sub;
    unsigned long long size = 0;
    std::optional<std::pair<unsigned, unsigned>> dims;
    std::tm created{}, modified{}, accessed{};
    std::map<std::string, std::string> hashes;
    // V16.1+ native metadata
    std::map<std::string, std::string> exif;
    std::map<std::string, std::string> id3;
    bool meta_done = false;

    std::string name() const { return path.filename().string(); }
    std::string stem() const {
        std::string n = name();
        size_t dot = n.find_last_of('.');
        return (dot == std::string::npos || dot == 0) ? n : n.substr(0, dot);
    }
    std::string ext() const {
        std::string n = name();
        size_t dot = n.find_last_of('.');
        if (dot == std::string::npos || dot == 0) return "";
        std::string e = n.substr(dot + 1);
        for (auto& c : e) c = (char)std::tolower((unsigned char)c);
        return e;
    }
    std::string time_str(const std::tm& t, const char* fmt) const {
        char buf[64];
        std::strftime(buf, sizeof buf, fmt, &t);
        return buf;
    }
};

static std::tm tm_from_time(std::time_t t) {
    std::tm out{};
    localtime_r(&t, &out);
    return out;
}

static std::string hash_file(const fs::path& p, const std::string& algo_key) {
    std::ifstream f(p, std::ios::binary);
    if (!f) return "";
    Hasher h(algo_key);
    char buf[1 << 20];
    while (f.read(buf, sizeof buf) || f.gcount() > 0) {
        h.update(reinterpret_cast<const unsigned char*>(buf), f.gcount());
    }
    return h.hexdigest();
}

static std::map<std::string, std::string> read_exif(const fs::path& p);
static std::map<std::string, std::string> read_id3(const fs::path& p);

static void meta_facts(FileFacts& facts) {
    if (facts.meta_done) return;
    facts.meta_done = true;
    if (facts.mime_main == "image" && facts.mime_sub == "jpeg") {
        // EXIF parser below fills facts.exif
        facts.exif = read_exif(facts.path);
    }
    std::string e = facts.path.extension().string();
    for (auto& c : e) c = (char)std::tolower((unsigned char)c);
    if (facts.mime_sub == "mpeg" || e == ".mp3" || e == ".mpga") {
        facts.id3 = read_id3(facts.path);
    }
}

static void gather_facts(FileFacts& facts, const std::set<std::string>& want_hashes) {
    auto mime = sniff_mime(facts.path);
    facts.mime_main = mime.first;
    facts.mime_sub = mime.second;
    std::error_code ec;
    facts.size = fs::file_size(facts.path, ec);
    if (ec) facts.size = 0;
    // POSIX stat: C++17 has no portable file_clock -> time_t conversion
    struct stat st{};
    if (::stat(facts.path.c_str(), &st) == 0) {
        facts.modified = tm_from_time(st.st_mtime);
        facts.accessed = tm_from_time(st.st_atime);
        facts.created = facts.modified;          // st_ctime reflects metadata churn
    } else {
        facts.created = facts.modified = facts.accessed = tm_from_time(std::time(nullptr));
    }
    if (facts.mime_main == "image" || facts.mime_sub == "webm" ||
        facts.mime_sub == "mp4" || facts.mime_sub == "avi" ||
        facts.mime_sub == "quicktime" || facts.mime_sub == "matroska") {
        facts.dims = image_dimensions(facts.path);
    }
    for (const auto& kw : want_hashes) {
        if (facts.size > 0) facts.hashes[kw] = hash_file(facts.path, kw);
    }
}

// ===========================================================================
// 6. TEMPLATE ENGINE (V9 Resolve_Value + V17 prefix/fallback language)
// ===========================================================================

static std::string slugify(const std::string& text) {
    std::string kept;
    for (unsigned char ch : text) {
        if (std::isalnum(ch) || ch == '-' || ch == '_' || ch == '.') kept += (char)ch;
        else kept += '-';
    }
    std::string out;
    bool prev_dash = false;
    for (char c : kept) {
        if (c == '-') {
            if (!prev_dash) out += '-';
            prev_dash = true;
        } else { out += c; prev_dash = false; }
    }
    while (!out.empty() && out.front() == '-') out.erase(out.begin());
    while (!out.empty() && out.back() == '-') out.pop_back();
    return out;
}

static std::string to_lower(std::string s) {
    for (auto& c : s) c = (char)std::tolower((unsigned char)c);
    return s;
}
static std::string to_upper(std::string s) {
    for (auto& c : s) c = (char)std::toupper((unsigned char)c);
    return s;
}

static const std::map<std::string, std::string> HASH_ALGOS = {
    {"md5sum", "md5"}, {"sha1sum", "sha1"}, {"sha224sum", "sha224"},
    {"sha256sum", "sha256"}, {"sha384sum", "sha384"}, {"sha512sum", "sha512"},
};

class TemplateEngine {
public:
    TemplateEngine(const std::string& spec, const std::string& context = "path",
                   const std::string& random_value = "")
        : spec_(spec), context_(context), random_(random_value) {}

    std::string keyword_value(FileFacts& f, const std::string& kw) {
        meta_facts(f);
        if (kw == "exif-make") return f.exif.count("make") ? f.exif["make"] : "";
        if (kw == "exif-model") return f.exif.count("model") ? f.exif["model"] : "";
        if (kw == "exif-datetime") {
            if (f.exif.count("datetime")) return f.exif["datetime"];
            if (f.exif.count("dt_original")) return f.exif["dt_original"];
            return "";
        }
        if (kw == "exif-date") {
            std::string v;
            if (f.exif.count("datetime")) v = f.exif["datetime"];
            else if (f.exif.count("dt_original")) v = f.exif["dt_original"];
            return v.size() >= 10 ? v.substr(0, 10) : "";
        }
        if (kw == "exif-orientation")
            return f.exif.count("orientation") ? f.exif["orientation"] : "";
        if (kw.rfind("id3-", 0) == 0) {
            std::string k = kw.substr(4);
            return f.id3.count(k) ? f.id3[k] : "";
        }
        if (kw == "title") {
            if (f.id3.count("title") && !f.id3["title"].empty()) return f.id3["title"];
            if (f.exif.count("model") && !f.exif["model"].empty()) return f.exif["model"];
            return f.stem();
        }
        if (kw == "created") return f.time_str(f.created, "%Y-%m-%d-%H-%M-%S");
        if (kw == "modified") return f.time_str(f.modified, "%Y-%m-%d-%H-%M-%S");
        if (kw == "accessed") return f.time_str(f.accessed, "%Y-%m-%d-%H-%M-%S");
        if (kw == "created-time") return f.time_str(f.created, "%H-%M-%S");
        if (kw == "modified-time") return f.time_str(f.modified, "%H-%M-%S");
        if (kw == "accessed-time") return f.time_str(f.accessed, "%H-%M-%S");
        if (kw == "created-date") return f.time_str(f.created, "%Y-%m-%d");
        if (kw == "modified-date") return f.time_str(f.modified, "%Y-%m-%d");
        if (kw == "accessed-date") return f.time_str(f.accessed, "%Y-%m-%d");
        if (kw == "year") return f.time_str(f.modified, "%Y");
        if (kw == "month") return f.time_str(f.modified, "%m");
        if (kw == "day") return f.time_str(f.modified, "%d");
        if (kw == "year+month") return f.time_str(f.modified, "%Y-%m");
        if (kw == "year+month+day") return f.time_str(f.modified, "%Y-%m-%d");
        if (kw == "mime" || kw == "mime-main" || kw == "mimemain" || kw == "type")
            return f.mime_main;
        if (kw == "mime-sub") return f.mime_sub;
        if (kw == "extension" || kw == "ext") return f.ext().empty() ? "NOEXT" : f.ext();
        if (kw == "ext-lower") return to_lower(f.ext().empty() ? "noext" : f.ext());
        if (kw == "ext-upper") return to_upper(f.ext().empty() ? "NOEXT" : f.ext());
        if (kw == "filename" || kw == "name" || kw == "basename") return f.name();
        if (kw == "stem" || kw == "original") return f.stem();
        if (kw == "size") return decimal_size_label(f.size, false);
        if (kw == "format") return decimal_size_label(f.size, true);
        if (kw == "size+format")
            return decimal_size_label(f.size, false) + "-" + decimal_size_label(f.size, true);
        if (kw == "format+size")
            return decimal_size_label(f.size, true) + "-" + decimal_size_label(f.size, false);
        if (kw == "pixel-size" || kw == "resolution" || kw == "dims") {
            if (f.dims) return std::to_string(f.dims->first) + "x" + std::to_string(f.dims->second);
            return "0x0";
        }
        if (kw == "pixel-format" || kw == "resolution-format") {
            if (f.dims) return resolution_format_label((int)f.dims->first, (int)f.dims->second);
            return "ZERO";
        }
        if (HASH_ALGOS.count(kw)) {
            auto it = f.hashes.find(kw);
            return it != f.hashes.end() ? it->second : "";
        }
        if (kw == "random") return random_;
        return "";
    }

    std::string segment(FileFacts& f, const std::string& seg_in) {
        std::string value_style = "default";
        std::string expr = trim(seg_in);
        while (true) {
            std::string low = to_lower(expr);
            if (low.rfind("lower:", 0) == 0) { expr = expr.substr(6); value_style = "lower"; }
            else if (low.rfind("upper:", 0) == 0) { expr = expr.substr(6); value_style = "upper"; }
            else if (low.rfind("raw:", 0) == 0) { expr = expr.substr(4); value_style = "raw"; }
            else break;
        }
        std::string raw_value;
        if (expr.find('|') != std::string::npos) {
            size_t start = 0;
            while (raw_value.empty() && start <= expr.size()) {
                size_t bar = expr.find('|', start);
                std::string cand = trim(expr.substr(start,
                    bar == std::string::npos ? std::string::npos : bar - start));
                if (!cand.empty()) raw_value = keyword_value(f, cand);
                if (bar == std::string::npos) break;
                start = bar + 1;
            }
        } else {
            raw_value = keyword_value(f, trim(expr));
        }
        if (raw_value.empty()) return "";
        if (value_style == "raw") return raw_value;
        std::string out;
        if (context_ == "path") out = to_upper(slugify(raw_value));
        else if (context_ == "name") out = slugify(raw_value);
        else out = raw_value;
        if (value_style == "lower") out = to_lower(out);
        else if (value_style == "upper") out = to_upper(out);
        return out;
    }

    std::string resolve(FileFacts& f) {
        if (spec_.empty()) return "";
        std::vector<std::string> segs;
        size_t start = 0;
        while (true) {
            size_t slash = spec_.find('/', start);
            std::string s = trim(spec_.substr(start,
                slash == std::string::npos ? std::string::npos : slash - start));
            if (!s.empty()) segs.push_back(s);
            if (slash == std::string::npos) break;
            start = slash + 1;
        }
        std::string out, joiner = (context_ == "path") ? "/" : "_";
        bool first = true;
        for (auto& s : segs) {
            std::string r = segment(f, s);
            if (r.empty()) continue;
            if (!first) out += joiner;
            out += r;
            first = false;
        }
        return out;
    }

private:
    static std::string trim(const std::string& s) {
        size_t a = s.find_first_not_of(" \t\r\n");
        if (a == std::string::npos) return "";
        size_t b = s.find_last_not_of(" \t\r\n");
        return s.substr(a, b - a + 1);
    }
    std::string spec_, context_, random_;
};

// ===========================================================================
// NATIVE METADATA (V16.1+ ExifTool era): JPEG EXIF + MP3 ID3 parsers
// ===========================================================================

static const std::map<unsigned, const char*> EXIF_TAGS = {
    {0x010F, "make"}, {0x0110, "model"}, {0x0112, "orientation"},
    {0x0132, "datetime"}, {0x9003, "dt_original"},
    {0x829A, "exposure"}, {0x829D, "fnumber"}, {0x8827, "iso"},
};

static std::string read_file_bytes(const fs::path& p, size_t limit) {
    std::ifstream f(p, std::ios::binary);
    if (!f) return "";
    std::string out(limit, '\0');
    f.read(out.data(), limit);
    out.resize(f.gcount());
    return out;
}

static std::map<std::string, std::string> parse_tiff(const std::string& buf, size_t tiff) {
    std::map<std::string, std::string> out;
    if (tiff + 8 > buf.size()) return out;
    bool little;
    if (buf.compare(tiff, 2, "II") == 0) little = true;
    else if (buf.compare(tiff, 2, "MM") == 0) little = false;
    else return out;
    auto rd16 = [&](size_t at) -> unsigned {
        unsigned char b0 = (unsigned char)buf[at], b1 = (unsigned char)buf[at+1];
        return little ? (b0 | (b1 << 8)) : ((b0 << 8) | b1);
    };
    auto rd32 = [&](size_t at) -> unsigned long {
        unsigned v = 0;
        for (int i = 0; i < 4; ++i) {
            unsigned char b = (unsigned char)buf[at + (little ? i : 3 - i)];
            v = (v << 8) | b;
        }
        return v;
    };
    if (rd16(tiff + 2) != 42) return out;
    size_t ifd = tiff + rd32(tiff + 4);
    if (ifd + 2 > buf.size()) return out;
    unsigned count = rd16(ifd);
    for (unsigned i = 0; i < count && i < 256; ++i) {
        size_t e = ifd + 2 + (size_t)i * 12;
        if (e + 12 > buf.size()) break;
        unsigned tag = rd16(e), typ = rd16(e + 2);
        unsigned long cnt = rd32(e + 4);
        auto tag_it = EXIF_TAGS.find(tag);
        if (tag_it == EXIF_TAGS.end()) continue;
        const char* key = tag_it->second;
        if (typ == 2) {                          // ASCII
            std::string raw;
            if (cnt <= 4) raw = buf.substr(e + 8, cnt);
            else {
                size_t off = rd32(e + 8);
                if (tiff + off + cnt <= buf.size())
                    raw = buf.substr(tiff + off, cnt);
            }
            size_t z = raw.find('\0');
            if (z != std::string::npos) raw = raw.substr(0, z);
            out[key] = raw;
        } else if (typ == 3) {
            out[key] = std::to_string(rd16(e + 8));
        } else if (typ == 4) {
            out[key] = std::to_string(rd32(e + 8));
        } else if (typ == 10) {                   // RATIONAL
            size_t off = rd32(e + 8);
            if (tiff + off + 8 <= buf.size()) {
                unsigned long num = rd32(tiff + off), den = rd32(tiff + off + 4);
                char b[64];
                std::snprintf(b, sizeof b, "%.6f", den ? (double)num / (double)den : 0.0);
                out[key] = b;
            }
        }
    }
    return out;
}

static std::map<std::string, std::string> read_exif(const fs::path& p) {
    std::map<std::string, std::string> out;
    std::string data = read_file_bytes(p, 2 << 20);
    if (!starts_with(data, 0, "\xff\xd8\xff", 3)) return out;
    size_t pos = 2, n = data.size();
    while (pos + 4 < n) {
        if ((unsigned char)data[pos] != 0xFF) { pos += 1; continue; }
        unsigned char code = (unsigned char)data[pos + 1];
        if (code == 0xD8 || code == 0x01 || (code >= 0xD0 && code <= 0xD7)) { pos += 2; continue; }
        if (pos + 4 > n) break;
        unsigned seglen = ((unsigned)(unsigned char)data[pos+2] << 8) | (unsigned)(unsigned char)data[pos+3];
        if (seglen < 2 || pos + 2 + seglen > n) break;
        if (code == 0xE1 && data.compare(pos + 4, 6, "Exif\x00\x00") == 0) {
            auto sub = parse_tiff(data, pos + 10);
            out.insert(sub.begin(), sub.end());
            break;
        }
        pos += 2 + seglen;
    }
    return out;
}

static std::string decode_id3_text(int enc, std::string raw) {
    if (enc == 0 || enc == 3) {
        size_t z = raw.find('\0');
        if (z != std::string::npos) raw = raw.substr(0, z);
    }
    return raw;   // the practical subset: treat as latin-1/utf-8 passthrough
}

static unsigned syncsafe(const std::string& h, size_t at) {
    return (((unsigned)(unsigned char)h[at] & 0x7F) << 21) |
           (((unsigned)(unsigned char)h[at+1] & 0x7F) << 14) |
           (((unsigned)(unsigned char)h[at+2] & 0x7F) << 7) |
           ((unsigned)(unsigned char)h[at+3] & 0x7F);
}

static std::map<std::string, std::string> read_id3(const fs::path& p) {
    std::map<std::string, std::string> out;
    std::ifstream f(p, std::ios::binary);
    if (!f) return out;
    std::string head(1 << 20, '\0');
    f.read(head.data(), head.size());
    head.resize(f.gcount());
    std::string tail;
    f.clear();
    if (f.seekg(-128, std::ios::end)) {
        tail.resize(128);
        f.read(tail.data(), 128);
        tail.resize(f.gcount());
    }

    if (head.compare(0, 3, "ID3") == 0) {
        int ver = (unsigned char)head[3];
        unsigned size = syncsafe(head, 6);
        size_t pos = 10, end = std::min((size_t)10 + size, head.size());
        static const std::map<std::string, const char*> NAMES = {
            {"TIT2", "title"}, {"TPE1", "artist"}, {"TALB", "album"},
            {"TYER", "year"}, {"TDRC", "year"}, {"TRCK", "track"}, {"TCON", "genre"}};
        while (pos + 10 <= end) {
            std::string fid = head.substr(pos, 4);
            if (fid.find_first_not_of('\0') == std::string::npos) break;
            if (fid[0] != 'T' && fid[0] != 'A' && fid[0] != 'C' && fid[0] != ':') break;
            unsigned fsize = (ver == 4) ? syncsafe(head, pos + 4)
                : (((unsigned)(unsigned char)head[pos+4] << 24) |
                   ((unsigned)(unsigned char)head[pos+5] << 16) |
                   ((unsigned)(unsigned char)head[pos+6] << 8) |
                   (unsigned)(unsigned char)head[pos+7]);
            if (fsize == 0 || pos + 10 + fsize > head.size()) break;
            int enc = (unsigned char)head[pos + 10];
            std::string value = decode_id3_text(enc, head.substr(pos + 11, fsize - 1));
            auto nit = NAMES.find(fid);
            if (nit != NAMES.end() && !value.empty()) out[nit->second] = value;
            pos += 10 + fsize;
        }
    }

    if (tail.size() == 128 && tail.compare(0, 3, "TAG") == 0) {
        auto txt = [&](size_t o, size_t l) {
            std::string s = tail.substr(o, l);
            size_t end = s.find_last_not_of('\0');
            s = s.substr(0, end == std::string::npos ? 0 : end + 1);
            while (!s.empty() && (s.back() == ' ')) s.pop_back();
            return s;
        };
        if (!out.count("title")) out["title"] = txt(3, 30);
        if (!out.count("artist")) out["artist"] = txt(33, 30);
        if (!out.count("album")) out["album"] = txt(63, 30);
        if (!out.count("year")) out["year"] = txt(93, 4);
        if ((unsigned char)tail[125] == 0 && (unsigned char)tail[126] != 0)
            out["track"] = std::to_string((unsigned char)tail[126]);
    }
    return out;
}

// ===========================================================================
// MAGIC MODULE (V17.5 lineage) - --magic: magic-number detection report
// 237 embedded signatures, generated from the Python source of truth.
// ===========================================================================

static const int MAGIC_SPAN = 32774;

struct MagicEntry { int off; const char* sig; const char* name; const char* exts; };
static const MagicEntry MAGIC_TABLE[] = {
    {64, "3c3c3c3c204f7261636c6520564d2056", "VirtualBox VDI disk", "vdi"},
    {4086, "535741505350414345", "Linux swap area", "img"},
    {60, "424f4f4b4d4f4249", "MOBI e-book", "mobi,prc"},
    {3, "4e54465320202020", "NTFS filesystem", "img"},
    {64, "5f42485266535f4d", "Btrfs filesystem", "img"},
    {32769, "4344303031", "ISO 9660 image", "iso,img"},
    {257, "7573746172", "TAR archive", "tar"},
    {1, "2d6c683?2d", "LHA/LZH archive", "lzh,lha"},
    {44, "5343524d", "S3M module", "s3m"},
    {108, "4d214b21", "Amiga MOD module", "mod"},
    {108, "46545434", "Amiga MOD module", "mod"},
    {108, "46545438", "Amiga MOD module", "mod"},
    {108, "3443484e", "Amiga MOD module", "mod"},
    {108, "3643484e", "Amiga MOD module", "mod"},
    {108, "3843484e", "Amiga MOD module", "mod"},
    {8, "2142444e", "Outlook PST database", "pst"},
    {108, "4d2e4b", "Amiga MOD module", "mod"},
    {1080, "53ef", "Linux ext2/3/4 filesystem", "img"},
    {0, "4c0000000114020000000000c0000000", "Windows shortcut", "lnk"},
    {0, "457874656e646564204d6f64756c65", "FastTracker XM module", "xm"},
    {0, "53514c69746520666f726d61742033", "SQLite database", "db,sqlite,sqlite3"},
    {0, "437265617469766520566f696365", "Creative Voice audio (VOC)", "voc"},
    {0, "414e44524f4944204241434b5550", "Android backup", "ab"},
    {0, "0000000c6a5020200d0a870a", "JPEG 2000 (JP2)", "jp2"},
    {0, "3c53746174615f6474613e", "Stata dataset", "dta"},
    {0, "64383a616e6e6f756e6365", "BitTorrent metainfo", "torrent"},
    {0, "233f52414449414e4345", "Radiance HDR image", "hdr"},
    {0, "2d2d2d2d2d424547494e", "Armored ASCII block (PGP/PEM/SSH)", "asc,pgp,gpg"},
    {0, "52494646????????57454250", "WEBP image", "webp"},
    {0, "52494646????????57415645", "WAV audio", "wav"},
    {0, "52494646????????41564920", "AVI video", "avi"},
    {0, "52494646????????414d5620", "AMV video", "amv"},
    {0, "464f524d????????41494646", "AIFF audio", "aiff,aif"},
    {0, "464f524d????????41494643", "AIFC audio", "aifc"},
    {0, "????????6674797071742020", "QuickTime MOV video", "mov"},
    {0, "????????667479704d344120", "M4A audio", "m4a"},
    {0, "????????667479704d345620", "M4V video", "m4v"},
    {0, "????????6674797068656963", "HEIC/HEIF image", "heic,heif,hif"},
    {0, "????????6674797068656978", "HEIC/HEIF image", "heic,heif,hif"},
    {0, "????????6674797068656966", "HEIC/HEIF image", "heic,heif,hif"},
    {0, "????????667479706d696631", "HEIC/HEIF image", "heic,heif,hif"},
    {0, "????????667479706d736631", "HEIC/HEIF image", "heic,heif,hif"},
    {0, "????????6674797061766966", "AVIF image", "avif"},
    {0, "????????6674797061766973", "AVIF image", "avif"},
    {0, "????????667479706a703220", "JPEG 2000 (JP2)", "jp2"},
    {0, "????????6674797033677034", "3GP video", "3gp"},
    {0, "????????6674797033677035", "3GP video", "3gp"},
    {0, "????????6674797033677036", "3GP video", "3gp"},
    {0, "????????6674797033673261", "3G2 video", "3g2"},
    {0, "????????6674797069736f6d", "MP4 video", "mp4"},
    {0, "????????6674797069736f32", "MP4 video", "mp4"},
    {0, "????????667479706d703431", "MP4 video", "mp4"},
    {0, "????????667479706d703432", "MP4 video", "mp4"},
    {0, "????????6674797061766331", "MP4 video", "mp4"},
    {0, "????????6674797064617368", "DASH video", "mpd,m4s,mp4"},
    {0, "????????6674797066347620", "Flash F4V video", "f4v"},
    {0, "52494646????????41434f4e", "Windows animated cursor", "ani"},
    {0, "464f524d????????494c424d", "Amiga ILBM image", "iff,lbm"},
    {0, "464f524d????????38535658", "Amiga 8SVX audio", "iff,8svx"},
    {0, "464f524d????????4d415544", "Amiga MAUD audio", "maud"},
    {0, "52494646????????524d4944", "RIFF MIDI (RMID)", "rmi"},
    {0, "52494646????????7366626b", "SoundFont SF2", "sf2"},
    {0, "????????6674797068766331", "HEVC video", "hevc,h265"},
    {0, "????????6674797068657631", "HEVC video", "hevc,h265"},
    {0, "????????6674797061763031", "AV1 video", "av1"},
    {0, "????????6674797044495658", "DivX video", "divx"},
    {0, "????????667479704d344220", "M4B audiobook", "m4b"},
    {0, "67696d7020786366", "GIMP XCF image", "xcf"},
    {0, "3026b2758e66cf11", "ASF media (WMA/WMV)", "wma,wmv,asf"},
    {0, "d0cf11e0a1b11ae1", "MS Office/OLE compound", "doc,xls,ppt,msi,cfg"},
    {0, "41542654464f524d", "DjVu document", "djvu,djv"},
    {0, "49544f4c49544c53", "MS Reader LIT e-book", "lit"},
    {0, "7668647866696c65", "Hyper-V VHDX disk", "vhdx"},
    {0, "2321414d522d5742", "AMR-WB speech audio", "amr"},
    {0, "50532d5820455845", "PlayStation executable", "exe"},
    {0, "414e44524f494421", "Android boot image", "img"},
    {0, "5041474544554d50", "Windows kernel dump", "dmp"},
    {0, "5041474544553634", "Windows kernel dump (64-bit)", "dmp"},
    {0, "52494646????????434452", "CorelDRAW document", "cdr"},
    {0, "213c617263683e", "AR archive (deb/static lib)", "a,deb"},
    {0, "53747566664974", "StuffIt archive", "sit"},
    {0, "49492a00????????4352", "Canon CR2 raw image", "cr2"},
    {0, "233f52474245", "Radiance HDR image", "hdr"},
    {0, "377abcaf271c", "7-Zip archive", "7z"},
    {0, "526172211a07", "RAR archive", "rar"},
    {0, "303730373031", "CPIO archive (newc)", "cpio"},
    {0, "303730373037", "CPIO archive (odc)", "cpio"},
    {0, "2a2a4143452a", "ACE archive", "ace"},
    {0, "7b5c72746631", "RTF document", "rtf"},
    {0, "4c554b53babe", "LUKS encrypted volume", "luks,img"},
    {0, "53494d504c45", "FITS astronomy image", "fits"},
    {0, "4152524f5731", "Apache Arrow IPC data", "arrow"},
    {0, "4d41544c4142", "MATLAB MAT-file", "mat"},
    {0, "0d0a870a0a", "JPEG XL container", "jxl"},
    {0, "3c3f786d6c", "XML document", "xml,svg,fb2,rss,xsl,plist"},
    {0, "2321414d52", "AMR speech audio", "amr"},
    {0, "fd377a585a", "XZ stream", "xz,txz"},
    {0, "4d5357494d", "Windows Imaging archive", "wim"},
    {0, "4e45534d1a", "NES sound file", "nsf"},
    {0, "5245444953", "Redis RDB snapshot", "rdb"},
    {0, "????????66747970", "MP4/QuickTime container", "mp4,m4a,mov,3gp,heic"},
    {0, "89504e47", "PNG image", "png"},
    {0, "ff4fff51", "JPEG 2000 codestream", "j2k,jpc"},
    {0, "47494638", "GIF image", "gif"},
    {0, "49492a00", "TIFF image (little-endian)", "tif,tiff"},
    {0, "4d4d002a", "TIFF image (big-endian)", "tif,tiff"},
    {0, "38425053", "Photoshop PSD image", "psd,pdd"},
    {0, "44445320", "DirectDraw Surface texture", "dds"},
    {0, "762f3101", "OpenEXR image", "exr"},
    {0, "00020000", "Windows cursor", "cur"},
    {0, "00010000", "ICO icon / TrueType font", "ico,ttf,otf"},
    {0, "69636e73", "Apple ICNS icon", "icns"},
    {0, "3c737667", "SVG image", "svg"},
    {0, "52494646", "RIFF container", "wav,avi,webp"},
    {0, "46524d38", "DSDIFF audio (DFF)", "dff"},
    {0, "63616666", "Apple CAF audio", "caf"},
    {0, "44534420", "DSD streamfile audio (DSF)", "dsf"},
    {0, "664c6143", "FLAC audio", "flac"},
    {0, "4f676753", "OGG media", "ogg,oga,opus,ogv,ogx"},
    {0, "4d546864", "MIDI music", "mid,midi,rmi,kar"},
    {0, "2e736e64", "NeXT/Sun AU audio", "au,snd"},
    {0, "4d414320", "Monkey Audio (APE)", "ape"},
    {0, "7770766b", "WavPack audio", "wv"},
    {0, "4d50434b", "Musepack audio (SV8)", "mpc"},
    {0, "54544131", "True Audio (TTA)", "tta"},
    {0, "616a6b67", "Shorten audio", "shn"},
    {0, "494d504d", "Impulse Tracker module", "it"},
    {0, "1a45dfa3", "Matroska/WebM video", "mkv,webm,mka,mks"},
    {0, "000001ba", "MPEG program stream", "mpg,mpeg,vob,ps"},
    {0, "000001b3", "MPEG elementary video", "m2v,mpv,mpg"},
    {0, "2e524d46", "RealMedia video", "rm,rmvb"},
    {0, "060e2b34", "MXF video", "mxf"},
    {0, "504b0304", "ZIP/Office document", "zip,docx,xlsx,pptx,odt,jar,apk,epub"},
    {0, "504b0506", "ZIP archive (empty)", "zip"},
    {0, "504b0708", "ZIP archive (spanned)", "zip"},
    {0, "28b52ffd", "Zstandard stream", "zst"},
    {0, "04224d18", "LZ4 frame", "lz4"},
    {0, "5d000080", "LZMA-alone stream", "lzma"},
    {0, "894c5a4f", "LZO compressed archive", "lzo"},
    {0, "4d534346", "MS Cabinet archive", "cab"},
    {0, "edabeedb", "RPM package", "rpm"},
    {0, "50415231", "Apache Parquet data", "parquet"},
    {0, "25504446", "PDF document", "pdf"},
    {0, "25215053", "PostScript/EPS document", "ps,eps,ai"},
    {0, "49545346", "MS Compiled HTML (CHM)", "chm"},
    {0, "4f54544f", "OpenType (CFF) font", "otf"},
    {0, "74746366", "TrueType collection", "ttc"},
    {0, "774f4646", "WOFF font", "woff"},
    {0, "774f4632", "WOFF2 font", "woff2"},
    {0, "7f454c46", "ELF binary", "so,bin,elf,o,ko"},
    {0, "feedface", "Mach-O binary (32-bit BE)", "bin"},
    {0, "cefaedfe", "Mach-O binary (32-bit LE)", "bin"},
    {0, "feedfacf", "Mach-O binary (64-bit BE)", "bin"},
    {0, "cffaedfe", "Mach-O binary (64-bit LE)", "bin"},
    {0, "cafebabe", "Java class / Mach-O fat binary", "class,bin"},
    {0, "0061736d", "WebAssembly module", "wasm"},
    {0, "6465780a", "Android DEX bytecode", "dex,odex"},
    {0, "72656766", "Windows registry hive", "dat,hive,reg"},
    {0, "a1b2c3d4", "pcap packet capture", "pcap,cap"},
    {0, "d4c3b2a1", "pcap packet capture (swapped)", "pcap,cap"},
    {0, "0a0d0d0a", "pcapng packet capture", "pcapng"},
    {0, "4f626a01", "Apache Avro object container", "avro"},
    {0, "43723234", "Chrome extension (CRX)", "crx"},
    {0, "514649fb", "QEMU copy-on-write disk", "qcow,qcow2"},
    {0, "4b444d56", "VMware VMDK disk", "vmdk"},
    {0, "4d4d002b", "TIFF image (BigTIFF)", "tif,tiff"},
    {0, "4949524f", "Olympus ORF raw image", "orf"},
    {0, "49495500", "Panasonic RW2 raw image", "rw2"},
    {0, "4949bc01", "JPEG XR image", "jxr,wdp,hdp"},
    {0, "464c4946", "FLIF image", "flif"},
    {0, "ab4b5458", "KTX/KTX2 texture", "ktx,ktx2"},
    {0, "716f6966", "QOI image", "qoi"},
    {0, "4f465220", "OptimFROG audio", "ofr"},
    {0, "7fff8001", "DTS audio", "dts"},
    {0, "50534944", "Commodore SID tune", "sid"},
    {0, "56676d20", "Video Game Music tune", "vgm"},
    {0, "6e75742f", "NUT video", "nut"},
    {0, "78617221", "XAR archive", "xar"},
    {0, "5041434b", "Git packfile / Quake PAK", "pack,pak"},
    {0, "4d50511a", "Blizzard MPQ archive", "mpq"},
    {0, "49574144", "Doom IWAD game archive", "wad"},
    {0, "50574144", "Doom PWAD game archive", "wad"},
    {0, "444d5321", "Amiga DMS archive", "dms"},
    {0, "4e45531a", "NES ROM image", "nes"},
    {0, "80371240", "Nintendo 64 ROM", "n64,z64"},
    {0, "37804012", "Nintendo 64 ROM (swapped)", "n64,v64"},
    {0, "53454741", "SEGA Mega Drive ROM", "md,gen"},
    {0, "3f5f0300", "Windows Help file", "hlp"},
    {0, "504e5264", "eReader PDB e-book", "pdb"},
    {0, "3c3f7068", "PHP script", "php"},
    {0, "4d444d50", "Windows minidump", "dmp"},
    {0, "aced0005", "Java serialized object", "ser"},
    {0, "feedfeed", "Java keystore", "jks"},
    {0, "58465342", "XFS filesystem", "img"},
    {0, "89484446", "HDF5 dataset", "h5,hdf5"},
    {0, "43444601", "NetCDF classic dataset", "nc"},
    {0, "43444602", "NetCDF 64-bit dataset", "nc"},
    {0, "52445832", "R binary data", "rdata,rds"},
    {0, "42414d01", "BAM sequence data", "bam"},
    {0, "4352414d", "CRAM sequence data", "cram"},
    {0, "44495243", "Git index", "index"},
    {0, "4d4d443?", "Amiga MED module", "med"},
    {0, "ffd8ff", "JPEG image", "jpg,jpeg,jfif"},
    {0, "0a0000", "PCX image", "pcx"},
    {0, "0a0200", "PCX image", "pcx"},
    {0, "0a0300", "PCX image", "pcx"},
    {0, "0a0500", "PCX image", "pcx"},
    {0, "494433", "MP3 audio (ID3v2 tag)", "mp3"},
    {0, "4d502b", "Musepack audio", "mpc"},
    {0, "464c56", "Flash video (FLV)", "flv"},
    {0, "42494b", "Bink video", "bik,bk2"},
    {0, "425a68", "BZIP2 stream", "bz2,tbz2"},
    {0, "1f9d8d", "compress (.Z) archive", "z"},
    {0, "5a4f4f", "ZOO archive", "zoo"},
    {0, "435753", "Shockwave Flash (compressed)", "swf"},
    {0, "465753", "Shockwave Flash", "swf"},
    {0, "5a5753", "Shockwave Flash (LZMA)", "swf"},
    {0, "50370a", "PAM image", "pam"},
    {0, "4d544d", "Multitracker module", "mtm"},
    {0, "800106", "Type 1 font (PFB)", "pfb"},
    {0, "4f5243", "Apache ORC data", "orc"},
    {0, "ff0a", "JPEG XL codestream", "jxl"},
    {0, "424d", "BMP image", "bmp,dib"},
    {0, "5034", "PBM image", "pbm"},
    {0, "5035", "PGM image", "pgm"},
    {0, "5036", "PPM image", "ppm"},
    {0, "fffb", "MP3 audio (MPEG-1)", "mp3"},
    {0, "fff3", "MP3 audio (MPEG-2)", "mp3"},
    {0, "fff2", "MP3 audio (MPEG-2.5)", "mp3"},
    {0, "ffe3", "MP3 audio (MPEG-2.5 LSF)", "mp3"},
    {0, "fff1", "AAC audio (ADTS)", "aac,adts"},
    {0, "fff9", "AAC audio (ADTS)", "aac,adts"},
    {0, "1f8b", "GZIP stream", "gz,tgz"},
    {0, "60ea", "ARJ archive", "arj"},
    {0, "7ffe", "Bourne shell archive", "shar"},
    {0, "4d5a", "DOS/PE executable", "exe,dll,sys,ocx,scr"},
    {0, "2321", "Script (#!)", "sh,py,pl,rb,el,js,ts"},
};

static std::string magic_hex(const fs::path& p) {
    std::ifstream f(p, std::ios::binary);
    if (!f) return "";
    std::string h(MAGIC_SPAN, '\0');
    f.read(h.data(), h.size());
    h.resize(f.gcount());
    static const char* hexd = "0123456789abcdef";
    std::string out;
    out.reserve(h.size() * 2);
    for (unsigned char c : h) { out += hexd[c >> 4]; out += hexd[c & 15]; }
    return out;
}

static bool magic_match(const std::string& h, int off, const char* sig) {
    size_t pos = (size_t)off * 2;
    size_t n = std::strlen(sig);
    if (h.size() < pos + n) return false;
    for (size_t i = 0; i < n; ++i)
        if (sig[i] != '?' && h[pos + i] != sig[i]) return false;
    return true;
}

static std::pair<std::string, std::string> magic_detect(const std::string& h) {
    // MPEG transport stream: 0x47 sync bytes at offsets 0, 188 and 376
    if (h.size() >= 754 && h.compare(0, 2, "47") == 0 &&
        h.compare(376, 2, "47") == 0 && h.compare(752, 2, "47") == 0)
        return {"MPEG-TS", "ts,m2ts,mts"};
    for (const auto& e : MAGIC_TABLE) {
        if (magic_match(h, e.off, e.sig)) return {e.name, e.exts};
    }
    return {"?", ""};
}

static std::string magic_report(const fs::path& path) {
    std::string h = magic_hex(path);
    if (h.empty()) h = "(empty)";
    auto res = magic_detect(h);
    std::string ext = path.extension().string();
    if (!ext.empty() && ext[0] == '.') ext = ext.substr(1);
    for (auto& c : ext) c = (char)std::tolower((unsigned char)c);
    std::string ext_disp = ext.empty() ? "(none)" : ext;
    std::string verdict;
    if (res.first == "?") verdict = "UNKNOWN";
    else if (ext_disp == "(none)") verdict = "NO-EXT";
    else {
        verdict = "MISMATCH";
        std::string list = "," + res.second + ",";
        if (list.find("," + ext_disp + ",") != std::string::npos) verdict = "MATCH";
    }
    return path.string() + "\nmagic: " + h.substr(0, 32) +
           "\ndetected: " + res.first +
           "\nextension: " + ext_disp +
           "\nverdict: " + verdict;
}


// ===========================================================================
// 6b. RAW DEVICE SCAN (V20) - --scan-raw: signature walk + carving
// ===========================================================================
// Scans a raw block device (/dev/sdX) or a disk image file with the same
// 237-entry table used by --magic. Every byte offset is a candidate; in
// copy mode hits are carved out (with format-aware end detection); dummy
// mode reports only. The device is opened read-only and --scan-raw
// refuses remove/trash/shred.

static const size_t RAW_BLOCK_SZ = 1u << 20;
static const size_t RAW_CARRY   = 32800;   // max entry offset + max signature
static const size_t RAW_CARVE_MAX = 5u << 20;

struct RawPat {
    int off;
    std::string sig;        // nibble pattern, '?' = any
    std::string name, exts;
    std::string anchor;     // literal bytes to search for (hex)
    int anchor_nibble;      // nibble index inside sig where anchor starts
};
static std::vector<RawPat> raw_patterns;

static std::string hex_to_bytes(const std::string& hx) {
    std::string out;
    for (size_t i = 0; i + 1 < hx.size(); i += 2)
        out += (char)strtol(hx.substr(i, 2).c_str(), nullptr, 16);
    return out;
}

static void raw_build_patterns() {
    if (!raw_patterns.empty()) return;
    for (const auto& e : MAGIC_TABLE) {
        std::string sig = e.sig;
        if (sig.size() < 4) continue;        // 1-byte signatures are noise
        RawPat p;
        p.off = e.off; p.sig = sig; p.name = e.name; p.exts = e.exts;
        if (sig.find('?') == std::string::npos) {
            p.anchor = hex_to_bytes(sig);
            p.anchor_nibble = 0;
        } else {
            // longest even-aligned even-length known run (>= 4 hex)
            int best_len = 0, best_start = -1;
            int i = 0;
            while (i < (int)sig.size()) {
                if (sig[i] == '?') { ++i; continue; }
                int j = i;
                while (j < (int)sig.size() && sig[j] != '?') ++j;
                for (int s = i; s < j; ++s) {
                    int e2 = j;
                    while ((e2 - s) % 2 != 0) --e2;
                    if (s % 2 == 0 && (e2 - s) >= best_len && (e2 - s) >= 4) {
                        best_len = e2 - s; best_start = s;
                    }
                }
                i = j;
            }
            if (best_start < 0) continue;     // cannot anchor reliably
            p.anchor = hex_to_bytes(sig.substr(best_start, best_len));
            p.anchor_nibble = best_start;
        }
        raw_patterns.push_back(p);
    }
}

static bool raw_sig_match(const std::string& buf, size_t pos, const RawPat& p) {
    // buf is hex; sig nibbles are matched against buf starting at hex index pos
    if (buf.size() < pos + p.sig.size()) return false;
    for (size_t i = 0; i < p.sig.size(); ++i)
        if (p.sig[i] != '?' && buf[pos + i] != p.sig[i]) return false;
    return true;
}

static std::string raw_hex(const std::string& bytes) {
    static const char* hexd = "0123456789abcdef";
    std::string out;
    out.reserve(bytes.size() * 2);
    for (unsigned char c : bytes) { out += hexd[c >> 4]; out += hexd[c & 15]; }
    return out;
}

static std::pair<size_t, bool> raw_carve_size(const std::string& head,
                                             const std::string& name,
                                             size_t cap) {
    auto capped = [&](size_t v) { return std::make_pair(std::min(v, cap), false); };
    auto exact  = [&](size_t v) { return std::make_pair(std::min(v, cap), true); };
    auto rd32be = [&](size_t p) -> unsigned {
        return ((unsigned char)head[p] << 24) | ((unsigned char)head[p+1] << 16) |
               ((unsigned char)head[p+2] << 8) | (unsigned char)head[p+3];
    };
    if (strncmp(name.c_str(), "PNG image", 9) == 0) {
        size_t pos = 8;
        while (pos + 12 <= head.size()) {
            unsigned clen = rd32be(pos);
            std::string ctype = head.substr(pos + 4, 4);
            pos += 12 + (size_t)clen;            // len + type + data + CRC
            if (ctype == "IEND") return exact(pos);
            if (clen > head.size()) return capped(pos);
        }
        return capped(head.size());
    }
    if (strncmp(name.c_str(), "JPEG image", 10) == 0) {
        size_t end = head.rfind("\xff\xd9");
        if (end != std::string::npos) return exact(end + 2);
        return capped(head.size());
    }
    if (strncmp(name.c_str(), "GIF image", 9) == 0) {
        size_t end = head.rfind("\x3b");
        if (end != std::string::npos && end >= 13) return exact(end + 1);
        return capped(head.size());
    }
    if (strncmp(name.c_str(), "ZIP/", 4) == 0 || strncmp(name.c_str(), "ZIP archive", 11) == 0) {
        size_t end = head.rfind("PK\x05\x06");
        if (end != std::string::npos && end + 22 <= head.size())
            return exact(end + 22 + (size_t)head[end + 20] +
                         (size_t)(unsigned char)head[end + 21] * 256);
        return capped(head.size());
    }
    if (strncmp(name.c_str(), "PDF document", 12) == 0) {
        size_t end = head.rfind("%%EOF");
        if (end != std::string::npos) return exact(end + 5);
        return capped(head.size());
    }
    return capped(head.size());
}

struct RawHit {
    unsigned long long offset;
    std::string name, exts;
    size_t size;
    bool exact;
};

static void raw_scan_device(const std::string& dev,
                            std::vector<RawHit>& out) {
    raw_build_patterns();
    std::ifstream f(dev, std::ios::binary);
    if (!f) { std::cout << "RAW-SCAN: cannot open " << dev << "\n"; return; }
    std::ifstream probe(dev, std::ios::binary);
    unsigned long long base = 0, next_allowed = 0;
    std::string carry;
    std::vector<char> block(RAW_BLOCK_SZ);
    std::vector<std::pair<unsigned long long, size_t>> anchors;  // hit cand, pat idx
    while (true) {
        f.read(block.data(), block.size());
        std::streamsize got = f.gcount();
        if (got <= 0) break;
        std::string buf = carry + std::string(block.data(), (size_t)got);
        std::string hexbuf = raw_hex(buf);
        unsigned long long buf_base = base - carry.size();
        anchors.clear();
        for (size_t pi = 0; pi < raw_patterns.size(); ++pi) {
            const RawPat& p = raw_patterns[pi];
            size_t apos = 0;
            while (true) {
                size_t hit = hexbuf.find(raw_hex(p.anchor), apos);
                if (hit == std::string::npos) break;
                apos = hit + 1;
                if (hit % 2 != 0) continue;             // byte alignment
                size_t sig_start = hit - (size_t)p.anchor_nibble;
                if (sig_start % 2 != 0) continue;
                if (raw_sig_match(hexbuf, sig_start, p))
                    anchors.push_back({buf_base + sig_start / 2 - (unsigned long long)p.off, pi});
            }
        }
        std::sort(anchors.begin(), anchors.end());
        for (auto& [hit, pi] : anchors) {
            if (hit < next_allowed) continue;
            const RawPat& p = raw_patterns[pi];
            probe.clear();
            probe.seekg((std::streamoff)hit);
            std::string head(std::min(RAW_CARVE_MAX, RAW_BLOCK_SZ), '\0');
            probe.read(head.data(), head.size());
            head.resize(probe.gcount());
            auto [size, exact] = raw_carve_size(head, p.name, RAW_CARVE_MAX);
            next_allowed = exact ? (hit + size) : (hit + 1);
            out.push_back({hit, p.name, p.exts, size, exact});
        }
        base += (unsigned long long)got;
        carry = buf.size() > RAW_CARRY ? buf.substr(buf.size() - RAW_CARRY) : buf;
    }
}

static std::string raw_json_quote(const std::string& s) {
    std::string out = "\"";
    for (char c : s) {
        if (c == '"' || c == '\\') out += '\\';
        if ((unsigned char)c < 0x20) { char b[8]; std::snprintf(b, 8, "\\u%04x", (unsigned)c); out += b; }
        else out += c;
    }
    return out + "\"";
}

static std::string raw_first_ext(const std::string& exts) {
    if (exts.empty()) return "bin";
    size_t c = exts.find(',');
    return c == std::string::npos ? exts : exts.substr(0, c);
}

static int run_raw_scan(const std::string& dev, const std::string& mode,
                        const fs::path& target, const std::optional<fs::path>& log) {
    if (mode == "move" || mode == "remove" || mode == "trash" || mode == "shred") {
        std::cout << "RAW-SCAN: --scan-raw supports dummy and copy only "
                     "(mode '" << mode << "' refused)\n";
        return 64;
    }
    std::vector<RawHit> hits;
    raw_scan_device(dev, hits);
    std::cout << "RAW-SCAN: " << dev << "\n";
    fs::path outdir = target / "RAW-CARVE";
    if (mode == "copy") fs::create_directories(outdir);
    std::ifstream src(dev, std::ios::binary);
    for (const auto& h : hits) {
        std::string ext = raw_first_ext(h.exts);
        char offhex[32];
        std::snprintf(offhex, sizeof offhex, "0x%012llx %llu",
                      (unsigned long long)h.offset, (unsigned long long)h.offset);
        std::cout << "  hit: " << offhex << " " << h.name << " -> " << ext
                  << " (carve " << h.size << " bytes" << (h.exact ? "" : ", capped") << ")\n";
        if (mode != "copy" || !src) continue;
        char name[32];
        std::snprintf(name, sizeof name, "%012llx",
                      (unsigned long long)h.offset);
        fs::path dest = outdir / (std::string(name) + "." + ext);
        std::ofstream dst(dest, std::ios::binary);
        src.clear();
        src.seekg((std::streamoff)h.offset);
        size_t remaining = h.size;
        char buf[1 << 20];
        while (remaining > 0) {
            size_t want = std::min(remaining, sizeof buf);
            src.read(buf, (std::streamsize)want);
            std::streamsize got = src.gcount();
            if (got <= 0) break;
            dst.write(buf, got);
            remaining -= (size_t)got;
        }
        dst.close();
        std::cout << "  carved: " << dest.string() << "\n";
        if (log) {
            std::ofstream lf(*log, std::ios::app);
            lf << "{\"action\": \"carved\", \"src\": " << raw_json_quote(dev + "@" + std::to_string(h.offset))
               << ", \"dst\": " << raw_json_quote(dest.string()) << "}\n";
        }
    }
    std::cout << "RAW-SCAN: " << hits.size() << " signatures found\n";
    return 0;
}

// ===========================================================================
#if defined(__linux__)
#include <fcntl.h>
#include <sys/ioctl.h>
#include <unistd.h>
#define SORT_BLKGETSIZE64 0x80081272
#ifndef BLKGETSIZE64
#define BLKGETSIZE64 SORT_BLKGETSIZE64
#endif
#endif
#include <cerrno>

// 6c. FS SCAN (V21) - --scan=FSFormat: partition map + per-partition scan
// -------------------------------------------------------------------------
// Two phases: (1) partition discovery from MBR/GPT plus a 512-byte-aligned
// filesystem-signature probe that also finds deleted/lost partitions,
// (2) the V20 signature engine runs inside each selected partition; a
// fragment that crosses the partition end or overlaps another partition is
// marked "broken" (overwritten data). Dummy reports only, copy carves to
// Target/FS-CARVE. The source is only ever opened read-only.

struct FsPart {
    unsigned long long start, size;
    std::string fs;            // may be empty (unknown)
    bool listed;
};

static const char* FS_FORMATS[] = {"all", "ntfs", "exfat", "fat12", "fat16",
    "fat32", "ext", "btrfs", "xfs", "reiserfs", "hfs", "swap", "luks"};

static std::string fs_norm(const std::string& f) {
    std::string s = f;
    for (auto& c : s) c = (char)tolower((unsigned char)c);
    if (s == "ext2" || s == "ext3" || s == "ext4") s = "ext";
    if (s == "hfs+" || s == "hfsx" || s == "hfsplus") s = "hfs";
    return s;
}

static unsigned long long fs_le32(const char* p) {
    return (unsigned char)p[0] | ((unsigned long long)(unsigned char)p[1] << 8) |
           ((unsigned long long)(unsigned char)p[2] << 16) |
           ((unsigned long long)(unsigned char)p[3] << 24);
}

static unsigned long long fs_le64(const char* p) {
    unsigned long long v = 0;
    for (int i = 0; i < 8; ++i)
        v |= (unsigned long long)(unsigned char)p[i] << (8 * i);
    return v;
}

static unsigned long long fs_dev_size(const std::string& path) {
    std::ifstream f(path, std::ios::binary);
    f.seekg(0, std::ios::end);
    if (f.good()) {
        std::streampos n = f.tellg();
        if (n > 0) return (unsigned long long)n;
    }
#if defined(__linux__)
    int fd = ::open(path.c_str(), O_RDONLY);
    if (fd >= 0) {
        unsigned long long sz = 0;
        if (ioctl(fd, BLKGETSIZE64, &sz) == 0 && sz > 0) { ::close(fd); return sz; }
        ::close(fd);
    }
#endif
    return 0;
}

static std::string fs_probe(const std::string& w) {
    auto at = [&](size_t off, size_t n) {
        return w.size() >= off + n;
    };
    if (w.size() >= 6 && w.compare(0, 6, "LUKS\xba\xbe", 6) == 0) return "luks";
    if (w.size() >= 11 && w.compare(3, 8, "NTFS    ") == 0) return "ntfs";
    if (w.size() >= 8 && w.compare(3, 5, "EXFAT ") == 0) return "exfat";
    if (w.size() >= 59 && w.compare(54, 5, "FAT16") == 0) return "fat16";
    if (w.size() >= 59 && w.compare(54, 5, "FAT12") == 0) return "fat12";
    if (w.size() >= 87 && w.compare(82, 5, "FAT32") == 0) return "fat32";
    if (w.size() >= 72 && w.compare(64, 8, "_BHRfS_M") == 0) return "btrfs";
    if (w.size() >= 4 && w.compare(0, 4, "XFSB") == 0) return "xfs";
    if (w.size() >= 60 && (w.compare(52, 8, "ReIsErFs") == 0 ||
        w.compare(52, 8, "ReIsEr2F") == 0 ||
        w.compare(52, 8, "ReIsEr3F") == 0 ||
        w.compare(52, 8, "ReIsEr4F") == 0)) return "reiserfs";
    if (w.size() >= 1026 && (w.compare(1024, 2, "H+") == 0 ||
        w.compare(1024, 2, "HX") == 0)) return "hfs";
    if (w.size() >= 1082 && (unsigned char)w[1080] == 0x53 &&
        (unsigned char)w[1081] == 0xef) return "ext";
    if (w.size() >= 1062 && w.compare(1052, 10, "SWAPSPACE2") == 0) return "swap";
    (void)at;
    return "";
}

static size_t fs_read_at(std::ifstream& f, unsigned long long off,
                         void* buf, size_t n) {
    f.clear();
    f.seekg((std::streamoff)off);
    if (!f.good()) return 0;
    f.read((char*)buf, (std::streamsize)n);
    return f.gcount() > 0 ? (size_t)f.gcount() : 0;
}

static void fs_listed(std::ifstream& f, unsigned long long fsize,
                      std::vector<std::pair<unsigned long long,
                                            unsigned long long>>& out) {
    char mbr[512];
    if (fs_read_at(f, 0, mbr, 512) != 512) return;
    if ((unsigned char)mbr[510] != 0xAA || mbr[511] != 0x55) return;
    unsigned char types[4];
    for (int i = 0; i < 4; ++i) types[i] = (unsigned char)mbr[446 + 16 * i + 4];
    bool gpt = false;
    for (int i = 0; i < 4; ++i) gpt = gpt || types[i] == 0xEE;
    if (gpt) {
        char hdr[512];
        if (fs_read_at(f, 512, hdr, 512) != 512) return;
        if (std::memcmp(hdr, "EFI PART", 8) != 0) return;
        unsigned long long elba = fs_le64(hdr + 72);
        unsigned long long nent = fs_le32(hdr + 80);
        unsigned long long esz = fs_le32(hdr + 84);
        if (esz < 128 || nent == 0 || nent * esz > (4ull << 20)) return;
        std::vector<char> blob((size_t)(nent * esz));
        if (fs_read_at(f, elba * 512, blob.data(), blob.size()) != blob.size()) return;
        for (unsigned long long k = 0; k < nent; ++k) {
            const char* e = blob.data() + (size_t)(k * esz);
            bool any = false;
            for (int b = 0; b < 16; ++b) any = any || e[b] != 0;
            if (!any) continue;
            unsigned long long first = fs_le64(e + 32);
            unsigned long long last = fs_le64(e + 40);
            if (last < first) continue;
            unsigned long long start = first * 512;
            unsigned long long size = (last - first + 1) * 512;
            if (size > 0 && start + size <= fsize)
                out.push_back({start, size});
        }
        return;
    }
    for (int i = 0; i < 4; ++i) {
        unsigned char tb = types[i];
        if (tb == 0x00 || tb == 0x05 || tb == 0x0F || tb == 0xEE || tb == 0x85)
            continue;
        unsigned long long lba = fs_le32(mbr + 446 + 16 * i + 8);
        unsigned long long nsec = fs_le32(mbr + 446 + 16 * i + 12);
        if (nsec == 0) continue;
        unsigned long long start = lba * 512;
        unsigned long long size = nsec * 512;
        if (start + size <= fsize) out.push_back({start, size});
    }
}

static bool fs_partitions(const std::string& path,
                          std::vector<FsPart>& parts,
                          unsigned long long& fsize) {
    std::ifstream f(path, std::ios::binary);
    if (!f) {
        std::cout << "SCAN: cannot open " << path << "\n";
        return false;
    }
    fsize = fs_dev_size(path);
    std::vector<std::pair<unsigned long long, unsigned long long>> listed;
    fs_listed(f, fsize, listed);
    std::vector<FsPart> all;
    char w[1200];
    for (auto& [start, size] : listed) {
        FsPart p{start, size, "", true};
        size_t got = fs_read_at(f, start, w, sizeof w);
        if (got > 0) p.fs = fs_probe(std::string(w, got));
        all.push_back(p);
    }
    if (fsize == 0) {
        if (all.empty()) {
            std::cout << "SCAN: cannot determine size of " << path << "\n";
            return false;
        }
        fsize = 0;
        for (auto& p : all) fsize = std::max(fsize, p.start + p.size);
    }
    unsigned long long off = 0;
    while (off < fsize) {
        bool inside = false;
        for (auto& p : all)
            if (p.listed && off >= p.start && off < p.start + p.size)
                inside = true;
        size_t got = inside ? 0 : fs_read_at(f, off, w, sizeof w);
        if (!inside && got > 0) {
            std::string tok = fs_probe(std::string(w, got));
            if (!tok.empty()) {
                unsigned long long est = fsize;
                for (auto& p : all)
                    if (p.listed && p.start > off && p.start < est)
                        est = p.start;
                all.push_back({off, est - off, tok, false});
            }
        }
        off += 512;
    }
    std::stable_sort(all.begin(), all.end(),
                     [](const FsPart& a, const FsPart& b) {
                         return a.start < b.start;
                     });
    for (auto& p : all) if (p.listed) parts.push_back(p);
    for (auto& p : all) if (!p.listed) parts.push_back(p);
    return true;
}

static bool fs_overlap(const std::vector<FsPart>& parts, size_t idx,
                       unsigned long long hit, unsigned long long size) {
    const FsPart& p = parts[idx];
    if (hit + size > p.start + p.size) return true;
    for (size_t i = 0; i < parts.size(); ++i) {
        if (i == idx) continue;
        if (hit < parts[i].start + parts[i].size &&
            hit + size > parts[i].start) return true;
    }
    return false;
}

static void raw_scan_range(const std::string& dev,
                           unsigned long long lo, unsigned long long hi,
                           std::vector<RawHit>& out) {
    raw_build_patterns();
    std::ifstream f(dev, std::ios::binary);
    if (!f) { std::cout << "SCAN: cannot open " << dev << "\n"; return; }
    std::ifstream probe(dev, std::ios::binary);
    unsigned long long base = lo, next_allowed = lo;
    std::string carry;
    std::vector<char> block(RAW_BLOCK_SZ);
    struct Cand { unsigned long long hit; size_t pi; };
    std::vector<Cand> cands;
    while (base < hi) {
        f.clear();
        f.seekg((std::streamoff)base);
        f.read(block.data(), block.size());
        std::streamsize got = f.gcount();
        if (got <= 0) break;
        std::string buf = carry + std::string(block.data(), (size_t)got);
        std::string hexbuf = raw_hex(buf);
        unsigned long long buf_base = base - carry.size();
        cands.clear();
        for (size_t pi = 0; pi < raw_patterns.size(); ++pi) {
            const RawPat& p = raw_patterns[pi];
            size_t apos = 0;
            while (true) {
                size_t hit = hexbuf.find(raw_hex(p.anchor), apos);
                if (hit == std::string::npos) break;
                apos = hit + 1;
                if (hit % 2 != 0) continue;
                size_t sig_start = hit - (size_t)p.anchor_nibble;
                if (sig_start % 2 != 0) continue;
                if (raw_sig_match(hexbuf, sig_start, p)) {
                    unsigned long long off =
                        buf_base + sig_start / 2 - (unsigned long long)p.off;
                    if (off >= lo && off < hi) cands.push_back({off, pi});
                }
            }
        }
        std::stable_sort(cands.begin(), cands.end(),
                         [&](const Cand& a, const Cand& b) {
                             if (a.hit != b.hit) return a.hit < b.hit;
                             return raw_patterns[a.pi].name <
                                    raw_patterns[b.pi].name;
                         });
        for (auto& c : cands) {
            if (c.hit < next_allowed) continue;
            const RawPat& p = raw_patterns[c.pi];
            probe.clear();
            probe.seekg((std::streamoff)c.hit);
            std::string head(std::min(RAW_CARVE_MAX, RAW_BLOCK_SZ), '\0');
            probe.read(head.data(), head.size());
            head.resize(probe.gcount());
            auto [size, exact] = raw_carve_size(head, p.name, RAW_CARVE_MAX);
            next_allowed = exact ? (c.hit + size) : (c.hit + 1);
            out.push_back({c.hit, p.name, p.exts, size, exact});
        }
        base += (unsigned long long)got;
        carry = buf.size() > RAW_CARRY ? buf.substr(buf.size() - RAW_CARRY)
                                       : buf;
    }
}

struct FsHitInfo {
    size_t part;
    std::string fs;
    unsigned long long offset;
    size_t size;
    std::string name, ext;
    bool exact, broken;
};
static std::function<void(const FsHitInfo&)> g_fs_hit_hook;   // set by the GUI

static bool fs_carve_one(const std::string& dev, unsigned long long off,
                         size_t size, const std::string& ext,
                         const fs::path& dest_dir) {
    std::error_code ec;
    fs::create_directories(dest_dir, ec);
    char nm[32];
    std::snprintf(nm, sizeof nm, "%012llx", off);
    fs::path dest = dest_dir / (std::string(nm) + "." + ext);
    std::ifstream src_f(dev, std::ios::binary);
    if (!src_f) return false;
    std::ofstream dst(dest, std::ios::binary);
    if (!dst) return false;
    src_f.seekg((std::streamoff)off);
    size_t remaining = size;
    char buf[1 << 20];
    while (remaining > 0) {
        size_t want = std::min(remaining, sizeof buf);
        src_f.read(buf, (std::streamsize)want);
        std::streamsize got = src_f.gcount();
        if (got <= 0) break;
        dst.write(buf, got);
        if (!dst) return false;
        remaining -= (size_t)got;
    }
    return true;
}

static int run_fs_scan(const std::string& dev, const std::string& formats,
                       const std::string& mode, const fs::path& target,
                       const std::optional<fs::path>& log) {
    if (mode == "move" || mode == "remove" || mode == "trash" || mode == "shred") {
        std::cout << "SCAN: --scan supports dummy and copy only "
                     "(mode '" << mode << "' refused)\n";
        return 64;
    }
    std::vector<std::string> fmts;
    {
        std::string s = formats.empty() ? "all" : formats;
        size_t pos = 0;
        while (pos <= s.size()) {
            size_t c = s.find(',', pos);
            std::string tok = fs_norm(s.substr(pos, c == std::string::npos
                                               ? std::string::npos : c - pos));
            if (!tok.empty()) {
                bool known = false;
                for (const char* kf : FS_FORMATS)
                    if (tok == kf) known = true;
                if (!known) {
                    std::string list;
                    for (const char* kf : FS_FORMATS)
                        list += (list.empty() ? "" : ",") + std::string(kf);
                    std::cout << "SCAN: unknown filesystem format '" << tok
                              << "' (known: " << list << ")\n";
                    return 64;
                }
                fmts.push_back(tok);
            }
            if (c == std::string::npos) break;
            pos = c + 1;
        }
    }
    if (fmts.empty() ||
        std::find(fmts.begin(), fmts.end(), "all") != fmts.end()) {
        fmts.clear();
        for (const char* kf : FS_FORMATS)
            if (std::string(kf) != "all") fmts.push_back(kf);
    }
    std::vector<FsPart> parts;
    unsigned long long fsize = 0;
    if (!fs_partitions(dev, parts, fsize)) return 66;
    std::cout << "SCAN: " << dev << "\n";
    for (size_t i = 0; i < parts.size(); ++i) {
        std::cout << "  part " << (i + 1) << ": 0x";
        char h[24];
        std::snprintf(h, sizeof h, "%012llx",
                      (unsigned long long)parts[i].start);
        std::cout << h << " " << parts[i].start << " ";
        if (!parts[i].listed) std::cout << "~";
        std::cout << parts[i].size << " "
                  << (parts[i].fs.empty() ? "unknown" : parts[i].fs)
                  << (parts[i].listed ? " listed" : " lost") << "\n";
    }
    size_t nlist = 0;
    for (auto& p : parts) if (p.listed) ++nlist;
    std::cout << "SCAN: " << parts.size() << " partitions found ("
              << nlist << " listed, " << (parts.size() - nlist)
              << " lost)\n";
    std::ifstream src(dev, std::ios::binary);
    std::vector<RawHit> hits;
    unsigned long long total = 0;
    size_t scanned = 0;
    for (size_t i = 0; i < parts.size(); ++i) {
        const FsPart& p = parts[i];
        if (p.fs.empty() || p.size == 0) continue;
        bool sel = false;
        for (auto& fk : fmts) if (fk == "all" || fk == p.fs) sel = true;
        if (!sel) continue;
        hits.clear();
        raw_scan_range(dev, p.start, p.start + p.size, hits);
        std::cout << "SCAN-PART " << (i + 1) << " " << p.fs << " 0x";
        char h[24];
        std::snprintf(h, sizeof h, "%012llx", (unsigned long long)p.start);
        std::cout << h << " " << p.size << "\n";
        size_t nhits = 0;
        for (auto& hm : hits) {
            if (hm.name.find("filesystem") != std::string::npos ||
                hm.name == "Linux swap area")
                continue;
            bool broken = fs_overlap(parts, i, hm.offset, hm.size);
            ++nhits; ++total;
            if (g_fs_hit_hook)
                g_fs_hit_hook({i + 1, p.fs, hm.offset, hm.size, hm.name,
                               raw_first_ext(hm.exts), hm.exact, broken});
            char oh[32];
            std::snprintf(oh, sizeof oh, "0x%012llx %llu",
                          (unsigned long long)hm.offset,
                          (unsigned long long)hm.offset);
            std::cout << "  hit: " << oh << " " << hm.name << " -> "
                      << raw_first_ext(hm.exts) << " (carve " << hm.size
                      << " bytes" << (hm.exact ? "" : ", capped")
                      << (broken ? ", broken" : "") << ")\n";
            if (mode != "copy" || !src) continue;
            fs::path outdir = target / "FS-CARVE";
            char pd[32];
            std::snprintf(pd, sizeof pd, "p%zu-%012llx", i + 1,
                          (unsigned long long)p.start);
            fs::path base_dir = outdir / pd;
            while (true) {
                std::error_code ec;
                fs::create_directories(base_dir, ec);
                char nm[32];
                std::snprintf(nm, sizeof nm, "%012llx",
                              (unsigned long long)hm.offset);
                fs::path dest = base_dir / (std::string(nm) + "." +
                                            raw_first_ext(hm.exts));
                std::ofstream dst(dest, std::ios::binary);
                src.clear();
                src.seekg((std::streamoff)hm.offset);
                size_t remaining = hm.size;
                char buf[1 << 20];
                bool wok = true;
                while (remaining > 0) {
                    size_t want = std::min(remaining, sizeof buf);
                    src.read(buf, (std::streamsize)want);
                    std::streamsize got = src.gcount();
                    if (got <= 0) break;
                    dst.write(buf, got);
                    if (!dst) { wok = false; break; }
                    remaining -= (size_t)got;
                }
                dst.close();
                if (wok) { base_dir = dest; break; }
                bool oos = errno == ENOSPC;
                if (oos && isatty(0)) {
                    std::cout << "SCAN: out of space at "
                              << base_dir.string() << "\n";
                    std::cout << "SCAN: new target directory "
                                 "(empty = abort): ";
                    std::string newt;
                    std::getline(std::cin, newt);
                    if (newt.empty() || !std::cin) {
                        std::cout << "SCAN: copy aborted by user\n";
                        return 65;
                    }
                    base_dir = fs::path(newt) / "FS-CARVE" / pd;
                    continue;
                }
                std::cout << "SCAN: cannot write " << dest.string() << "\n";
                return 65;
            }
            std::cout << "  carved: " << base_dir.string() << "\n";
            if (log) {
                std::ofstream lf(*log, std::ios::app);
                lf << "{\"action\": \"carved\", \"src\": "
                   << raw_json_quote(dev + "@" + std::to_string(hm.offset))
                   << ", \"dst\": " << raw_json_quote(base_dir.string())
                   << ", \"part\": " << (i + 1);
                if (broken) lf << ", \"broken\": true";
                lf << "}\n";
            }
        }
        ++scanned;
        std::cout << "SCAN-PART " << (i + 1) << ": " << nhits
                  << " signatures found\n";
    }
    std::cout << "SCAN: done, " << total << " signatures in " << scanned
              << " partitions\n";
    return 0;
}

// 7. MODES: DUMMY / COPY / MOVE / REMOVE / TRASH / SHRED (V14 Safe Transport)
// ===========================================================================

static std::string xdg_data_home() {
    const char* x = std::getenv("XDG_DATA_HOME");
    if (x && *x) return x;
    const char* home = std::getenv("HOME");
    return std::string(home ? home : ".") + "/.local/share";
}

static std::string now_iso() {
    std::time_t t = std::time(nullptr);
    char buf[32];
    std::strftime(buf, sizeof buf, "%Y-%m-%dT%H:%M:%S", std::gmtime(&t));
    return buf;
}

static bool move_path(const fs::path& src, const fs::path& dst) {
    std::error_code ec;
    fs::rename(src, dst, ec);
    if (!ec) return true;
    // cross-device fallback: copy + remove
    try {
        fs::copy_file(src, dst, fs::copy_options::overwrite_existing);
        fs::remove(src);
        return true;
    } catch (...) {
        return false;
    }
}

// ===========================================================================
// 8. CORE ENGINE (V6.x heritage: parse -> filter -> resolve -> act)
// ===========================================================================

static const std::map<std::string, std::set<std::string>> TYPE_FILTERS = {
    {"image", {"image"}}, {"video", {"video"}}, {"audio", {"audio"}},
    {"document", {"document", "text"}}, {"doc", {"document", "text"}},
    {"archive", {"archive"}}, {"text", {"text"}}, {"binary", {"binary"}},
};

struct Options {
    std::string mode = "dummy";
    std::string dirs, subdirs, rename, extension, type_filter;
    fs::path target = ".";
    std::vector<std::string> inputs;
    bool recursive = false, hidden = false, follow_links = false;
    std::string replace = "ask";        // ask | always | never
    double pause = 0.0;
    int jobs = 1;
    std::optional<fs::path> log;
    bool cleanup_empty = true;
    std::string lang = "en";
    bool colors = true, icons = true, quiet = false;
};

class Organizer {
public:
    explicit Organizer(const Options& o) : opts_(o), ui_(o.colors, o.icons, o.lang, o.quiet) {
        if (o.log) log_fh_.open(*o.log, std::ios::app);
        scan_hash_keywords();
    }

    int run() {
        auto files = collect();
        if (files.empty()) {
            ui_.say(ui_.T("noinput"));
            return 30;
        }
        ui_.say(ui_.icon("info") + ui_.bold(ui_.T("start")) + " " + ui_.label(opts_.mode) +
                " | " + ui_.T("target") + ": " +
                ui_.path((opts_.target.empty() ? fs::current_path() : opts_.target).string()));
        if (opts_.mode == "dummy") ui_.say(ui_.dim(ui_.T("dry")));
        if (opts_.jobs > 1 && opts_.mode != "dummy") {
            run_threaded(files);
        } else {
            for (auto& f : files) process(f);
        }
        summary();
        return counters_["failed"] ? 50 : 0;
    }

private:
    // ---- keyword requirements discovered from the specs ---------------------
    void scan_hash_keywords() {
        for (const std::string* spec :
             {&opts_.dirs, &opts_.subdirs, &opts_.rename, &opts_.extension}) {
            std::string s = *spec;
            size_t pos = 0;
            while (pos < s.size()) {
                size_t a = s.find_first_not_of("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789+-_", pos);
                if (a == std::string::npos) a = s.size();
                if (a > pos) {
                    std::string kw = s.substr(pos, a - pos);
                    if (HASH_ALGOS.count(kw)) wanted_hashes_.insert(kw);
                }
                pos = a + 1;
            }
        }
    }

    // ---- input collection ---------------------------------------------------
    std::vector<fs::path> collect() {
        std::vector<fs::path> found;
        for (const auto& item : opts_.inputs) {
            fs::path p(item);
            std::error_code ec;
            if (!fs::exists(p, ec) && !fs::is_symlink(p)) {
                ui_.say(ui_.icon("warn") + ui_.err(ui_.T("notfound")) + " " + ui_.path(p.string()));
                continue;
            }
            if (fs::is_directory(p, ec)) {
                if (opts_.recursive) {
                    std::vector<fs::path> stack;
                    stack.push_back(p);
                    while (!stack.empty()) {
                        fs::path dir = stack.back();
                        stack.pop_back();
                        std::error_code ec2;
                        for (auto it = fs::directory_iterator(dir,
                                 fs::directory_options::skip_permission_denied, ec2);
                             it != fs::directory_iterator(); it.increment(ec2)) {
                            if (ec2) break;
                            const auto& entry = *it;
                            std::string nm = entry.path().filename().string();
                            if (!opts_.hidden && !nm.empty() && nm[0] == '.') continue;
                            if (entry.is_directory(ec2)) {
                                if (opts_.follow_links || !entry.is_symlink(ec2))
                                    stack.push_back(entry.path());
                            } else {
                                found.push_back(entry.path());
                            }
                        }
                    }
                } else {
                    std::vector<fs::path> entries;
                    for (auto& e : fs::directory_iterator(p))
                        if (e.is_regular_file()) entries.push_back(e.path());
                    std::sort(entries.begin(), entries.end());
                    for (auto& e : entries) {
                        std::string nm = e.filename().string();
                        if (!opts_.hidden && !nm.empty() && nm[0] == '.') continue;
                        found.push_back(e);
                    }
                }
            } else {
                found.push_back(p);
            }
        }
        std::set<std::string> seen;
        std::vector<fs::path> ordered;
        for (auto& f : found) {
            std::string key = f.string();
            if (seen.insert(key).second) ordered.push_back(f);
        }
        return ordered;
    }

    // ---- type filter ---------------------------------------------------------
    bool matches_filter(const FileFacts& facts) {
        if (opts_.type_filter.empty()) return true;
        std::set<std::string> allowed;
        std::string s = opts_.type_filter;
        size_t start = 0;
        while (start <= s.size()) {
            size_t comma = s.find(',', start);
            std::string part = to_lower(trim(s.substr(start,
                comma == std::string::npos ? std::string::npos : comma - start)));
            auto it = TYPE_FILTERS.find(part);
            if (it != TYPE_FILTERS.end())
                allowed.insert(it->second.begin(), it->second.end());
            if (comma == std::string::npos) break;
            start = comma + 1;
        }
        return allowed.empty() ? true : allowed.count(facts.mime_main) > 0;
    }
    static std::string trim(const std::string& s) {
        size_t a = s.find_first_not_of(" \t\r\n");
        if (a == std::string::npos) return "";
        size_t b = s.find_last_not_of(" \t\r\n");
        return s.substr(a, b - a + 1);
    }

    // ---- collision handling (V6.4 interactive) --------------------------------
    std::string resolve_collision(const fs::path& src, const fs::path& dst) {
        std::error_code ec;
        if (!fs::exists(dst, ec)) return "proceed";
        if (replace_all_ || opts_.replace == "always") return "replace";
        if (skip_all_ || opts_.replace == "never") return "skip";
        if (!isatty(STDIN_FILENO)) return "skip";
        ui_.say(ui_.icon("warn") + ui_.warn("collision: ") + ui_.path(src.string()) +
                " -> " + ui_.path(dst.string()));
        std::cout << ui_.T("confirm");
        std::cout.flush();
        std::string ans;
        std::getline(std::cin, ans);
        for (auto& c : ans) c = (char)std::tolower((unsigned char)c);
        ans = trim(ans);
        if (!ans.empty()) {
            char c0 = ans[0];
            if (c0 == 'r' || c0 == 'e' || c0 == 'd') {
                if (ans.find('l') != std::string::npos || ans.find('t') != std::string::npos)
                    replace_all_ = true;
                return "replace";
            }
            if (c0 == 's' || c0 == 'o' || c0 == 'i' || c0 == 'a' || c0 == 'u') {
                if (ans.find('l') != std::string::npos || ans.find('t') != std::string::npos)
                    skip_all_ = true;
                return "skip";
            }
        }
        return "cancel";
    }

    // ---- action log (V15 undo heritage) ----------------------------------------
    void log_action(const std::string& action, const std::string& k1, const std::string& v1,
                    const std::string& k2 = "", const std::string& v2 = "") {
        if (!log_fh_.is_open()) return;
        std::lock_guard<std::mutex> lock(log_mutex_);
        log_fh_ << "{\"time\": \"" << now_iso() << "\", \"action\": \"" << action
                << "\", \"" << k1 << "\": " << json_str(v1);
        if (!k2.empty()) log_fh_ << ", \"" << k2 << "\": " << json_str(v2);
        log_fh_ << "}\n";
        log_fh_.flush();
    }
    static std::string json_str(const std::string& s) {
        std::string out = "\"";
        for (char c : s) {
            if (c == '"' || c == '\\') out += '\\';
            if ((unsigned char)c < 0x20) { char b[8]; std::snprintf(b, 8, "\\u%04x", c); out += b; }
            else out += c;
        }
        return out + "\"";
    }

    // ---- per-file pipeline --------------------------------------------------------
    void process(const fs::path& path) {
        try {
            std::error_code ec;
            if (!fs::is_regular_file(path, ec)) {
                if (!(fs::is_symlink(path) && opts_.follow_links)) return;
            }
            FileFacts facts;
            facts.path = path;
            gather_facts(facts, wanted_hashes_);
            if (!matches_filter(facts)) {
                bump("filtered");
                ui_.say(ui_.icon("skip") + ui_.dim(ui_.T("filtered")) + " " + ui_.path(path.string()));
                return;
            }
            fs::path target_root = opts_.target.empty() ? fs::current_path() : opts_.target;
            std::string tag = random_tag();
            std::string rel_dir = TemplateEngine(opts_.dirs, "path", tag).resolve(facts);
            std::string rel_sub = TemplateEngine(opts_.subdirs, "path", tag).resolve(facts);
            std::string new_name = TemplateEngine(opts_.rename, "name", tag).resolve(facts);
            std::string new_ext = TemplateEngine(opts_.extension, "extension", tag).resolve(facts);

            fs::path destination;
            if (opts_.mode == "remove" || opts_.mode == "trash" || opts_.mode == "shred") {
                destination = path;
            } else {
                fs::path folder = target_root;
                if (!rel_dir.empty()) folder /= rel_dir;
                if (!rel_sub.empty()) folder /= rel_sub;
                if (opts_.mode == "dummy") {
                    std::string name_disp = !opts_.rename.empty() ? new_name : facts.name();
                    std::string ext_disp = !opts_.extension.empty()
                        ? ("." + new_ext) : (facts.ext().empty() ? "" : "." + facts.ext());
                    destination = folder / (name_disp + (opts_.extension.empty() ? "" : ext_disp));
                } else {
                    std::string stem = new_name.empty() ? facts.stem() : new_name;
                    std::string ext = !new_ext.empty() ? ("." + new_ext)
                        : (facts.ext().empty() ? "" : "." + facts.ext());
                    destination = folder / (stem + ext);
                }
            }
            act(path, facts, destination);
            if (opts_.pause > 0)
                std::this_thread::sleep_for(
                    std::chrono::milliseconds((long long)(opts_.pause * 1000)));
        } catch (const std::exception& exc) {
            bump("failed");
            ui_.say(ui_.icon("error") + ui_.err("ERROR: ") + exc.what() +
                    " [" + ui_.path(path.string()) + "]");
        }
    }

    void act(const fs::path& path, FileFacts& facts, const fs::path& destination) {
        (void)facts;   // kept for pipeline parity; act() uses path/destination only
        std::error_code ec;
        if (opts_.mode == "dummy") {
            ui_.say(ui_.icon("info") + ui_.dim(ui_.T("dry")) + " " + ui_.path(path.string()) +
                    " -> " + ui_.path(destination.string()));
            return;
        }
        if (opts_.mode == "remove") {
            if (fs::remove(path, ec) && !ec) {
                bump("removed");
            } else {
                bump("failed");
            }
            log_action("removed", "src", path.string());
            ui_.say(ui_.icon("remove") + ui_.err(ui_.T("removed")) + " " + ui_.path(path.string()));
            if (opts_.cleanup_empty) cleanup_empty(path.parent_path());
            return;
        }
        if (opts_.mode == "trash") {
            freedesktop_trash(path);
            bump("trashed");
            log_action("trashed", "src", path.string());
            return;
        }
        if (opts_.mode == "shred") {
            shred_file(path);
            bump("shredded");
            log_action("shredded", "src", path.string());
            return;
        }
        std::string decision = resolve_collision(path, destination);
        if (decision == "skip" || decision == "cancel") { bump("skipped"); return; }
        fs::create_directories(destination.parent_path(), ec);
        if (decision == "replace" && fs::exists(destination, ec)) fs::remove(destination, ec);
        if (opts_.mode == "copy") {
            fs::copy_file(path, destination, fs::copy_options::overwrite_existing, ec);
            if (ec) { bump("failed"); return; }
            // preserve mtime like shutil.copy2
            fs::last_write_time(destination, fs::last_write_time(path), ec2_);
            bump("copied");
            log_action("copied", "src", path.string(), "dst", destination.string());
            ui_.say(ui_.icon("copy") + ui_.ok(ui_.T("copied")) + " " + ui_.path(path.string()) +
                    " -> " + ui_.path(destination.string()));
        } else if (opts_.mode == "move") {
            if (!move_path(path, destination)) { bump("failed"); return; }
            bump("moved");
            log_action("moved", "src", path.string(), "dst", destination.string());
            ui_.say(ui_.icon("move") + ui_.ok(ui_.T("moved")) + " " + ui_.path(path.string()) +
                    " -> " + ui_.path(destination.string()));
            if (opts_.cleanup_empty) cleanup_empty(path.parent_path());
        }
    }

    void freedesktop_trash(const fs::path& path) {
        fs::path trash_root = fs::path(xdg_data_home()) / "Trash";
        fs::path files_dir = trash_root / "files";
        fs::path info_dir = trash_root / "info";
        fs::create_directories(files_dir);
        fs::create_directories(info_dir);
        fs::path dest = files_dir / path.filename();
        int i = 1;
        std::error_code ec;
        while (fs::exists(dest, ec)) {
            dest = files_dir / (facts_stem(path) + "-" + std::to_string(i) + path.extension().string());
            ++i;
        }
        move_path(path, dest);
        std::string deletion;
        {
            std::time_t t = std::time(nullptr);
            char buf[32];
            std::strftime(buf, sizeof buf, "%Y-%m-%dT%H:%M:%S", std::localtime(&t));
            deletion = buf;
        }
        std::ofstream info(info_dir / (dest.filename().string() + ".trashinfo"));
        info << "[Trash Info]\nPath=" << fs::absolute(path).string()
             << "\nDeletionDate=" << deletion << "\n";
        ui_.say(ui_.icon("remove") + ui_.ok(ui_.T("trashed")) + " " + ui_.path(path.string()) +
                " -> " + ui_.path(dest.string()));
    }
    static std::string facts_stem(const fs::path& p) {
        std::string n = p.filename().string();
        size_t dot = n.find_last_of('.');
        return (dot == std::string::npos || dot == 0) ? n : n.substr(0, dot);
    }

    void shred_file(const fs::path& path) {
        std::error_code ec;
        auto size = fs::file_size(path, ec);
        if (ec) return;
        int fd = ::open(path.c_str(), O_RDWR);
        if (fd < 0) return;
        std::mt19937_64 rng((std::random_device())());
        const int PASSES = 3;
        std::string buf(1 << 20, '\0');
        for (int pass = 0; pass < PASSES; ++pass) {
            off_t done = 0;
            while (done < (off_t)size) {
                size_t chunk = (size_t)std::min<off_t>((off_t)buf.size(), (off_t)size - done);
                for (size_t i = 0; i < chunk; ++i)
                    buf[i] = (char)(rng() & 0xFF);
                if (::pwrite(fd, buf.data(), chunk, done) != (ssize_t)chunk) break;
                done += chunk;
            }
            ::fsync(fd);
        }
        ::close(fd);
        fs::remove(path, ec);
        ui_.say(ui_.icon("remove") + ui_.err(ui_.T("shredded")) + " " + ui_.path(path.string()));
    }

    void cleanup_empty(const fs::path& folder) {
        std::error_code ec;
        if (!fs::is_directory(folder, ec)) return;
        fs::directory_iterator it(folder, fs::directory_options::skip_permission_denied, ec);
        if (ec) return;
        if (it != fs::directory_iterator()) return;    // not empty
        fs::remove(folder, ec);
        if (!ec)
            ui_.say(ui_.icon("clean") + ui_.info(ui_.T("empty")) + " " + ui_.path(folder.string()));
    }

    void bump(const std::string& k) {
        std::lock_guard<std::mutex> lock(counters_mutex_);
        ++counters_[k];
    }

    void run_threaded(const std::vector<fs::path>& files) {
        std::vector<std::thread> pool;
        std::queue<fs::path> queue;
        for (const auto& f : files) queue.push(f);
        std::mutex qm;
        int n = std::max(1, opts_.jobs);
        for (int i = 0; i < n; ++i) {
            pool.emplace_back([&] {
                while (true) {
                    fs::path p;
                    {
                        std::lock_guard<std::mutex> lock(qm);
                        if (queue.empty()) return;
                        p = queue.front();
                        queue.pop();
                    }
                    process(p);
                }
            });
        }
        for (auto& t : pool) t.join();
    }

    void summary() {
        std::string parts;
        for (const auto& k : {"copied", "moved", "removed", "trashed", "shredded",
                              "skipped", "failed"}) {
            long v = counters_[k];
            if (!v) continue;
            if (!parts.empty()) parts += " | ";
            parts += std::to_string(v) + " " + ui_.T(k);
        }
        ui_.say(ui_.icon("done") + ui_.bold(ui_.T("done")) + ": " +
                (parts.empty() ? "0 " + ui_.T("files") : parts));
    }

    std::string random_tag() {
        static std::mt19937_64 rng{(unsigned)std::random_device()()};
        char buf[16];
        std::snprintf(buf, sizeof buf, "%08x%08x",
                      (unsigned)(rng() & 0xFFFFFFFFu), (unsigned)(rng() >> 32));
        return buf;
    }

    Options opts_;
    UI ui_;
    std::map<std::string, long> counters_ = {{"copied", 0}, {"moved", 0}, {"removed", 0},
                                             {"trashed", 0}, {"shredded", 0}, {"skipped", 0},
                                             {"failed", 0}, {"filtered", 0}};
    std::ofstream log_fh_;
    std::set<std::string> wanted_hashes_;
    std::mutex counters_mutex_, log_mutex_;
    bool skip_all_ = false, replace_all_ = false;
    std::error_code ec2_;
};

// ===========================================================================
// 9. UNDO (V15 heritage: reverse a JSONL action log)
// ===========================================================================

static std::string json_field(const std::string& line, const std::string& key) {
    std::string pat = "\"" + key + "\": \"";
    size_t a = line.find(pat);
    if (a == std::string::npos) return "";
    a += pat.size();
    std::string out;
    for (size_t i = a; i < line.size(); ++i) {
        if (line[i] == '\\' && i + 1 < line.size()) { out += line[++i]; continue; }
        if (line[i] == '"') break;
        out += line[i];
    }
    return out;
}

static std::string trim_ws(const std::string& s) {
    size_t a = s.find_first_not_of(" \t\r\n");
    if (a == std::string::npos) return "";
    size_t b = s.find_last_not_of(" \t\r\n");
    return s.substr(a, b - a + 1);
}

static int undo_log(const fs::path& logfile) {
    std::ifstream f(logfile);
    if (!f) { std::cout << "cannot open log: " << logfile << "\n"; return 1; }
    std::vector<std::string> lines;
    std::string line;
    while (std::getline(f, line)) lines.push_back(line);
    int undone = 0;
    for (auto it = lines.rbegin(); it != lines.rend(); ++it) {
        if (trim_ws(*it).empty()) continue;
        std::string a = json_field(*it, "action");
        std::string src = json_field(*it, "src");
        std::string dst = json_field(*it, "dst");
        try {
            if (a == "moved" && !dst.empty() && fs::exists(dst)) {
                fs::create_directories(fs::path(src).parent_path());
                move_path(dst, src);
                ++undone;
            } else if (a == "copied" && !dst.empty() && fs::exists(dst)) {
                fs::remove(dst);
                ++undone;
            } else if (a == "carved" && !dst.empty() && fs::exists(dst)) {
                fs::remove(dst);           // carved fragments never go back
                ++undone;
            } else if (a == "trashed") {
                fs::path cand = fs::path(xdg_data_home()) / "Trash/files" /
                                fs::path(src).filename();
                if (fs::exists(cand)) { move_path(cand, src); ++undone; }
            } else if (a == "removed") {
                std::cout << "cannot restore removed file: " << src << "\n";
            } else if (a == "shredded") {
                std::cout << "cannot restore shredded file: " << src << "\n";
            }
        } catch (const std::exception& exc) {
            std::cout << "undo failed: " << exc.what() << "\n";
        }
    }
    std::cout << "Undone: " << undone << "\n";
    return 0;
}

// ===========================================================================
// 10. SELF-TEST (mirrors Sort.py's 23 checks)
// ===========================================================================

static std::string st_q(const std::string& s) {
    std::string out = "\"";
    for (char c : s) {
        if (c == '"' || c == '\\') out += '\\';
        if ((unsigned char)c < 0x20) { char b[8]; std::snprintf(b, 8, "\\u%04x", c); out += b; }
        else out += c;
    }
    return out + "\"";
}

static void st_write(const fs::path& p, const std::string& bytes) {
    std::ofstream f(p, std::ios::binary);
    f.write(bytes.data(), (std::streamsize)bytes.size());
}

static std::string be16(unsigned v) { std::string s; s += (char)(v >> 8); s += (char)(v & 0xFF); return s; }
static std::string be32(unsigned v) {
    std::string s;
    s += (char)((v >> 24) & 0xFF); s += (char)((v >> 16) & 0xFF);
    s += (char)((v >> 8) & 0xFF);  s += (char)(v & 0xFF);
    return s;
}
static std::string le16(unsigned v) { std::string s; s += (char)(v & 0xFF); s += (char)(v >> 8); return s; }
static std::string le24(unsigned v) {
    std::string s;
    s += (char)(v & 0xFF); s += (char)((v >> 8) & 0xFF); s += (char)((v >> 16) & 0xFF);
    return s;
}

static int run_self_test() {
    char tmpl[] = "/tmp/sort-cpp-selftest-XXXXXX";
    std::string root_s = mkdtemp(tmpl) ? tmpl : "/tmp/sort-cpp-selftest";
    fs::path root(root_s);
    int passed = 0, failed = 0;
    auto check = [&](const std::string& name, bool cond, const std::string& extra = "") {
        if (cond) { ++passed; std::cout << "[PASS] " << name << " " << extra << "\n"; }
        else      { ++failed; std::cout << "[FAIL] " << name << " " << extra << "\n"; }
    };

    fs::path png = root / "a.png";
    st_write(png, "\x89PNG\r\n\x1a\n" "\x00\x00\x00\x0DIHDR" + be32(640) + be32(480) + "\x08\x06\x00\x00\x00");
    fs::path gif = root / "b.gif";
    st_write(gif, "GIF89a" + le16(320) + le16(200));
    fs::path jpeg = root / "c.jpg";
    // JPEG SOF0 stores height then width, big-endian
    st_write(jpeg, "\xFF\xD8\xFF\xE0" "\x00\x10JFIF\x00\x01\x02\x00\x00\x01\x00\x01\x00\x00"
                    "\xFF\xC0\x00\x11\x08" + be16(600) + be16(800) + "\x03\x01\x22\x00");
    fs::path webp = root / "d.webp";
    st_write(webp, "RIFF\x30\x00\x00\x00" "WEBPVP8X" "\x0A\x00\x00\x00"
                    "\x00\x00\x00\x00" + le24(1919) + le24(1079));
    fs::path pdf = root / "doc.pdf";
    st_write(pdf, "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n1 0 obj\n<<>>\nendobj\ntrailer<<>>\n%%EOF");
    fs::path zipp = root / "arc.zip";
    st_write(zipp, "PK\x03\x04" "\x14\x00\x00\x00\x08\x00" + std::string(64, '\0'));
    fs::path mp3 = root / "song.mp3";
    st_write(mp3, "ID3\x04\x00\x00\x00\x00\x00\x00" "\xFF\xFB\x90\x44" + std::string(256, '\0'));
    fs::path jsn = root / "data.json";
    st_write(jsn, "{\"a\": 1}\n");
    fs::path shellf = root / "run.sh";
    st_write(shellf, "#!/bin/sh\necho hi\n");
    fs::path txtf = root / "note.txt";
    st_write(txtf, "just text\n");

    // MIME checks
    std::vector<std::pair<fs::path, std::pair<std::string, std::string>>> mimes = {
        {png, {"image", "png"}}, {gif, {"image", "gif"}}, {jpeg, {"image", "jpeg"}},
        {webp, {"image", "webp"}}, {pdf, {"document", "pdf"}}, {zipp, {"archive", "zip"}},
        {mp3, {"audio", "mpeg"}}, {jsn, {"text", "json"}}, {shellf, {"text", "x-shellscript"}},
        {txtf, {"text", "plain"}},
    };
    for (auto& t : mimes) {
        auto got = sniff_mime(t.first);
        check("mime " + t.first.filename().string(),
              got.first == t.second.first && got.second == t.second.second,
              "got=" + got.first + "/" + got.second);
    }

    // dimensions
    auto d1 = image_dimensions(png);
    check("png dims", d1 && d1->first == 640 && d1->second == 480,
          d1 ? std::to_string(d1->first) + "x" + std::to_string(d1->second) : "none");
    auto d2 = image_dimensions(gif);
    check("gif dims", d2 && d2->first == 320 && d2->second == 200,
          d2 ? std::to_string(d2->first) + "x" + std::to_string(d2->second) : "none");
    auto d3 = image_dimensions(jpeg);
    check("jpeg dims", d3 && d3->first == 800 && d3->second == 600,
          d3 ? std::to_string(d3->first) + "x" + std::to_string(d3->second) : "none");
    auto d4 = image_dimensions(webp);
    check("webp dims", d4 && d4->first == 1920 && d4->second == 1080,
          d4 ? std::to_string(d4->first) + "x" + std::to_string(d4->second) : "none");

    // hashes
    check("md5", hash_file(png, "md5sum").size() == 32);
    check("sha256", hash_file(png, "sha256sum").size() == 64);

    // template engine
    FileFacts facts;
    facts.path = png;
    gather_facts(facts, {"sha256sum"});
    std::string got = TemplateEngine("mime-main/year+month/size", "path").resolve(facts);
    std::regex rx("^IMAGE/\\d{4}-\\d{2}/\\d+[KMGT]?B$");
    check("template path", std::regex_search(got, rx), got);
    TemplateEngine eng3("missing|mime-main", "extension");
    check("fallback", eng3.segment(facts, "missing|mime-main") == "image",
          eng3.segment(facts, "missing|mime-main"));
    TemplateEngine eng4("raw:filename", "name");
    check("raw prefix", eng4.segment(facts, "raw:filename") == "a.png",
          eng4.segment(facts, "raw:filename"));
    TemplateEngine eng5("year+month+day/pixel-format", "path");
    std::string px = eng5.resolve(facts);
    check("pixel-format", std::count(px.begin(), px.end(), '/') == 1, px);

    // organizer smoke test (copy with threads)
    fs::path src_dir = root / "in";
    fs::create_directories(src_dir);
    std::string png_data, pdf_data;
    { std::ifstream f(png, std::ios::binary); std::ostringstream ss; ss << f.rdbuf(); png_data = ss.str(); }
    { std::ifstream f(pdf, std::ios::binary); std::ostringstream ss; ss << f.rdbuf(); pdf_data = ss.str(); }
    st_write(src_dir / "x.png", png_data);
    st_write(src_dir / "y.pdf", pdf_data);
    st_write(src_dir / "z.pdf", pdf_data);
    fs::path target = root / "out";
    Options opts;
    opts.mode = "copy"; opts.dirs = "mime-main"; opts.type_filter = "image";
    opts.target = target; opts.inputs = {src_dir.string()};
    opts.recursive = true; opts.jobs = 2; opts.quiet = true; opts.replace = "always";
    int rc = Organizer(opts).run();
    check("copy run", rc == 0);
    check("copy result", fs::exists(target / "IMAGE" / "x.png"));

    // undo smoke test
    fs::path logf = root / "actions.jsonl";
    {
        std::ofstream lf(logf);
        lf << "{\"action\": \"copied\", \"src\": " << st_q((src_dir / "x.png").string())
           << ", \"dst\": " << st_q((target / "IMAGE" / "x.png").string()) << "}\n";
    }
    bool before = fs::exists(target / "IMAGE" / "x.png");
    undo_log(logf);
    check("undo copy", before && !fs::exists(target / "IMAGE" / "x.png"));

    std::cout << "\nPassed: " << passed << "  Failed: " << failed << "\n";
    std::error_code ec;
    fs::remove_all(root, ec);
    return failed ? 2 : 0;
}

// ===========================================================================
// 11. EDITION GATE + CLI (mirrors Sort.py's era model)
// ===========================================================================

static const std::vector<std::string> EDITION_MODES = {
    "copy", "dummy", "move", "remove", "shred", "trash"};
static const std::vector<std::string> EDITION_FLAGS = {
    "--dirs", "--extension", "--hidden", "--jobs", "--lang", "--links", "--log",
    "--magic", "--no-colors", "--pause", "--quiet", "--recursive", "--rename",
    "--replace", "--scan", "--scan-raw", "--subdirs", "--target", "--type", "--undo"};
static const std::vector<std::string> EDITION_KEYWORDS = {
    "accessed", "created", "day", "exif-date", "exif-datetime", "exif-make",
    "exif-model", "exif-orientation", "extension", "format", "format+size",
    "id3-album", "id3-artist", "id3-genre", "id3-title", "id3-track", "id3-year",
    "md5sum", "mime", "mime-main", "mime-sub", "modified", "month", "name",
    "random", "sha1sum", "sha224sum", "sha256sum", "sha384sum", "sha512sum",
    "size", "size+format", "title", "year", "year+month", "year+month+day"};
static const std::vector<std::string> CANONICAL_KEYWORDS = {
    "year", "month", "day", "year+month", "year+month+day", "created",
    "created-date", "created-time", "modified", "modified-date", "modified-time",
    "accessed", "accessed-date", "accessed-time", "mime", "mime-main", "mime-sub",
    "type", "extension", "ext", "ext-lower", "ext-upper", "filename", "name",
    "basename", "stem", "original", "size", "format", "size+format", "format+size",
    "pixel-size", "resolution", "pixel-format", "md5sum", "sha1sum", "sha224sum",
    "sha256sum", "sha384sum", "sha512sum", "random",
    "exif-date", "exif-datetime", "exif-make", "exif-model", "exif-orientation",
    "id3-album", "id3-artist", "id3-genre", "id3-title", "id3-track", "id3-year", "title"};

static const char* ERA_USAGE =
    "Sort-V21.cpp - standalone C++ edition of Sort-V21.sh\n"
    "(C++17 only; no external commands, no dependencies required.)\n"
    "\n"
    "USAGE\n"
    "    Sort-V21.cpp [OPTIONS] FILES...\n"
    "\n"
    "MODES (--mode=...)\n"
    "    copy, dummy, move, remove, shred, trash\n"
    "\n"
    "OPTIONS\n"
    "    --dirs, --extension, --hidden, --jobs, --lang, --links, --log, --magic, --mode, --no-colors, --pause, --quiet, --recursive, --rename, --replace, --scan, --scan-raw, --subdirs, --target, --type, --undo, inputs\n"
    "    --magic             print a magic-number detection report (237 signature formats) and exit\n    --scan-raw DEVICE   scan a raw device or disk image (237 signatures); dry-run report, --mode=copy carves fragments\n    --scan FSFORMAT     scan a raw device/image for partitions (MBR/GPT + lost via filesystem signatures), then scan the selected filesystems for files/lost data; FORMATS: all,ntfs,exfat,fat12,fat16,fat32,ext,btrfs,xfs,reiserfs,hfs,swap,luks; dummy reports, copy carves to Target/FS-CARVE (V21)\n"
    "\n"
    "TEMPLATE KEYWORDS (for --dirs / --subdirs/--rename/--extension/--dirs)\n"
    "    accessed, created, day, exif-date, exif-datetime, exif-make, exif-model, exif-orientation, extension, format, format+size, id3-album, id3-artist, id3-genre, id3-title, id3-track, id3-year, md5sum, mime, mime-main, mime-sub, modified, month, name, random, sha1sum, sha224sum, sha256sum, sha384sum, sha512sum, size, size+format, title, year, year+month, year+month+day\n"
    "    (segments join with '/'; unknown words are literal folder text)\n"
    "\n"
    "ALWAYS AVAILABLE\n"
    "    -h / --help          this usage\n"
    "    --self-test          engine self test\n"
    "    --version            version banner\n"
    "\n"
    "OUT OF SCOPE FOR THIS EDITION (stripped; see README.md)\n"
    "    --decompress: archive decompress (--decompress) - stripped; --delete: delete mode - use --mode=remove; --exif: EXIF rename/strip levels (--exif) - stripped; --needed: dependency listing - stripped; --noconfirm: interactive confirm - stripped; --non-interactive: interactive confirm - stripped; --stats: stats mode (--stats) - stripped; --strip: metadata stripping (--strip) - stripped; --title: metadata title rename (--title) - stripped; --verbose: verbose flag - use default output; --version: --version\n";

static int era_error(const std::string& msg) {
    std::cout << "Sort-V21 edition error: " << msg << "\n";
    std::cout << "Allowed here -- modes: ";
    for (size_t i = 0; i < EDITION_MODES.size(); ++i)
        std::cout << (i ? ", " : "") << EDITION_MODES[i];
    std::cout << " | flags: ";
    for (size_t i = 0; i < EDITION_FLAGS.size(); ++i)
        std::cout << (i ? ", " : "") << EDITION_FLAGS[i];
    std::cout << " | keywords: ";
    for (size_t i = 0; i < EDITION_KEYWORDS.size(); ++i)
        std::cout << (i ? ", " : "") << EDITION_KEYWORDS[i];
    std::cout << "\nRun with -h for the full era usage.\n";
    return 64;
}

static void check_template(const std::string& value, const std::string& arg) {
    size_t start = 0;
    while (start <= value.size()) {
        size_t slash = value.find('/', start);
        std::string seg = value.substr(start,
            slash == std::string::npos ? std::string::npos : slash - start);
        size_t sstart = 0;
        while (sstart <= seg.size()) {
            size_t bar = seg.find('|', sstart);
            std::string expr = trim_ws(seg.substr(sstart,
                bar == std::string::npos ? std::string::npos : bar - sstart));
            if (!expr.empty()) {
                // modifiers are not enabled in this edition (mirrors Sort.py)
                std::string kw = to_lower(trim_ws(expr));
                if (std::find(CANONICAL_KEYWORDS.begin(), CANONICAL_KEYWORDS.end(), kw)
                        != CANONICAL_KEYWORDS.end()
                    && std::find(EDITION_KEYWORDS.begin(), EDITION_KEYWORDS.end(), kw)
                        == EDITION_KEYWORDS.end()) {
                    std::exit(era_error("keyword '" + kw + "' is not part of Sort-V21 (argument "
                                        + arg + ")"));
                }
            }
            if (bar == std::string::npos) break;
            sstart = bar + 1;
        }
        if (slash == std::string::npos) break;
        start = slash + 1;
    }
}

static int real_main(const std::vector<std::string>& argv);

static int era_main(const std::vector<std::string>& argv) {
    // --magic (V17.5 heritage): magic-number detection report, then exit
    bool has_magic = false;
    for (auto& a : argv) if (a == "--magic") has_magic = true;
    if (has_magic) {
        std::vector<std::string> inputs;
        for (auto& a : argv) if (a.empty() || a[0] != '-') inputs.push_back(a);
        if (inputs.empty()) { std::cout << "Nothing to inspect.\n"; return 1; }
        for (auto& item : inputs) {
            fs::path p(item);
            std::error_code ec;
            if (fs::is_directory(p, ec)) {
                std::cout << p.string() << " (directory - use --recursive not needed; listing files)\n";
                std::vector<fs::path> children;
                for (auto& e : fs::directory_iterator(p))
                    if (e.is_regular_file()) children.push_back(e.path());
                std::sort(children.begin(), children.end());
                for (auto& c : children) std::cout << magic_report(c) << "\n";
            } else if (fs::exists(p, ec)) {
                std::cout << magic_report(p) << "\n";
            } else {
                std::cout << p.string() << ": not found\n";
            }
        }
        return 0;
    }
    auto allowed = EDITION_FLAGS;
    for (auto& a : argv) {
        if (a == "-h" || a == "--help") { std::cout << ERA_USAGE; return 0; }
        if (a == "--self-test" || a == "--version" || a.empty() || a[0] != '-') continue;
        std::string name = a.substr(0, a.find('='));
        for (auto& c : name) c = (char)std::tolower((unsigned char)c);
        if (name == "--scan-raw") continue;
        if (name == "--scan") continue;
        if (name == "--mode") {
            std::string val;
            if (a.find('=') != std::string::npos) val = to_lower(a.substr(a.find('=') + 1));
            if (!val.empty()
                && std::find(EDITION_MODES.begin(), EDITION_MODES.end(), val) == EDITION_MODES.end())
                return era_error("mode '" + val + "' is not part of Sort-V21");
            continue;
        }
        if (std::find(allowed.begin(), allowed.end(), name) == allowed.end())
            return era_error("option '" + name + "' is not part of Sort-V21");
        if (a.find('=') != std::string::npos
            && (name == "--dirs" || name == "--subdirs" || name == "--rename"
                || name == "--extension"))
            check_template(a.substr(a.find('=') + 1), name);
    }
    return real_main(argv);
}

// ---- option parsing -----------------------------------------------------------

static int real_main(const std::vector<std::string>& argv) {
    Options opts;
    fs::path undo;
    std::string scan_raw;
    std::string scan_formats;
    bool want_self_test = false, want_version = false, want_help = false;
    auto need_val = [&](const std::vector<std::string>& a, size_t& i,
                        const std::string& inline_val) -> std::string {
        if (!inline_val.empty()) return inline_val;
        if (i + 1 >= a.size()) {
            std::cout << "missing value for " << a[i] << "\n";
            std::exit(2);
        }
        return a[++i];
    };
    for (size_t i = 0; i < argv.size(); ++i) {
        const std::string& a = argv[i];
        if (a.empty() || a[0] != '-') { opts.inputs.push_back(a); continue; }
        std::string name = a;
        std::string inline_val;
        size_t eq = a.find('=');
        if (a.rfind("--", 0) == 0 && eq != std::string::npos) {
            name = a.substr(0, eq);
            inline_val = a.substr(eq + 1);
        }
        if (name == "-h" || name == "--help") want_help = true;
        else if (name == "--version") want_version = true;
        else if (name == "--self-test") want_self_test = true;
        else if (name == "--mode") opts.mode = need_val(argv, i, inline_val);
        else if (name == "--target" || name == "-t") opts.target = need_val(argv, i, inline_val);
        else if (name == "--dirs") opts.dirs = need_val(argv, i, inline_val);
        else if (name == "--subdirs") opts.subdirs = need_val(argv, i, inline_val);
        else if (name == "--rename") opts.rename = need_val(argv, i, inline_val);
        else if (name == "--extension") opts.extension = need_val(argv, i, inline_val);
        else if (name == "--type") opts.type_filter = need_val(argv, i, inline_val);
        else if (name == "--recursive") opts.recursive = true;
        else if (name == "--hidden") opts.hidden = true;
        else if (name == "--links") opts.follow_links = true;
        else if (name == "--replace") opts.replace = need_val(argv, i, inline_val);
        else if (name == "--pause") opts.pause = std::stod(need_val(argv, i, inline_val));
        else if (name == "--jobs") opts.jobs = std::max(1, std::stoi(need_val(argv, i, inline_val)));
        else if (name == "--log") opts.log = need_val(argv, i, inline_val);
        else if (name == "--undo") undo = need_val(argv, i, inline_val);
        else if (name == "--scan-raw") scan_raw = need_val(argv, i, inline_val);
        else if (name == "--scan") scan_formats = need_val(argv, i, inline_val);
        else if (name == "--no-cleanup") opts.cleanup_empty = false;
        else if (name == "--no-colors") opts.colors = false;
        else if (name == "--no-icons") opts.icons = false;
        else if (name == "--quiet") opts.quiet = true;
        else if (name == "--lang") opts.lang = need_val(argv, i, inline_val);
        else { std::cout << "unknown option: " << name << "\n"; return 64; }
    }
    if (want_version) {
        std::cout << "Sort.cpp cpp-21 (C++17 port of the Sort.sh V1.0-V21 lineage)\n";
        return 0;
    }
    if (want_self_test) return run_self_test();
    if (want_help) { std::cout << ERA_USAGE; return 0; }
    if (!undo.empty()) return undo_log(undo);
    if (!scan_raw.empty())
        return run_raw_scan(scan_raw, opts.mode, opts.target, opts.log);
    if (!scan_formats.empty()) {
        if (opts.inputs.empty()) {
            std::cout << "SCAN: --scan needs a device or image path\n";
            return 64;
        }
        return run_fs_scan(opts.inputs[0], scan_formats, opts.mode,
                           opts.target, opts.log);
    }
    if (opts.inputs.empty()) { std::cout << ERA_USAGE; return 0; }
    return Organizer(opts).run();
}

int main(int argc, char** argv) {
    std::vector<std::string> args(argv + 1, argv + argc);
    try {
        return era_main(args);
    } catch (const std::exception& exc) {
        std::cerr << "Sort.cpp: " << exc.what() << "\n";
        return 70;
    }
}
