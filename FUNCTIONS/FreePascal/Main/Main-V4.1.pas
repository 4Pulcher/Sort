procedure Main;
begin
    Parse_Arguments;
    { validate the options before touching anything }
    Validate_Options;
    { collect the complete work list up front }
    Collect_Files;
    WriteLn('Found ' + IntToStr(Files.Count) + ' file(s)');
    { process the work list }
    Run_Threads;
    { summary }
    WriteLn('');
    WriteLn('--- Summary ---');
    WriteLn('Copied   : ' + IntToStr(CountCopied));
    WriteLn('Moved    : ' + IntToStr(CountMoved));
    WriteLn('Preview  : ' + IntToStr(CountPreview));
    WriteLn('Failed   : ' + IntToStr(CountFailed));
end;
