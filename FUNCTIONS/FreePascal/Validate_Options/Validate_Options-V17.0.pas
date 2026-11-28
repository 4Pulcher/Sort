procedure Validate_Options;
begin
    if not ((Modus = 'print') or (Modus = 'copy') or (Modus = 'move')
            or (Modus = 'remove') or (Modus = 'trash') or (Modus = 'shred')) then
    begin
        Out_Err('Invalid --mode: ' + Modus);
        Halt(2);
    end;
    if (Modus = 'trash') and (not HaveTool('trash-put')) and (not HaveTool('trash')) then
    begin
        Out_Err('--trash needs trash-put (trash-cli) installed');
        Halt(2);
    end;
    if (SourceDir <> '') and (not DirectoryExists(SourceDir)) then
    begin
        Out_Err('Source directory not found: ' + SourceDir);
        Halt(2);
    end;
end;
