def undo_log(logfile: Path) -> int:
    undone = 0
    for line in reversed(logfile.read_text(encoding="utf-8").splitlines()):
        if not line.strip():
            continue
        rec = json.loads(line)
        a = rec["action"]
        src, dst = rec.get("src", ""), rec.get("dst", "")
        try:
            if a == "moved" and dst and Path(dst).exists():
                Path(dst).parent.mkdir(parents=True, exist_ok=True)
                shutil.move(dst, src)
                undone += 1
            elif a == "copied" and dst and Path(dst).exists():
                Path(dst).unlink()
                undone += 1
            elif a == "trashed":
                trash_files = Path(os.environ.get(
                    "XDG_DATA_HOME", Path.home() / ".local/share")) / "Trash/files"
                cand = trash_files / Path(src).name
                if cand.exists():
                    shutil.move(str(cand), src)
                    undone += 1
            elif a == "removed":
                print(f"cannot restore removed file: {src}")
            elif a == "shredded":
                print(f"cannot restore shredded file: {src}")
        except (OSError, shutil.Error) as exc:
            print(f"undo failed: {exc}")
    print(f"Undone: {undone}")
    return 0
