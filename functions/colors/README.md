# functions/colors

> Complete color toolkit - ANSI colors / print helpers

A complete, standalone bag of color and print tools: the `C_*` ANSI color variables for direct use in echo/printf, plus `Print_*` helpers for plain messages, info, ok, errors, warnings, timestamped logs, debug lines, headers and separators. Colors switch on automatically when stdout or stderr is a terminal and switch off for pipes/files or when `NO_COLOR` is set. `Color_Enable` / `Color_Disable` override the detection.

## Color variables

`C_RESET`, `C_BOLD`, `C_DIM`, `C_UNDERLINE`, `C_RED`, `C_GREEN`, `C_YELLOW`, `C_BLUE`, `C_MAGENTA`, `C_CYAN`, `C_WHITE`, `C_GRAY` — usable directly:

```bash
echo "${C_RED}alert${C_RESET}"
printf '%sdone%s\n' "$C_GREEN" "$C_RESET"
```

## Functions

### Color state

- `Color_Enable` — force colors on
- `Color_Disable` — force colors off
- `Color_Preview` — print one line of every color (terminal support check)

### Generic printing

- `Print_Color <name> <text...>` — print in a named color (red/green/yellow/blue/magenta/cyan/white/gray/bold/dim/underline)
- `Print_Line [char] [width]` — separator line (default `-`, 80 wide)
- `Print_Header <text...>` — bold cyan header with separator underneath

### Message levels

- `Print_Message <text...>` — plain message, stdout
- `Print_Info <text...>` — cyan, stdout
- `Print_Ok <text...>` — green, stdout
- `Print_Error <text...>` — red, `Error: ` prefix, stderr, returns false
- `Print_Warning <text...>` — yellow, `Warning: ` prefix, stderr
- `Print_Log <text...>` — dim `[YYYY-MM-DD HH:MM:SS]` timestamp, stderr
- `Print_Debug <text...>` — magenta `[DEBUG]`, stderr, only when `DEBUG=1`

Total: 13 functions.
