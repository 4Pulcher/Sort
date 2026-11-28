function Resolve_Segment(const Value, F: string; out Text: string): Integer;
var
    Mime, DT, Tmp: string;
    W, H: Integer;
    P: Integer;
begin
    Text := '';
    Result := 0;
    if Value = 'extension' then
        Text := Get_File_Ext(F)
    else
        Result := 2;  { unknown -> treated as literal }
end;
