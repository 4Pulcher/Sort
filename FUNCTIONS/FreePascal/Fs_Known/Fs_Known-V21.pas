function Fs_Known(const Token: string): Boolean;
begin
    Result := Pos(',' + Token + ',', ',' + Fs_Formats + ',') > 0;
end;
