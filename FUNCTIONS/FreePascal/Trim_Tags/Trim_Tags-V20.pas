function Trim_Tags(const S: string): string;
var
    T: string;
begin
    T := StringReplace(S, #0, '', [rfReplaceAll]);
    while (T <> '') and (T[Length(T)] = ' ') do
        Delete(T, Length(T), 1);
    Result := T;
end;
