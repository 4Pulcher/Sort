procedure Out_Tagged(const Tag, S: string);
begin
    Lock.Enter;
    try
        if DoColored then
            WriteLn(C_Bold + Tag + C_Reset + ' ' + S)
        else
            WriteLn(Tag + ' ' + S);
    finally
        Lock.Leave;
    end;
end;
