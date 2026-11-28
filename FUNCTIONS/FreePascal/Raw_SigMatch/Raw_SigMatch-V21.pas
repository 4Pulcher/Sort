function Raw_SigMatch(const H: string; Pos1: Integer; E: Integer): Boolean;
var
    I: Integer;
begin
    Result := False;
    if Length(H) < Pos1 + Length(RawEntries[E].Sig) - 1 then
        Exit;
    for I := 1 to Length(RawEntries[E].Sig) do
        if (RawEntries[E].Sig[I] <> '?')
            and (H[Pos1 + I - 1] <> RawEntries[E].Sig[I]) then
            Exit;
    Result := True;
end;
