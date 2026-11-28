procedure Raw_Scan_Main;
var
    Stream, Probe, Dest: TFileStream;
    Block, Head, Carry, Window: array of Byte;
    Hex, HeadHex, Ext, OutPath: string;
    NextVal: Int64;
    Base, BufBase, N, I, E, P, SigStart: Int64;
    Hit: Int64;
    Hits: array of TRawHit;
    HitCount: Integer;
    TmpHit: TRawHit;
    J: Integer;
    Written: Int64;
begin
    if (Modus = 'move') or (Modus = 'remove') or (Modus = 'trash')
        or (Modus = 'shred') then
    begin
        WriteLn('RAW-SCAN: --scan-raw supports dummy and copy only (mode '''
            + Modus + ''' refused)');
        Halt(64);
    end;
    Raw_Init;
    Stream := nil; Probe := nil;
    try
        try
            Stream := TFileStream.Create(RawDevice, fmOpenRead or fmShareDenyNone);
            Probe := TFileStream.Create(RawDevice, fmOpenRead or fmShareDenyNone);
        except
            on EStreamError do
            begin
                WriteLn('RAW-SCAN: cannot open ' + RawDevice);
                Halt(1);
            end;
        end;
        SetLength(Block, Raw_Block);
        SetLength(Head, Raw_Block);
        SetLength(Carry, 0);
        Base := 0;
        WriteLn('RAW-SCAN: ' + RawDevice);
        if Modus = 'copy' then
        begin
            ForceDirectories(TargetDir + '/RAW-CARVE');
        end;
        HitCount := 0;
        SetLength(Hits, 0);
        while True do
        begin
            N := Stream.Read(Block[0], Raw_Block);
            if N <= 0 then
                Break;
            SetLength(Window, Length(Carry) + N);
            if Length(Carry) > 0 then
                Move(Carry[0], Window[0], Length(Carry));
            Move(Block[0], Window[Length(Carry)], N);
            Hex := Raw_BytesToHex(Window, Length(Window));
            BufBase := Base - Length(Carry);
            for E := 0 to Length(RawEntries) - 1 do
            begin
                if RawEntries[E].AnchorHex = '' then
                    Continue;
                if (Length(RawEntries[E].Sig) < 4) then
                    Continue;
                P := PosEx(RawEntries[E].AnchorHex, Hex, 1);
                while P > 0 do
                begin
                    if (P - 1) mod 2 = 0 then
                    begin
                        SigStart := (P - 1) - RawEntries[E].AnchorNibble;
                        if (SigStart mod 2 = 0) and (SigStart >= 0) then
                        begin
                            if Raw_SigMatch(Hex, SigStart + 1, E) then
                            begin
                                Hit := BufBase + SigStart div 2
                                    - RawEntries[E].Off;
                                if Hit >= 0 then
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
                    end;
                    P := PosEx(RawEntries[E].AnchorHex, Hex, P + 1);
                end;
            end;
            Base := Base + N;
            if Length(Window) > Raw_Carry then
            begin
                SetLength(Carry, Raw_Carry);
                Move(Window[Length(Window) - Raw_Carry], Carry[0], Raw_Carry);
            end
            else
            begin
                SetLength(Carry, Length(Window));
                if Length(Window) > 0 then
                    Move(Window[0], Carry[0], Length(Window));
            end;
        end;
        { --- second pass: sort hits by offset, carve sizes, report --- }
        for I := 0 to HitCount - 1 do
            for J := I + 1 to HitCount - 1 do
                if Hits[J].Offset < Hits[I].Offset then
                begin
                    TmpHit := Hits[I];
                    Hits[I] := Hits[J];
                    Hits[J] := TmpHit;
                end;
        NextVal := 0;
        for I := 0 to HitCount - 1 do
        begin
            if Hits[I].Offset < NextVal then
                Continue;
            E := Hits[I].Entry;
            Probe.Seek(Hits[I].Offset, soFromBeginning);
            N := Probe.Read(Head[0], Raw_Block);
            HeadHex := Raw_BytesToHex(Head, N);
            Raw_CarveSize(HeadHex, RawEntries[E].Name, Hits[I].Size,
                Hits[I].Exact);
            if Hits[I].Exact then
                NextVal := Hits[I].Offset + Hits[I].Size
            else
                NextVal := Hits[I].Offset + 1;
            Ext := Raw_FirstExt(RawEntries[E].Exts);
            WriteLn('  hit: 0x' + LowerCase(IntToHex(Hits[I].Offset, 12))
                + ' ' + IntToStr(Hits[I].Offset) + ' ' + RawEntries[E].Name
                + ' -> ' + Ext + ' (carve ' + IntToStr(Hits[I].Size)
                + ' bytes' + IfThen(Hits[I].Exact, '', ', capped') + ')');
            if Modus = 'copy' then
            begin
                OutPath := TargetDir + '/RAW-CARVE/'
                    + LowerCase(IntToHex(Hits[I].Offset, 12)) + '.' + Ext;
                Dest := TFileStream.Create(OutPath, fmCreate);
                try
                    Stream.Seek(Hits[I].Offset, soFromBeginning);
                    Written := 0;
                    while Written < Hits[I].Size do
                    begin
                        if Hits[I].Size - Written < Raw_Block then
                            N := Hits[I].Size - Written
                        else
                            N := Raw_Block;
                        N := Stream.Read(Head[0], N);
                        if N <= 0 then
                            Break;
                        Dest.Write(Head[0], N);
                        Written := Written + N;
                    end;
                finally
                    Dest.Free;
                end;
                WriteLn('  carved: ' + OutPath);
                if LogFile <> '' then
                    Out_Log('{"action": "carved", "src": "' + RawDevice
                        + '@' + IntToStr(Hits[I].Offset) + '", "dst": "'
                        + OutPath + '"}');
            end;
        end;
        WriteLn('RAW-SCAN: ' + IntToStr(HitCount) + ' signatures found');
    finally
        Stream.Free;
        Probe.Free;
    end;
end;
