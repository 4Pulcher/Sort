procedure Magic_Report(const Path: string);
var
    H, Name, Exts, Ext, Verdict: string;
    Comma: string;
begin
    H := Magic_Hex(Path);
    if H = '' then
        H := '(empty)';
    Magic_Detect(LowerCase(H), Name, Exts);
    Ext := LowerCase(ExtractFileExt(Path));
    Delete(Ext, 1, 1);
    if Ext = '' then
        Ext := '(none)';
    Verdict := 'UNKNOWN';
    if Name <> '?' then
    begin
        if Ext = '(none)' then
            Verdict := 'NO-EXT'
        else if Pos(',' + Ext + ',', ',' + Exts + ',') > 0 then
            Verdict := 'MATCH'
        else
            Verdict := 'MISMATCH';
    end;
    Comma := '';
    WriteLn(Path);
    WriteLn(#9'magic: ', H);
    WriteLn(#9'detected: ', Name);
    WriteLn(#9'extension: ', Ext);
    WriteLn(#9'verdict: ', Verdict);
end;
