procedure Parse_Arguments;
var
    I: Integer;
    A, K: string;
begin
    { walk the command line: every --word sets an option,
      a bare word is the start directory }
    I := 1;
    while I <= ParamCount do
    begin
        A := ParamStr(I);
        if Copy(A, 1, 2) = '--' then
        begin
            K := LowerCase(A);
            if Pos('=', A) > 0 then
                K := LowerCase(Copy(A, 1, Pos('=', A) - 1));
            if K = '--rename' then
                RenameVal := LowerCase(Opt_Value(A))
            else if K = '--extension' then
                ExtensionVal := LowerCase(Opt_Value(A))
            else if K = '--copy' then
                Modus := 'copy'
            else if K = '--move' then
                Modus := 'move'
            else if K = '--replace' then
                DoReplace := True
            else
                        begin Out_Err('Unknown option: ' + A); Show_Usage; Halt(2); end
        end
        else
            SourceDir := A;  { positional: start directory }
        I := I + 1;
    end;
end;
