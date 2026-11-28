procedure Process_File(const F: string);
var
    Target, Tmp: string;
    Rc: Integer;
begin

    if TypeFilter <> '' then
    begin
        Tmp := Detect_MIME(F);
        if Pos(LowerCase(TypeFilter), LowerCase(Tmp)) = 0 then
        begin
            Bump(CountSkipped);
            Exit;
        end;
    end;
    Target := Build_Name(F);
    Target := Unique_Target(Target);

    { dry-run: only show the computed target }
    if Modus = 'print' then
    begin
        Out_Tagged('PREVIEW', F + ' -> ' + Target);
        Bump(CountPreview);
        Exit;
    end;

    { destructive modes act on the source file itself }
    if (Modus = 'remove') or (Modus = 'trash') or (Modus = 'shred') then
    begin
        if Modus = 'remove' then
        begin
            if DeleteFile(F) then
            begin
                Out_Tagged('REMOVED', F);
                Bump(CountRemoved);
                Out_Log('rm ' + F);
            end
            else
            begin
                Out_Err('FAILED) rm ' + F);
                Bump(CountFailed);
            end;
        end
        else if Modus = 'trash' then
        begin
            Rc := Trash_File(F, Tmp);
            if Rc = 0 then
            begin
                Out_Tagged('TRASHED', F);
                Bump(CountTrashed);
            end
            else
            begin
                Out_Err('FAILED) trash ' + F + ' (rc ' + IntToStr(Rc) + ')');
                Bump(CountFailed);
            end;
        end
        else
        begin
            Shred_File(F);
            Out_Tagged('SHREDDED', F);
            Bump(CountShredded);
        end;
        Exit;
    end;

    { create the target directory, then copy or move }
    if not ForceDirectories(ExtractFileDir(Target)) then
    begin
        Out_Err('FAILED) mkdir ' + ExtractFileDir(Target));
        Bump(CountFailed);
        Exit;
    end;
    if Modus = 'move' then
    begin
        if Move_File(F, Target) then
        begin
            Out_Tagged('MOVED', F + ' -> ' + Target);
            Bump(CountMoved);
            Out_Log('mv "' + F + '" "' + Target + '"');
        end
        else
        begin
            Out_Err('FAILED) move ' + F);
            Bump(CountFailed);
        end;
    end
    else
    begin
        if Copy_File(F, Target) then
        begin
            Out_Tagged('COPIED', F + ' -> ' + Target);
            Bump(CountCopied);
            Out_Log('cp "' + F + '" "' + Target + '"');
        end
        else
        begin
            Out_Err('FAILED) copy ' + F);
            Bump(CountFailed);
        end;
    end;


    if PauseSec > 0 then
        Sleep(PauseSec * 1000);
end;
