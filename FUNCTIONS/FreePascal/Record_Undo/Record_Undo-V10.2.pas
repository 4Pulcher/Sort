procedure Record_Undo(const Op, A, B: string);
begin
    if Op = 'mv' then
        UndoLines.Add('mv ''' + A + ''' ''' + B + ''';')
    else if Op = 'cp' then
        UndoLines.Add('rm -f ''' + A + ''';');
end;
