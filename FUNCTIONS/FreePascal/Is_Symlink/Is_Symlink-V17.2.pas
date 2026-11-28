function Is_Symlink(const F: string): Boolean;
var
    SB: TStat;
begin
    Result := False;
    if FpLStat(F, SB) = 0 then
        Result := FPS_ISLNK(SB.st_mode);
end;
