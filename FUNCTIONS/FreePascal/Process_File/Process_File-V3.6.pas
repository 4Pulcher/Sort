procedure Process_File(const F: string);
var
    Target, Tmp: string;
    Rc: Integer;
begin
    Target := Build_Name(F);
    Target := Unique_Target(Target);

    { dry-run: only show the computed target }
    if Modus = 'print' then
    begin
        Out_Tagged('PREVIEW', F + ' -> ' + Target);
        Bump(CountPreview);
        Exit;
    end;

    { destructive modes act on the source file itself }
    if (Modus = 'remove') then
    begin
        if Modus = 'remove' then
        begin
            if DeleteFile(F) then
            begin
                Out_Tagged('REMOVED', F);
                Bump(CountRemoved);

            end
            else
            begin
                Out_Err('FAILED) rm ' + F);
                Bump(CountFailed);
            end;
        end
        Exit;
    end;
end;
