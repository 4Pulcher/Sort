procedure Run_Threads;
var
    I: Integer;
begin
    for I := 0 to Files.Count - 1 do
        Process_File(Files[I]);
end;
