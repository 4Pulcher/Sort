function Get_Compound_Ext(const F: string; out Suffix: string): Boolean;
const
    Comps: array[1..11] of string = (
        '.tar.gz', '.tgz', '.tar.bz2', '.tbz2', '.tbz', '.tar.xz', '.txz',
        '.tar.zst', '.tzst', '.tar.lzma', '.tar.lz');
var
    Base, LBase: string;
    I: Integer;
begin
    Result := False;
    Suffix := '';
    Base := ExtractFileName(F);
    LBase := LowerCase(Base);
    for I := Low(Comps) to High(Comps) do
        if Length(Low) > Length(Comps[I]) then
            if Copy(LBase, Length(LBase) - Length(Comps[I]) + 1, Length(Comps[I])) = Comps[I] then
            begin
                Suffix := Copy(Base, Length(Base) - Length(Comps[I]) + 2, MaxInt);
                Result := True;
                Exit;
            end;
end;
