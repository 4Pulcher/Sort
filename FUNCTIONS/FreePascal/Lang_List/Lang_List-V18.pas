procedure Lang_List;
var
    I: Integer;
begin
    WriteLn(Tr('Available languages (--lang=XX):'));
    for I := Low(LangCodes) to High(LangCodes) do
        WriteLn('  ', LangCodes[I], ' — ', Lang_Name(LangCodes[I]));
end;
