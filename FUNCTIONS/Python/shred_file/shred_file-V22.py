def shred_file(path: Path, ui: UI, passes: int = 3) -> None:
    """Best-effort secure overwrite (V14). No warranty on SSD/COW volumes."""
    size = path.stat().st_size
    with open(path, "ba+") as f:
        for _ in range(passes):
            f.seek(0)
            f.write(os.urandom(size))
            f.flush()
            os.fsync(f.fileno())
    os.remove(path)
    ui.say(f"{ui.icon('remove')}{ui.err(ui.T('shredded'))} {ui.path(str(path))}")
