def main(argv: list | None = None) -> int:
    args = build_parser().parse_args(argv)
    if args.self_test:
        return run_self_test()
    if args.undo:
        return undo_log(Path(args.undo))
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
