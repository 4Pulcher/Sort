procedure Parse_Arguments;
var
    I: Integer;
    A, K: string;
begin
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
            else if K = '--undo' then
            begin
                UndoFile := 'sort-undo.sh';
                if Pos('=', A) > 0 then
                    UndoFile := Opt_Value(A);
            end
            else if K = '--jobs' then
                JobCount := StrToIntDef(Opt_Value(A), 1)
            else if K = '--copy' then
                Modus := 'copy'
            else if K = '--move' then
                Modus := 'move'
            else if K = '--remove' then
                Modus := 'remove'
            else if K = '--delete' then
                Modus := 'remove'
            else if K = '--trash' then
                Modus := 'trash'
            else if K = '--shred' then
                Modus := 'shred'
            else if K = '--replace' then
                DoReplace := True
            else if K = '--recursive' then
                DoRecursive := True
            else if K = '--hidden' then
                DoHidden := True
            else if K = '--links' then
                DoLinks := True
            else if (K = '--colored') or (K = '--colors') then
                DoColored := True
            else if K = '--quiet' then
                DoQuiet := True
            else if K = '--verbose' then
                DoVerbose := True
            else if K = '--stats' then
                DoStats := True
            else if K = '--strip' then
                DoStrip := True
            else if K = '--exif' then
                DoExif := True
            else if K = '--decompress' then
                DoDecompress := True
            else if K = '--title' then
                RenameVal := 'title'
            else if K = '--self-test' then
                DoSelfTest := True
            else if K = '--lang' then
            begin
                if Pos('=', A) > 0 then
                    Lang := LowerCase(Opt_Value(A))
                else
                begin
                    Lang_List;
                    Halt(0);
                end;
            end
            else if K = '--magic' then
            begin
                Magic_Mode := True
            end
            else if K = '--scan-raw' then
            begin
                if Pos('=', A) > 0 then
                    RawDevice := Opt_Value(A)
                else
                    RawPending := True
            end
            else if K = '--scan' then
            begin
                if Pos('=', A) > 0 then
                    FsFormatsArg := Opt_Value(A)
                else
                    FsPending := True
            end
            else if K = '--usage' then
            begin
                Show_Usage;
                Halt(0);
            end
            else if (K = '--help') or (K = '-h') then
            begin
                Show_Help;
                Halt(0);
            end
            else if K = '--version' then
            begin
                Show_Version;
                Halt(0);
            end
            else
            begin
                Out_Err(Tf(Tr('Unknown option: %s'), [A]));
                Show_Usage;
                Halt(2);
            end;
        end
        else
        begin
            if RawPending then
            begin
                RawDevice := A;
                RawPending := False;
            end
            else if FsPending then
            begin
                FsDevice := A;
                FsPending := False;
            end
            else
                SourceDir := A;  { positional: start directory }
        end
        I := I + 1;
    end;
end;
