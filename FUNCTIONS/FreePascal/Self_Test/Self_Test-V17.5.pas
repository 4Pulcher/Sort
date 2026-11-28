function Self_Test: Boolean;
var
    Ok: Boolean;
    D, F1: string;
    SL: TStringList;
begin
    Ok := True;
    WriteLn('self-test: md5("abc") = ', MD5Print(MD5String('abc')));
    if MD5Print(MD5String('abc')) <> '900150983cd24fb0d6963f7d28e17f72' then
        Ok := False;
    WriteLn('self-test: sha1("abc") = ', SHA1Print(SHA1String('abc')));
    if SHA1Print(SHA1String('abc')) <> 'a9993e364706816aba3e25717850c26c9cd0d89d' then
        Ok := False;
    D := Make_Temp_Dir;
    F1 := IncludeTrailingPathDelimiter(D) + 't.txt';
    SL := TStringList.Create;
    try
        SL.Add('hello');
        SL.SaveToFile(F1);
        if FileExists(F1) then
            WriteLn('self-test: temp-file write OK')
        else
            Ok := False;
    finally
        SL.Free;
    end;
    Remove_Tree(D);
    if Ok then
        WriteLn('self-test: PASS')
    else
        WriteLn('self-test: FAIL');
    Result := Ok;
end;
