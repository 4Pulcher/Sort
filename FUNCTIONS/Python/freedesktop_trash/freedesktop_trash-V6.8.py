def freedesktop_trash(path: Path, ui: UI) -> str:
    """Move a file into the XDG trash with a .trashinfo entry (stdlib only)."""
    trash_root = Path(os.environ.get("XDG_DATA_HOME",
                                     Path.home() / ".local/share")) / "Trash"
    files_dir = trash_root / "files"
    info_dir = trash_root / "info"
    files_dir.mkdir(parents=True, exist_ok=True)
    info_dir.mkdir(parents=True, exist_ok=True)
    dest = files_dir / path.name
    i = 1
    while dest.exists():
        dest = files_dir / f"{path.stem}-{i}{path.suffix}"
        i += 1
    shutil.move(str(path), str(dest))
    deletion = datetime.datetime.now().strftime("%Y-%m-%dT%H:%M:%S")
    info = f"[Trash Info]\nPath={path.resolve()}\nDeletionDate={deletion}\n"
    (info_dir / f"{dest.name}.trashinfo").write_text(info, encoding="utf-8")
    ui.say(f"{ui.icon('remove')}{ui.ok(ui.T('trashed'))} "
           f"{ui.path(str(path))} -> {ui.path(str(dest))}")
    return str(dest)
