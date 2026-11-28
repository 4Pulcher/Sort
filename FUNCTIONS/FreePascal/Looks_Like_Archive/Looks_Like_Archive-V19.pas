function Looks_Like_Archive(const F: string): Boolean;
var
    E: string;
begin
    E := LowerCase(Get_File_Ext(F));
    Result := Is_Zip_File(F) or Is_Tar_Suffix(F) or (E = '7z') or (E = 'rar')
              or (E = 'gz') or (E = 'bz2') or (E = 'xz') or (E = 'zst');
end;
