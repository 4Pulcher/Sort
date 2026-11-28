procedure Validate_Options;
var
    I: Integer;
    LangOK: Boolean;
begin
    LangOK := False;
    for I := Low(LangCodes) to High(LangCodes) do
        if LangCodes[I] = Lang then
            LangOK := True;
    if not LangOK then
    begin
        Out_Err(Tf(Tr('Unsupported language: %s (see --lang)'), [Lang]));
        Lang_List;
        Halt(2);
    end;
    if not ((Modus = 'print') or (Modus = 'copy') or (Modus = 'move')
            or (Modus = 'remove') or (Modus = 'trash') or (Modus = 'shred')) then
    begin
        Out_Err(Tf(Tr('Invalid --mode: %s'), [Modus]));
        Halt(2);
    end;
    if (Modus = 'trash') and (not HaveTool('trash-put')) and (not HaveTool('trash')) then
    begin
        Out_Err(Tr('--trash needs trash-put (trash-cli)'));
        Halt(2);
    end;
    if (SourceDir <> '') and (not DirectoryExists(SourceDir)) then
    begin
        Out_Err(Tf(Tr('Source directory not found: %s'), [SourceDir]));
        Halt(2);
    end;
end;
