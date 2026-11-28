Get_SHA256Sum() { sha256sum -b "$1" | cut -d' ' -f1; }
