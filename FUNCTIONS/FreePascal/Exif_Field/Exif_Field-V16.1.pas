function Exif_Field(const F, Field: string): string;
var
    Res: string;
begin
    Result := '';
    if RunTool('exiftool', ['-s3', '-' + Field, F], Res) = 0 then
        Result := Trim(Res);
end;
