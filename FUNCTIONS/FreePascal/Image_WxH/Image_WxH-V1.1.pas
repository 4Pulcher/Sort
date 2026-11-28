procedure Image_WxH(const F: string; out W, H: Integer);
var
    Res: string;
    P: Integer;
begin
    W := 0;
    H := 0;
    if RunTool('identify', ['-format', '%w:%h', F], Res) <> 0 then
        Exit;
    Res := Trim(Res);
    if Length(Res) < 3 then
        Res := '0:0';
    P := Pos(':', Res);
    if P = 0 then
        Exit;
    W := StrToIntDef(Copy(Res, 1, P - 1), 0);
    H := StrToIntDef(Copy(Res, P + 1, MaxInt), 0);
end;
