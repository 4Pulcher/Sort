procedure Out_Err(const S: string);
begin
    if DoColored then
        WriteLn(StdErr, #27 + '[31m' + S + #27 + '[0m')
    else
        WriteLn(StdErr, S);
end;
