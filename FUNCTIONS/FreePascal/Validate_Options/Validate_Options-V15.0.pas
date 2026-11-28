procedure Validate_Options;
begin
    if (SourceDir <> '') and (not DirectoryExists(SourceDir)) then
    begin
        Out_Err('Source directory not found: ' + SourceDir);
        Halt(2);
    end;
end;
