function Get_Compound_Ext_Last(const F: string): string;
var
    S: string;
begin
    if Get_Compound_Ext(F, S) then
    begin
        S := LowerCase(S);
        if Pos('.', S) > 0 then
            Result := Copy(S, LastDelimiter('.', S) + 1, MaxInt)
        else
            Result := S;
    end
    else
        Result := LowerCase(Get_File_Ext(F));
end;
