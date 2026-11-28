procedure Out_Log(const S: string);
begin
    if DoVerbose then
        Out_Tagged('#', S);
    if LogFile <> '' then
        with TStringList.Create do
        try
            if FileExists(LogFile) then
                LoadFromFile(LogFile);
            Add(S);
            SaveToFile(LogFile);
        finally
            Free;
        end;
end;
