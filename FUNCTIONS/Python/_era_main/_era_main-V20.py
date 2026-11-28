def _era_main(argv):
    # --magic (V17.5): magic-number detection report, then exit
    if "--magic" in argv:
        inputs = [a for a in argv if not a.startswith("-")]
        if not inputs:
            print("Nothing to inspect.")
            return 1
        for item in inputs:
            p = Path(item)
            if p.is_dir():
                print(f"{p} (directory - use --recursive not needed; listing files)")
                for child in sorted(p.iterdir()):
                    if child.is_file():
                        print(magic_report(child))
            elif p.exists():
                print(magic_report(p))
            else:
                print(f"{p}: not found")
        return 0
    allowed = set(EDITION["flags"]) | {"--self-test", "--version"}
    for a in argv:
        if a in ("-h", "--help"):
            print(_ERA_USAGE)
            return 0
        if a == "--self-test" or a == "--version" or not a.startswith("-"):
            continue
        name = a.split("=")[0].lower()
        if name == "--scan-raw":
            continue
        if name == "--mode":
            val = a.split("=", 1)[1].lower() if "=" in a else ""
            if val and val not in EDITION["modes"]:
                raise SystemExit(_era_error(
                    "mode '%s' is not part of Sort-%s" % (val, EDITION["version"])))
            continue
        if name not in allowed:
            raise SystemExit(_era_error(
                "option '%s' is not part of Sort-%s" % (name, EDITION["version"])))
        if "=" in a and name in ("--dirs", "--subdirs", "--rename", "--extension"):
            _check_template(a.split("=", 1)[1], name)
    return main(argv)
