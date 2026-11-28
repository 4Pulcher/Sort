function Next_Free(const Dir, Name, Ext: string): string;
var
    N: Integer;
begin
    N := 0;
    Result := Target_Path(Dir, Name, Ext, N);
    while FileExists(Result) do
    begin
        N := N + 1;
        Result := Target_Path(Dir, Name, Ext, N);
    end;
end;
