def main(argv: list | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.self_test:
        return run_self_test()
    if args.undo:
        return undo_log(Path(args.undo))
    if args.scan_raw:
        return run_raw_scan(Path(args.scan_raw), args.mode,
                            Path(args.target),
                            Path(args.log) if args.log else None)
    if args.scan:
        if not args.inputs:
            print("SCAN: --scan needs a device or image path")
            return 64
        return run_fs_scan(args.inputs[0], args.scan, args.mode,
                           Path(args.target),
                           Path(args.log) if args.log else None)
    if not args.inputs:
        print(MANPAGE)
        return 0
    opts = Options(
        mode=args.mode, dirs=args.dirs, subdirs=args.subdirs, rename=args.rename,
        extension=args.extension, type_filter=args.type_filter,
        target=Path(args.target), inputs=args.inputs, recursive=args.recursive,
        hidden=args.hidden, follow_links=args.links, replace=args.replace,
        pause=args.pause, jobs=max(1, args.jobs),
        log=Path(args.log) if args.log else None,
        cleanup_empty=args.cleanup_empty, lang=args.lang, colors=args.colors,
        icons=args.icons, quiet=args.quiet,
    )
    return Organizer(opts).run()
