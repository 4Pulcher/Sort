Get_MD5Sum() { md5sum -b "$1" | cut -d' ' -f1; }
