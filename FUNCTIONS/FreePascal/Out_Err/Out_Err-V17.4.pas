procedure Out_Err(const S: string);
begin
    Lock.Enter;
    try
        if DoColored then
            WriteLn(StdErr, C_Red + S + C_Reset)
        else
            WriteLn(StdErr, S);
    finally
        Lock.Leave;
    end;
end;
