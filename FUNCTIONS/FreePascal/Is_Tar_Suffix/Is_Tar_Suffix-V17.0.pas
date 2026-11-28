function Is_Tar_Suffix(const F: string): Boolean;
var
    S: string;
begin
    Result := Get_Compound_Ext(F, S);
    if Result then
    begin
        S := LowerCase(S);
        Result := (Pos('tar', S) > 0)
                  or (S = 'tgz') or (S = 'tbz2') or (S = 'tbz')
                  or (S = 'txz') or (S = 'tzst');
    end;
end;
