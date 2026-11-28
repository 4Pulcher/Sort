procedure Main;
var
    I: Integer;
begin
    if ParamCount > 0 then
    begin
        WriteLn('Sorting..');
        for I := 1 to ParamCount do
            Sort_Extension(ParamStr(I));
        WriteLn('Done!');
        WriteLn('');
        WriteLn('--- Summary ---');
        WriteLn('Moved  : ' + IntToStr(CountMoved));
        WriteLn('Failed : ' + IntToStr(CountFailed));
    end;
end;
