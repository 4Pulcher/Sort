procedure Main;
var
    I: Integer;
begin
    if ParamCount = 0 then
    begin
        WriteLn(ExtractFileName(ParamStr(0)));
        WriteLn('');
        WriteLn('Usage: [''Replace''|''Move''|''Copy''|''Add''] [''Rename''] [''SubDirs'']');
        WriteLn('       [''Classes''] [''Sizes''] ''FileList''');
        Exit;
    end;
    Out_Tagged('SCRIPT', ExtractFileName(ParamStr(0)));
    for I := 1 to ParamCount do
        Parse_Item(ParamStr(I));
    WriteLn('');
    WriteLn('--- Summary ---');
    WriteLn('Moved   : ' + IntToStr(CountMoved));
    WriteLn('Copied  : ' + IntToStr(CountCopied));
    WriteLn('Preview : ' + IntToStr(CountPreview));
    WriteLn('Failed  : ' + IntToStr(CountFailed));
end;
