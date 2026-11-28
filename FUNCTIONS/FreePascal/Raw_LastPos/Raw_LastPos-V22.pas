function Raw_LastPos(const H, Sub: string; From: Integer): Integer;
var
    P, Last: Integer;
begin
    Last := 0;
    P := PosEx(Sub, H, From);
    while P > 0 do
    begin
        if (P - 1) mod 2 = 0 then
            Last := P;
        P := PosEx(Sub, H, P + 1);
    end;
    Result := Last;
end;
