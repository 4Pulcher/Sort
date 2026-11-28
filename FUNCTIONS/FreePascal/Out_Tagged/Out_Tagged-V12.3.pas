procedure Out_Tagged(const Tag, S: string);
begin
    if DoColored then
        WriteLn(#27 + '[1m' + Tag + #27 + '[0m ' + S)
    else
        WriteLn(Tag + ' ' + S);
end;
