function Trash_File(const F: string; out Text: string): Integer;
begin
    if HaveTool('trash-put') then
        Result := RunTool('trash-put', [F], Text)
    else if HaveTool('trash') then
        Result := RunTool('trash', [F], Text)
    else
        Result := 127;
end;
