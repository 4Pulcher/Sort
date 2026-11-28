procedure Magic_Report_All;
var
    I: Integer;
begin
    for I := 0 to Files.Count - 1 do
        Magic_Report(Files[I]);
end;
