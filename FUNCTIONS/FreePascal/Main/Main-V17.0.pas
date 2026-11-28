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
    Collect_Files;
    if not DoQuiet then
        WriteLn('Found ' + IntToStr(Files.Count) + ' file(s)');
    Run_Threads;
    if not DoQuiet then
    begin
        WriteLn('');
        WriteLn('--- Summary ---');
        WriteLn('Copied   : ' + IntToStr(CountCopied));
        WriteLn('Moved    : ' + IntToStr(CountMoved));
        WriteLn('Removed  : ' + IntToStr(CountRemoved));
        WriteLn('Trashed  : ' + IntToStr(CountTrashed));
        WriteLn('Shredded : ' + IntToStr(CountShredded));
        WriteLn('Extracted: ' + IntToStr(CountExtracted));
        WriteLn('Preview  : ' + IntToStr(CountPreview));
        WriteLn('Skipped  : ' + IntToStr(CountSkipped));
        WriteLn('Failed   : ' + IntToStr(CountFailed));
    end;
    if UndoFile <> '' then
    begin
        UndoLines.SaveToFile(UndoFile);
        FpChmod(UndoFile, S_IRUSR or S_IWUSR or S_IXUSR
                          or S_IRGRP or S_IXGRP or S_IROTH or S_IXOTH);
        WriteLn('Undo script written: ' + UndoFile);
    end;
end;
