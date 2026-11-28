function Self_Test: Boolean;
var
    Ok: Boolean;
    F1: string;
    SL: TStringList;
begin
    Ok := True;
    WriteLn('self-test: md5("abc") = ', MD5Print(MD5String('abc')));
    if MD5Print(MD5String('abc')) <> '900150983cd24fb0d6963f7d28e17f72' then
        Ok := False;
    WriteLn('self-test: sha1("abc") = ', SHA1Print(SHA1String('abc')));
    if SHA1Print(SHA1String('abc')) <> 'a9993e364706816aba3e25717850c26c9cd0d89d' then
        Ok := False;
    F1 := GetTempDir + 'sort-selftest.txt';
    SL := TStringList.Create;
    try
        SL.Add('hello');
        SL.SaveToFile(F1);
        if FileExists(F1) then
            WriteLn('self-test: temp-file write OK')
        else
            Ok := False;
        DeleteFile(F1);
    finally
        SL.Free;
    end;
    if Ok then
        WriteLn('self-test: PASS')
    else
        WriteLn('self-test: FAIL');
    Result := Ok;
end;
