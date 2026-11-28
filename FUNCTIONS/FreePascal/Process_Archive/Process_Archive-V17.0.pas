function Process_Archive(const F: string): Integer;
var
    Tmp, Inner, Saved: string;
    List: TStringList;
    I: Integer;
    Rc: Integer;
begin
    Result := 0;
    if DecompressDepth >= 8 then
        Exit(1);
    Tmp := Make_Temp_Dir;
    Rc := Archive_Extract(F, Tmp);
    if Rc <> 0 then
    begin
        Out_Err('FAILED) ' + F + ' - could not extract (rc ' + IntToStr(Rc) + ')');
        Bump(CountFailed);
        Exit(1);
    end;
    Saved := Modus;
    if Modus <> 'print' then
        Modus := 'copy';
    List := TStringList.Create;
    try
        Find_All_Files(Tmp, List);
        List.Sort;
        for I := 0 to List.Count - 1 do
        begin
            DecompressDepth := DecompressDepth + 1;
            Process_File(List[I]);
            DecompressDepth := DecompressDepth - 1;
        end;
    finally
        List.Free;
    end;
    Modus := Saved;
    Bump(CountExtracted);
    { fate of the archive itself }
    if Modus = 'print' then
    begin
        Out_Tagged('PREVIEW', 'EXTRACT(' + IntToStr(CountExtracted) + '): ' + F
                   + ' <=> delete archive');
        Bump(CountPreview);
    end
    else if Modus = 'trash' then
    begin
        Rc := Trash_File(F, Inner);
        if Rc = 0 then
            Bump(CountTrashed)
        else
        begin
            Out_Err('FAILED) trash ' + F);
            Bump(CountFailed);
        end;
    end
    else if Modus = 'shred' then
    begin
        Shred_File(F);
        Bump(CountShredded);
    end
    else
    begin
        DeleteFile(F);
        Bump(CountRemoved);
    end;
    Remove_Tree(Tmp);
end;
