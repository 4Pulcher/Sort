procedure Validate_Options;
begin
    if not ((Modus = 'print') or (Modus = 'copy') or (Modus = 'move') or (Modus = 'remove')) then
    begin
        Out_Err('Invalid --mode: ' + Modus);
        Halt(2);
    end;
    if (SourceDir <> '') and (not DirectoryExists(SourceDir)) then
    begin
        Out_Err('Source directory not found: ' + SourceDir);
        Halt(2);
    end;
end;
