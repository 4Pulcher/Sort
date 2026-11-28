function Id3v1_Genre_Name(Idx: Integer): string;
begin
    Result := '';
    if (Idx >= 0) and (Idx <= 125) then
        Result := Genre_Table[Idx];
end;
