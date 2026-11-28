function Magic_Match(const H: string; Off: Integer; const Sig: string): Boolean;
var
    I: Integer;
begin
    Magic_Match := False;
    if Length(H) < Off * 2 + Length(Sig) then
        Exit;
    for I := 1 to Length(Sig) do
        if (Sig[I] <> '?') and (H[Off * 2 + I] <> Sig[I]) then
            Exit;
    Magic_Match := True;
end;
