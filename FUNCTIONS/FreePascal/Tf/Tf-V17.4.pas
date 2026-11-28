function Tf(const Tpl: String; const Args: array of String): String;
var
    R: String;
    I, P: Integer;
begin
    R := Tpl;
    for I := 0 to High(Args) do
    begin
        P := Pos('%s', R);
        if P > 0 then
            R := Copy(R, 1, P - 1) + Args[I] + Copy(R, P + 2, Length(R));
    end;
    Result := R;
end;
