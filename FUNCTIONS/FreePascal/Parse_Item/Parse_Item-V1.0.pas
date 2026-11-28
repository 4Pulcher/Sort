procedure Parse_Item(const A: string);
var
    W: string;
begin
    W := LowerCase(A);
    if (W = 'replace') or (W = 'move') or (W = 'copy') or (W = 'add') then
    begin
        Mode := UpCase(W[1]) + Copy(W, 2, MaxInt);
        Out_Tagged('SET', 'Mode=' + Mode);
    end
    else if W = 'rename' then
    begin
        DoRename := True;
        Out_Tagged('SET', 'Rename=Yes');
    end
    else if W = 'subdirs' then
    begin
        DoSubDirs := True;
        Out_Tagged('SET', 'SubDirs=Yes');
    end
    else if W = 'classes' then
    begin
        DoClasses := True;
        Out_Tagged('SET', 'Classes=Yes');
    end
    else if W = 'sizes' then
    begin
        DoSizes := True;
        Out_Tagged('SET', 'Sizes=Yes');
    end
    else
        Process_Path(A);
end;
