procedure Sort_Extension(const P: string);
var
    SR: TSearchRec;
    Rc: Integer;
    Full, Short, Name, Mime, Ext, Dir, Target: string;
begin
    if DirectoryExists(P) then
    begin
        Rc := FindFirst(IncludeTrailingPathDelimiter(P) + AllFilesMask, faAnyFile, SR);
        try
            while Rc = 0 do
            begin
                Full := IncludeTrailingPathDelimiter(P) + SR.Name;
                if (SR.Name <> '.') and (SR.Name <> '..') then
                    Sort_Extension(Full);
                Rc := FindNext(SR);
            end;
        finally
            FindClose(SR);
        end;
    end
    else if FileExists(P) then
    begin
        Short := P;
        if Copy(Short, 1, 2) = './' then
            Short := Copy(Short, 3, MaxInt);
        Name := StringReplace(Short, '/', '~', [rfReplaceAll]);
        Name := Name_Without_Ext(Name);
        Mime := Detect_MIME(P);
        Ext := MIME_Sub(Mime);
        if Ext <> '' then
            Dir := UpCase(Ext)
        else
            Dir := '?';
        if not ForceDirectories(Dir) then
        begin
            Out_Err('FAILED) mkdir ' + Dir);
            Bump(CountFailed);
            Exit;
        end;
        { the whole relative path is flattened into the file name }
        Target := Dir + '/' + Name + '.' + LowerCase(Ext);
        if Move_File(P, Target) then
        begin
            Out_Tagged('MOVED', P + ' -> ' + Target);
            Bump(CountMoved);
        end
        else
        begin
            Out_Err('FAILED) mv ' + P);
            Bump(CountFailed);
        end;
    end
    else
        Out_Err('Error: ' + P + ' (does not exist!)');
end;
