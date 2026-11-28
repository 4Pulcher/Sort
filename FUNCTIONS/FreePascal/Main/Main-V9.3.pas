procedure Main;
begin
    Parse_Arguments;
    { --self-test: run the built-in checks and exit }
    if DoSelfTest then
    begin
        if Self_Test then
            Halt(0)
        else
            Halt(1);
    end;
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
    WriteLn('Preview  : ' + IntToStr(CountPreview));
    WriteLn('Skipped  : ' + IntToStr(CountSkipped));
    WriteLn('Failed   : ' + IntToStr(CountFailed));
end;
