procedure Collect_Dir(const Dir: string; List: TStringList);
var
    SR: TSearchRec;
    Rc: Integer;
    Full: string;
begin
    Rc := FindFirst(IncludeTrailingPathDelimiter(Dir) + AllFilesMask, faAnyFile, SR);
    try
        while Rc = 0 do
        begin
            Full := IncludeTrailingPathDelimiter(Dir) + SR.Name;
            if (SR.Name <> '.') and (SR.Name <> '..') then
            begin
                if (SR.Attr and faDirectory) = faDirectory then
                begin
                    if DoRecursive then
                        Collect_Dir(Full, List);
                end
                else
                begin
                    if (not DoHidden) and (SR.Name[1] = '.') then
                        { skip hidden files }
                    else if (not DoLinks) and Is_Symlink(Full) then
                        { skip symlinks unless --links }
                    else
                        List.Add(Full);
                end;
            end;
            Rc := FindNext(SR);
        end;
    finally
        FindClose(SR);
    end;
end;
