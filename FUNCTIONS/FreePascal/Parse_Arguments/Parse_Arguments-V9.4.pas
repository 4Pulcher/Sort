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
            if K = '--mode' then
                Modus := LowerCase(Opt_Value(A))
            else if K = '--dirs' then
                DirList := Opt_Value(A)
            else if K = '--subdirs' then
                SubList := Opt_Value(A)
            else if K = '--rename' then
                RenameVal := LowerCase(Opt_Value(A))
            else if K = '--extension' then
                ExtensionVal := LowerCase(Opt_Value(A))
            else if K = '--type' then
                TypeFilter := Opt_Value(A)
            else if K = '--source' then
                SourceDir := Opt_Value(A)
            else if K = '--target' then
                TargetDir := Opt_Value(A)
            else if K = '--pause' then
                PauseSec := StrToIntDef(Opt_Value(A), 0)
            else if K = '--log' then
                LogFile := Opt_Value(A)
            else if K = '--replace' then
                DoReplace := True
            else if K = '--recursive' then
                DoRecursive := True
            else if K = '--probe' then
                begin ProbeMode := 'info'; if Pos('=', A) > 0 then ProbeMode := LowerCase(Opt_Value(A)); end
            else if K = '--title' then
                RenameVal := 'title'
            else if K = '--self-test' then
                DoSelfTest := True
            else if (K = '--help') or (K = '-h') then
                begin Show_Help; Halt(0); end
            else
                        begin Out_Err('Unknown option: ' + A); Show_Usage; Halt(2); end
        end
        else
            SourceDir := A;  { positional: start directory }
        I := I + 1;
    end;
end;
