def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="Sort.py",
        description="Media-Intelligent File Organizer - "
                    "Python port of the Sort.sh lineage.",
        epilog=MANPAGE,
        formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("inputs", nargs="*", help="files or directories to organize")
    p.add_argument("--mode", default="dummy",
                   choices=["dummy", "copy", "move", "remove", "trash", "shred"],
                   help="operation mode (default: dummy = dry run)")
    p.add_argument("--target", "-t", default=".", help="destination root")
    p.add_argument("--dirs", default="", help="template for the main folders")
    p.add_argument("--subdirs", default="", help="template for sub folders")
    p.add_argument("--rename", default="", help="template for the new file name")
    p.add_argument("--extension", default="",
                   help="template for the new extension")
    p.add_argument("--type", dest="type_filter", default="",
                   help="comma list: image,video,audio,document,archive,text,binary")
    p.add_argument("--recursive", action="store_true",
                   help="descend into directories")
    p.add_argument("--hidden", action="store_true", help="include dotfiles")
    p.add_argument("--links", action="store_true",
                   help="follow symbolic links")
    p.add_argument("--replace", default="ask",
                   choices=["ask", "always", "never"],
                   help="collision handling")
    p.add_argument("--pause", type=float, default=0.0,
                   help="seconds to pause between files")
    p.add_argument("--jobs", type=int, default=1,
                   help="parallel workers (V12)")
    p.add_argument("--log", default=None, help="JSONL action log (V15)")
    p.add_argument("--scan-raw", default=None, metavar="DEVICE",
                   help="scan a raw device/disk image with the 237-signature "
                        "engine; dummy reports, copy carves to Target/RAW-CARVE (V20)")
    p.add_argument("--undo", default=None,
                   help="revert a JSONL action log (V15)")
    p.add_argument("--no-cleanup", dest="cleanup_empty", action="store_false",
                   help="keep directories left empty by move/remove")
    p.add_argument("--lang", default="en", choices=sorted(TRANSLATIONS),
                   help="UI language")
    p.add_argument("--no-colors", dest="colors", action="store_false")
    p.add_argument("--no-icons", dest="icons", action="store_false")
    p.add_argument("--quiet", action="store_true")
    p.add_argument("--version", action="version",
                   version=f"Sort.py {__version__} ({LINEAGE_NOTE})")
    p.add_argument("--self-test", action="store_true",
                   help="run the built-in test suite")
    return p
