procedure Fs_Scan_Main;
var
    S, Src, Dest: TFileStream;
    Parts, All: TFsPartArray;
    Hits: array of TRawHit;
    TmpHit: TRawHit;
    Block, Head, Carry, Window, WBuf: array of Byte;
    H, HeadHex, Ext, OutPath, OutDir, Tok, Forms, NewT: string;
    Base, BufBase, N, I, J, E, P, SigStart, Hit, Lo, Hi, NextVal: Int64;
    Parts2: TFsPartArray;
    K: Integer;
    Off, Est, Fsize, Written, Total: Int64;
    Count, HitCount, NList, Scanned, NParts: Integer;
    Found, Broken, Sel: Boolean;
    Formats: TStringList;
    Rec: TFsPart;
begin
    if (Modus = 'move') or (Modus = 'remove') or (Modus = 'trash')
        or (Modus = 'shred') then
    begin
        WriteLn('SCAN: --scan supports dummy and copy only (mode '''
            + Modus + ''' refused)');
        Halt(64);
    end;
    Formats := TStringList.Create;
    try
        Forms := FsFormatsArg;
        if Forms = '' then
            Forms := 'all';
        while Pos(',', Forms) > 0 do
            Forms := StringReplace(Forms, ',', ' ', [rfReplaceAll]);
        Forms := Trim(Forms);
        while Forms <> '' do
        begin
            if Pos(' ', Forms) > 0 then
            begin
                Tok := Copy(Forms, 1, Pos(' ', Forms) - 1);
                Delete(Forms, 1, Pos(' ', Forms));
            end
            else
            begin
                Tok := Forms;
                Forms := '';
            end;
            Tok := Fs_Norm(Tok);
            if Tok = '' then
                Continue;
            if not Fs_Known(Tok) then
            begin
                WriteLn('SCAN: unknown filesystem format ''' + Tok
                    + ''' (known: ' + Fs_Formats + ')');
                Halt(64);
            end;
            if Formats.IndexOf(Tok) < 0 then
                Formats.Add(Tok);
        end;
        if Formats.Count = 0 then
            Formats.Add('all');
    finally
    end;
    Raw_Init;
    S := nil; Src := nil;
    try
        try
            S := TFileStream.Create(FsDevice, fmOpenRead or fmShareDenyNone);
        except
            on EStreamError do
            begin
                WriteLn('SCAN: cannot open ' + FsDevice);
                Halt(66);
            end;
        end;
        Fsize := Fs_Device_Size(S);
        if Fsize <= 0 then
        begin
            WriteLn('SCAN: cannot determine size of ' + FsDevice);
            Halt(66);
        end;

        { --- phase 1a: listed partitions from MBR/GPT --- }
        Fs_Listed(S, Fsize, Parts);
        for I := 0 to Length(Parts) - 1 do
        begin
            SetLength(WBuf, 1200);
            S.Seek(Parts[I].StartV, soFromBeginning);
            N := S.Read(WBuf[0], 1200);
            H := Raw_BytesToHex(WBuf, N);
            Parts[I].Fs := Fs_Probe_Hex(H);
        end;

        { --- phase 1b: lost partitions via 512-aligned probe --- }
        SetLength(All, 0);
        Off := 0;
        while Off < Fsize do
        begin
            if not Fs_Inside_Listed(Parts, Off) then
            begin
                SetLength(WBuf, 1200);
                S.Seek(Off, soFromBeginning);
                N := S.Read(WBuf[0], 1200);
                if N > 0 then
                begin
                    H := Raw_BytesToHex(WBuf, N);
                    Tok := Fs_Probe_Hex(H);
                    if Tok <> '' then
                    begin
                        Est := Fsize;
                        for I := 0 to Length(Parts) - 1 do
                            if (Parts[I].StartV > Off) and
                               (Parts[I].StartV < Est) then
                                Est := Parts[I].StartV;
                        Rec.StartV := Off;
                        Rec.SizeV := Est - Off;
                        Rec.Fs := Tok;
                        Rec.Listed := False;
                        SetLength(All, Length(All) + 1);
                        All[Length(All) - 1] := Rec;
                    end;
                end;
            end;
            Off := Off + 512;
        end;

        { --- assemble: sort by start, listed first in numbering --- }
        { lost partitions sorted by start }
        for I := 0 to Length(All) - 1 do
            for J := I + 1 to Length(All) - 1 do
                if All[J].StartV < All[I].StartV then
                begin
                    Rec := All[I];
                    All[I] := All[J];
                    All[J] := Rec;
                end;
        { final list: listed (sorted by start), then lost (sorted by start) }
        for I := 0 to Length(Parts) - 1 do
            for J := I + 1 to Length(Parts) - 1 do
                if Parts[J].StartV < Parts[I].StartV then
                begin
                    Rec := Parts[I];
                    Parts[I] := Parts[J];
                    Parts[J] := Rec;
                end;
        Parts2 := Parts;
        for I := 0 to Length(All) - 1 do
        begin
            SetLength(Parts2, Length(Parts2) + 1);
            Parts2[Length(Parts2) - 1] := All[I];
        end;
        Parts := Parts2;
        NParts := Length(Parts);

        { --- report the partition map --- }
        WriteLn('SCAN: ' + FsDevice);
        NList := 0;
        for I := 0 to NParts - 1 do
        begin
            if Parts[I].Listed then
                Inc(NList);
            Tok := Parts[I].Fs;
            if Tok = '' then
                Tok := 'unknown';
            if Parts[I].Listed then
                WriteLn(Format('  part %d: 0x%s %d %d %s listed',
                    [I + 1, LowerCase(IntToHex(Parts[I].StartV, 12)),
                     Parts[I].StartV, Parts[I].SizeV, Tok]))
            else
                WriteLn(Format('  part %d: 0x%s %d ~%d %s lost',
                    [I + 1, LowerCase(IntToHex(Parts[I].StartV, 12)),
                     Parts[I].StartV, Parts[I].SizeV, Tok]));
        end;
        WriteLn(Format('SCAN: %d partitions found (%d listed, %d lost)',
            [NParts, NList, NParts - NList]));

        { --- phase 2: per-partition signature scan (V20 engine) --- }
        if Modus = 'copy' then
            ForceDirectories(TargetDir + '/FS-CARVE');
        SetLength(Block, Raw_Block);
        SetLength(Head, Raw_Block);
        Total := 0;
        Scanned := 0;
        for I := 0 to NParts - 1 do
        begin
            Sel := False;
            for K := 0 to Formats.Count - 1 do
                if (Formats[K] = 'all') or (Formats[K] = Parts[I].Fs) then
                    Sel := True;
            if (Parts[I].Fs = '') or (Parts[I].SizeV <= 0) or not Sel then
                Continue;
            Lo := Parts[I].StartV;
            Hi := Lo + Parts[I].SizeV;
            WriteLn(Format('SCAN-PART %d %s 0x%s %d', [I + 1, Parts[I].Fs,
                LowerCase(IntToHex(Lo, 12)), Parts[I].SizeV]));

            { first pass: collect hits inside [Lo, Hi) }
            SetLength(Hits, 0);
            HitCount := 0;
            SetLength(Carry, 0);
            CarryLen := 0;
            Base := Lo;
            S.Seek(Lo, soFromBeginning);
            while Base < Hi do
            begin
                N := S.Read(Block[0], Raw_Block);
                if N <= 0 then
                    Break;
                SetLength(Window, CarryLen + N);
                if CarryLen > 0 then
                    Move(Carry[0], Window[0], CarryLen);
                Move(Block[0], Window[CarryLen], N);
                H := Raw_BytesToHex(Window, Length(Window));
                BufBase := Base - CarryLen;
                for E := 0 to Length(RawEntries) - 1 do
                begin
                    if RawEntries[E].AnchorHex = '' then
                        Continue;
                    if Length(RawEntries[E].Sig) < 4 then
                        Continue;
                    P := PosEx(RawEntries[E].AnchorHex, H, 1);
                    while P > 0 do
                    begin
                        if (P - 1) mod 2 = 0 then
                        begin
                            SigStart := (P - 1) - RawEntries[E].AnchorNibble;
                            if (SigStart mod 2 = 0) and (SigStart >= 0) then
                                if Raw_SigMatch(H, SigStart + 1, E) then
                                begin
                                    Hit := BufBase + SigStart div 2
                                        - RawEntries[E].Off;
                                    if (Hit >= Lo) and (Hit < Hi) then
                                    begin
                                        Inc(HitCount);
                                        SetLength(Hits, HitCount);
                                        Hits[HitCount - 1].Offset := Hit;
                                        Hits[HitCount - 1].Entry := E;
                                        Hits[HitCount - 1].Size := 0;
                                        Hits[HitCount - 1].Exact := False;
                                    end;
                                end;
                        end;
                        P := PosEx(RawEntries[E].AnchorHex, H, P + 1);
                    end;
                end;
                Base := Base + Raw_Block;
                if Base < Hi then
                begin
                    if Length(Window) > Raw_Carry then
                    begin
                        SetLength(Carry, Raw_Carry);
                        Move(Window[Length(Window) - Raw_Carry],
                            Carry[0], Raw_Carry);
                        CarryLen := Raw_Carry;
                    end
                    else
                    begin
                        SetLength(Carry, Length(Window));
                        if Length(Window) > 0 then
                            Move(Window[0], Carry[0], Length(Window));
                        CarryLen := Length(Window);
                    end;
                end;
            end;

            { sort by (offset, name) - same tie-break as the other editions }
            for J := 0 to HitCount - 1 do
                for K := J + 1 to HitCount - 1 do
                    if (Hits[K].Offset < Hits[J].Offset) or
                       ((Hits[K].Offset = Hits[J].Offset) and
                        (RawEntries[Hits[K].Entry].Name <
                         RawEntries[Hits[J].Entry].Name)) then
                    begin
                        TmpHit := Hits[J];
                        Hits[J] := Hits[K];
                        Hits[K] := TmpHit;
                    end;

            { second pass: carve sizes, broken check, report, carve }
            Count := 0;
            NextVal := Lo;
            for J := 0 to HitCount - 1 do
            begin
                E := Hits[J].Entry;
                if (Pos('filesystem', RawEntries[E].Name) > 0) or
                    (RawEntries[E].Name = 'Linux swap area') then
                    Continue;
                if Hits[J].Offset < NextVal then
                    Continue;
                S.Seek(Hits[J].Offset, soFromBeginning);
                N := S.Read(Head[0], Raw_Block);
                HeadHex := Raw_BytesToHex(Head, N);
                Raw_CarveSize(HeadHex, RawEntries[E].Name, Hits[J].Size,
                    Hits[J].Exact);
                if Hits[J].Exact then
                    NextVal := Hits[J].Offset + Hits[J].Size
                else
                    NextVal := Hits[J].Offset + 1;
                Broken := Fs_Broken(Parts, I, Hits[J].Offset, Hits[J].Size);
                Inc(Count);
                Inc(Total);
                Ext := Raw_FirstExt(RawEntries[E].Exts);
                Write('  hit: 0x' + LowerCase(IntToHex(Hits[J].Offset, 12))
                    + ' ' + IntToStr(Hits[J].Offset) + ' '
                    + RawEntries[E].Name + ' -> ' + Ext
                    + ' (carve ' + IntToStr(Hits[J].Size) + ' bytes');
                if not Hits[J].Exact then
                    Write(', capped');
                if Broken then
                    Write(', broken');
                WriteLn(')');
                if Modus = 'copy' then
                begin
                    OutDir := TargetDir + '/FS-CARVE/p' + IntToStr(I + 1)
                        + '-' + LowerCase(IntToHex(Lo, 12));
                    while True do
                    begin
                        try
                            ForceDirectories(OutDir);
                            OutPath := OutDir + '/'
                                + LowerCase(IntToHex(Hits[J].Offset, 12))
                                + '.' + Ext;
                            Dest := TFileStream.Create(OutPath, fmCreate);
                            try
                                S.Seek(Hits[J].Offset, soFromBeginning);
                                Written := 0;
                                while Written < Hits[J].Size do
                                begin
                                    if Hits[J].Size - Written > Raw_Block then
                                        N := Raw_Block
                                    else
                                        N := Hits[J].Size - Written;
                                    N := S.Read(Head[0], N);
                                    if N <= 0 then
                                        Break;
                                    Dest.Write(Head[0], N);
                                    Written := Written + N;
                                end;
                            finally
                                Dest.Free;
                            end;
                            Break;
                        except
                            on EStreamError do
                            begin
                                WriteLn('SCAN: out of space at ' + OutDir);
                                Write('SCAN: new target directory '
                                    + '(empty = abort): ');
                                Flush(Output);
                                ReadLn(NewT);
                                if NewT = '' then
                                begin
                                    WriteLn('SCAN: copy aborted by user');
                                    Halt(65);
                                end;
                                OutDir := NewT + '/FS-CARVE/p'
                                    + IntToStr(I + 1) + '-'
                                    + LowerCase(IntToHex(Lo, 12));
                            end;
                        end;
                    end;
                    WriteLn('  carved: ' + OutPath);
                    if LogFile <> '' then
                    begin
                        H := '{"action": "carved", "src": "' + FsDevice + '@'
                            + IntToStr(Hits[J].Offset) + '", "dst": "'
                            + OutPath + '", "part": ' + IntToStr(I + 1);
                        if Broken then
                            H := H + ', "broken": true';
                        H := H + '}';
                        Out_Log(H);
                    end;
                end;
            end;
            Inc(Scanned);
            WriteLn(Format('SCAN-PART %d: %d signatures found',
                [I + 1, Count]));
        end;
        WriteLn(Format('SCAN: done, %d signatures in %d partitions',
            [Total, Scanned]));
    finally
        S.Free;
        Formats.Free;
    end;
end;
