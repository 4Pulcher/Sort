procedure Main;
begin
    Parse_Arguments;
    if DoSelfTest then
    begin
        if Self_Test then
            Halt(0)
        else
            Halt(1);
    end;
    Validate_Options;
    if Magic_Mode then
    begin
        Collect_Files;
        Magic_Report_All;
        Halt(0);
    end;
    if RawDevice <> '' then
    begin
        Raw_Scan_Main;
        Halt(0);
    end;
    if FsFormatsArg <> '' then
    begin
        if FsDevice = '' then
        begin
            Out_Err('SCAN: --scan needs a device or image path');
            Halt(64);
        end;
        Fs_Scan_Main;
        Halt(0);
    end;
    Collect_Files;
    if not DoQuiet then
        WriteLn(Tf(Tr('Found %s file(s)'), [IntToStr(Files.Count)]));
    Run_Threads;
    if not DoQuiet then
    begin
        WriteLn('');
        WriteLn('--- ' + Tr('Summary') + ' ---');
        WriteLn(Tf(Tr('Copied : %s'), [IntToStr(CountCopied)]));
        WriteLn(Tf(Tr('Moved  : %s'), [IntToStr(CountMoved)]));
        WriteLn(Tf(Tr('Removed: %s'), [IntToStr(CountRemoved)]));
        WriteLn(Tf(Tr('Trashed  : %s'), [IntToStr(CountTrashed)]));
        WriteLn(Tf(Tr('Shredded : %s'), [IntToStr(CountShredded)]));
        WriteLn(Tf(Tr('Extracted: %s'), [IntToStr(CountExtracted)]));
        WriteLn(Tf(Tr('Preview: %s'), [IntToStr(CountPreview)]));
        WriteLn(Tf(Tr('Skipped: %s'), [IntToStr(CountSkipped)]));
        WriteLn(Tf(Tr('Failed : %s'), [IntToStr(CountFailed)]));
    end;
    if UndoFile <> '' then
    begin
        UndoLines.SaveToFile(UndoFile);
        FpChmod(UndoFile, S_IRUSR or S_IWUSR or S_IXUSR
                          or S_IRGRP or S_IXGRP or S_IROTH or S_IXOTH);
        WriteLn(Tf(Tr('Undo script written: %s'), [UndoFile]));
    end;
end;
