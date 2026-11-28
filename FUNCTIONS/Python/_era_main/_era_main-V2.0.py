def _era_main(argv):
    allowed = set(EDITION["flags"]) | {"--self-test", "--version"}
    for a in argv:
        if a in ("-h", "--help"):
            print(_ERA_USAGE)
            return 0
        if a == "--self-test" or a == "--version" or not a.startswith("-"):
            continue
        name = a.split("=")[0].lower()
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
