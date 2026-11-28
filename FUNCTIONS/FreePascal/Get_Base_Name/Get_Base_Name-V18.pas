function Get_Base_Name(const F: string): string;
var
    Suffix: string;
begin
    if Get_Compound_Ext(F, Suffix) then
        Result := Copy(ExtractFileName(F), 1,
                       Length(ExtractFileName(F)) - Length(Suffix) - 1)
    else
        Result := Name_Without_Ext(F);
end;
