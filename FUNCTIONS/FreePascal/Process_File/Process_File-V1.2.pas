procedure Process_File(const F: string);
var
    Mime, Type_, Ext, Fext, Name, Dir, New, Sub, Class_: string;
    W, H: Integer;
begin
    Mime := Detect_MIME(F);
    if Mime = '' then
    begin
        Out_Err('File (' + F + ') not recognized!');
        Bump(CountFailed);
        Exit;
    end;
    Type_ := UpCase(MIME_Main(Mime));
    Ext := UpCase(MIME_Sub(Mime));
    Fext := Ext_From_MimeTypes(Mime);
    Out_Tagged('MIME', UpCase(Mime) + ' <' + Fext + '>');
    if DoRename then
    begin
        Name := Hash_File(F);
        if Name = '' then
            Name := ExtractFileName(F);
    end
    else
        Name := ExtractFileName(F);
    if DoClasses then
        Dir := Type_ + '/' + Ext
    else
        Dir := Ext;
    if (Type_ = 'IMAGE') and DoSizes then
    begin
        Image_WxH(F, W, H);
        if (W > 0) and (H > 0) then
        begin
            if W > H then
                Sub := 'wide'
            else if W < H then
                Sub := 'high'
            else
                Sub := 'square';
            if (W < 500) or (H < 500) then
                Class_ := 'small-' + Sub
            else if (W > 5000) or (H > 5000) then
                Class_ := 'big-' + Sub
            else
                Class_ := 'medium-' + Sub;
            Dir := Dir + '/' + Class_ + '/' + IntToStr(W) + '-' + IntToStr(H);
        end;
    end;
    { the early eras used ALL-CAPS directory names }
    Dir := UpCase(Dir);
    New := Target_Path(Dir, Name, Fext, 0);
    if (F = New) or (ExpandFileName(F) = ExpandFileName(New)) then
    begin
        Out_Tagged('Equals', New);
        Exit;
    end;
    if Mode = '' then
    begin
        Out_Tagged('Target', New);
        Bump(CountPreview);
        Exit;
    end;
    if (Mode = 'Move') or (Mode = 'Add') then
        New := Next_Free(Dir, Name, Fext);
    if not ForceDirectories(Dir) then
    begin
        Out_Err('FAILED) mkdir ' + Dir);
        Bump(CountFailed);
        Exit;
    end;
    if (Mode = 'Replace') or (Mode = 'Move') then
    begin
        if Move_File(F, New) then
        begin
            Out_Tagged('MOVED', F + ' -> ' + New);
            Bump(CountMoved);
        end
        else
        begin
            Out_Err('FAILED) mv ' + F);
            Bump(CountFailed);
        end;
    end
    else if (Mode = 'Copy') or (Mode = 'Add') then
    begin
        if Copy_File(F, New) then
        begin
            Out_Tagged('COPIED', F + ' -> ' + New);
            Bump(CountCopied);
        end
        else
        begin
            Out_Err('FAILED) cp ' + F);
            Bump(CountFailed);
        end;
    end;
end;
