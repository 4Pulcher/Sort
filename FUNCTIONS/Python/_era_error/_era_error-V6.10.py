def _era_error(msg):
    print("Sort-V6.10 edition error: " + msg)
    print("Allowed here -- modes: " + ", ".join(EDITION["modes"]) +
          " | flags: " + ", ".join(EDITION["flags"]) +
          " | keywords: " + ", ".join(EDITION["keywords"]))
    print("Run with -h for the full era usage.")
    return 64
