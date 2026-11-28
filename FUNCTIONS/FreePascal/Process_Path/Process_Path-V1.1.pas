procedure Process_Path(const P: string);
var
    SR: TSearchRec;
    Rc: Integer;
    Full: string;
begin
    if DirectoryExists(P) then
    begin
        if (Pos('lost+found', P) > 0) and (not DoSubDirs) then
        begin
            Out_Tagged('DIR', P + ' (skipped)');
            Exit;
        end;
        Out_Tagged('DIR', P);
        Rc := FindFirst(IncludeTrailingPathDelimiter(P) + AllFilesMask, faAnyFile, SR);
        try
            while Rc = 0 do
            begin
                Full := IncludeTrailingPathDelimiter(P) + SR.Name;
                if (SR.Name <> '.') and (SR.Name <> '..') then
                    Process_Path(Full);
                Rc := FindNext(SR);
            end;
        finally
            FindClose(SR);
        end;
    end
    else if FileExists(P) then
    begin
        Out_Tagged('FILE', P);
        Process_File(P);
    end
    else
        Out_Err('File (' + P + ') not recognized!');
end;
