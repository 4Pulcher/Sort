procedure Out_Log(const S: string);
begin
    if DoVerbose then
        Out_Tagged('#', S);
    if LogFile <> '' then
    begin
        Lock.Enter;
        try
            with TStringList.Create do
            try
                if FileExists(LogFile) then
                    LoadFromFile(LogFile);
                Add(S);
                SaveToFile(LogFile);
            finally
                Free;
            end;
        finally
            Lock.Leave;
        end;
    end;
end;
