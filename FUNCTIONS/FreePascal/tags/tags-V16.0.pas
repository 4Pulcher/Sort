{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : tags.pas                                                         }
{  Version : 1.0                                                              }
{  Desc    : Audio-tag toolkit - ID3v1 / ID3v2 readers in pure FreePascal     }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh tags.pas    }
{                                                                             }
{*****************************************************************************}
unit tags;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, Classes;

{ Id3v1_Present: true when the file ends with an ID3v1 tag }
function Id3v1_Present(const F: string): Boolean;

{ Id3v1_Field: one ID3v1 field by name (title artist album year comment
  track genre), empty when unusable }
function Id3v1_Field(const F, Field: string): string;

{ Id3v1_Genre_Name: genre name for an ID3v1 genre index (0-125), empty
  when the index is unknown }
function Id3v1_Genre_Name(Idx: Integer): string;

{ Id3v2_Present: true when the file starts with an ID3v2 tag }
function Id3v2_Present(const F: string): Boolean;

{ Id3v2_Major: ID3v2 major version (2, 3 or 4), 0 when absent }
function Id3v2_Major(const F: string): Integer;

{ Id3v2_Tag_Size: total ID3v2 tag size in bytes (synchsafe header size) }
function Id3v2_Tag_Size(const F: string): Integer;

{ Id3v2_Field: one ID3v2 text frame by id (TIT2, TPE1, ...; 3-character
  v2.2 ids work too), empty when the frame is absent }
function Id3v2_Field(const F, Frame: string): string;

{ Id3_Field: one audio tag by friendly name (title artist album year genre
  track) - ID3v2 frames, then ID3v1 fields }
function Id3_Field(const F, Field: string): string;

{ Get_Audio_Title: audio title tag }
function Get_Audio_Title(const F: string): string;

{ Get_Audio_Artist: audio artist tag }
function Get_Audio_Artist(const F: string): string;

{ Get_Audio_Album: audio album tag }
function Get_Audio_Album(const F: string): string;

{ Get_Audio_Year: audio year tag }
function Get_Audio_Year(const F: string): string;

{ Get_Audio_Genre: audio genre tag (numeric genres resolved to names) }
function Get_Audio_Genre(const F: string): string;

{ Get_Audio_Track: audio track-number tag }
function Get_Audio_Track(const F: string): string;

{ Get_Audio_Tags_Dir: composite directory "<Artist>/<Year - Album>",
  empty levels skipped, components sanitized }
function Get_Audio_Tags_Dir(const F: string): string;

implementation

const
    { The 80 standard ID3v1 genres plus the Winamp extensions (0-125) }
    Genre_Table: array[0..125] of string = (
        'Blues', 'Classic Rock', 'Country', 'Dance', 'Disco', 'Funk',
        'Grunge', 'Hip-Hop', 'Jazz', 'Metal', 'New Age', 'Oldies', 'Other',
        'Pop', 'R&B', 'Rap', 'Reggae', 'Rock', 'Techno', 'Industrial',
        'Alternative', 'Ska', 'Death Metal', 'Pranks', 'Soundtrack',
        'Euro-Techno', 'Ambient', 'Trip-Hop', 'Vocal', 'Jazz+Funk', 'Fusion',
        'Trance', 'Classical', 'Instrumental', 'Acid', 'House', 'Game',
        'Sound Clip', 'Gospel', 'Noise', 'Alternative Rock', 'Bass', 'Soul',
        'Punk', 'Space', 'Meditation', 'Instrumental Pop', 'Instrumental Rock',
        'Ethnic', 'Gothic', 'Darkwave', 'Techno-Industrial', 'Electronic',
        'Pop-Folk', 'Eurodance', 'Dream', 'Southern Rock', 'Comedy', 'Cult',
        'Gangsta', 'Top 40', 'Christian Rap', 'Pop/Funk', 'Jungle',
        'Native US', 'Cabaret', 'New Wave', 'Psychadelic', 'Rave',
        'Showtunes', 'Trailer', 'Lo-Fi', 'Tribal', 'Acid Punk', 'Acid Jazz',
        'Polka', 'Retro', 'Musical', 'Rock & Roll', 'Hard Rock', 'Folk',
        'Folk-Rock', 'National Folk', 'Swing', 'Fast Fusion', 'Bebob',
        'Latin', 'Revival', 'Celtic', 'Bluegrass', 'Avantgarde',
        'Gothic Rock', 'Progressive Rock', 'Psychedelic Rock',
        'Symphonic Rock', 'Slow Rock', 'Big Band', 'Chorus', 'Easy Listening',
        'Acoustic', 'Humour', 'Speech', 'Chanson', 'Opera', 'Chamber Music',
        'Sonata', 'Symphony', 'Booty Bass', 'Primus', 'Porn Groove', 'Satire',
        'Slow Jam', 'Club', 'Tango', 'Samba', 'Folklore', 'Ballad',
        'Power Ballad', 'Rhythmic Soul', 'Freestyle', 'Duet', 'Punk Rock',
        'Drum Solo', 'A cappella', 'Euro-House', 'Dance Hall');

{ Trim_Tags: strip NUL bytes and trailing spaces from a raw tag field }
function Trim_Tags(const S: string): string;
var
    T: string;
begin
    T := StringReplace(S, #0, '', [rfReplaceAll]);
    while (T <> '') and (T[Length(T)] = ' ') do
        Delete(T, Length(T), 1);
    Result := T;
end;

{ Latin1_To_Utf8: ISO-8859-1 bytes to UTF-8 text }
function Latin1_To_Utf8(const S: string): string;
var
    I: Integer;
    C: Byte;
begin
    Result := '';
    for I := 1 to Length(S) do
    begin
        C := Ord(S[I]);
        if C < 128 then
            Result := Result + S[I]
        else
            Result := Result + Chr($C0 or (C shr 6)) + Chr($80 or (C and $3F));
    end;
end;

{ Utf16_To_Utf8: UTF-16 bytes (with or without BOM) to UTF-8 text;
  BE selects big-endian when no BOM is present }
function Utf16_To_Utf8(const S: string; BE: Boolean): string;
var
    WS: WideString;
    I, N: Integer;
    W: Word;
    Swap: Boolean;
begin
    Result := '';
    N := Length(S) div 2;
    if N = 0 then
        Exit;
    Swap := False;
    SetLength(WS, N);
    for I := 0 to N - 1 do
    begin
        if BE then
            W := (Ord(S[I * 2 + 1]) shl 8) or Ord(S[I * 2 + 2])
        else
            W := (Ord(S[I * 2 + 2]) shl 8) or Ord(S[I * 2 + 1]);
        if (I = 0) and ((W = $FEFF) or (W = $FFFE)) then
        begin
            { byte order mark - remember the real order, skip the mark }
            if ((W = $FFFE) and (not BE)) or ((W = $FEFF) and BE) then
                Swap := True;
            continue;
        end;
        if Swap then
            W := (W shl 8) or (W shr 8);
        WS[I + 1] := WideChar(W);
    end;
    Result := Utf8Encode(WS);
end;

{ Id3v1_Present: true when the file ends with an ID3v1 tag }
function Id3v1_Present(const F: string): Boolean;
var
    FS: TFileStream;
    Buf: array[0..2] of Byte;
begin
    Result := False;
    if not FileExists(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        if FS.Size < 128 then
            Exit;
        FS.Position := FS.Size - 128;
        FS.ReadBuffer(Buf, 3);
        Result := (Buf[0] = Ord('T')) and (Buf[1] = Ord('A')) and (Buf[2] = Ord('G'));
    finally
        FS.Free;
    end;
end;

{ Id3v1_Field: one ID3v1 field by name, empty when unusable }
function Id3v1_Field(const F, Field: string): string;
var
    FS: TFileStream;
    Buf: array[0..127] of Byte;
    Off, Len, I: Integer;
    Field_L: string;
begin
    Result := '';
    if not Id3v1_Present(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        FS.Position := FS.Size - 128;
        FS.ReadBuffer(Buf, 128);
    finally
        FS.Free;
    end;
    Field_L := LowerCase(Field);
    if Field_L = 'track' then
    begin
        { track byte only valid when the comment zero-separator is there }
        if (Buf[125] = 0) and (Buf[126] <> 0) then
            Result := IntToStr(Buf[126]);
        Exit;
    end;
    if Field_L = 'genre' then
    begin
        if (Buf[127] < 255) and (Buf[127] <= 125) then
            Result := Genre_Table[Buf[127]]
        else if Buf[127] < 255 then
            Result := IntToStr(Buf[127]);
        Exit;
    end;
    if Field_L = 'title' then
    begin
        Off := 3;
        Len := 30;
    end
    else if Field_L = 'artist' then
    begin
        Off := 33;
        Len := 30;
    end
    else if Field_L = 'album' then
    begin
        Off := 63;
        Len := 30;
    end
    else if Field_L = 'year' then
    begin
        Off := 93;
        Len := 4;
    end
    else if Field_L = 'comment' then
    begin
        Off := 97;
        Len := 28;
    end
    else
        Exit;
    for I := Off to Off + Len - 1 do
        Result := Result + Chr(Buf[I]);
    Result := Trim_Tags(Result);
end;

{ Id3v1_Genre_Name: genre name for an index, empty when unknown }
function Id3v1_Genre_Name(Idx: Integer): string;
begin
    Result := '';
    if (Idx >= 0) and (Idx <= 125) then
        Result := Genre_Table[Idx];
end;

{ Id3v2_Present: true when the file starts with an ID3v2 tag }
function Id3v2_Present(const F: string): Boolean;
var
    FS: TFileStream;
    Buf: array[0..2] of Byte;
begin
    Result := False;
    if not FileExists(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        if FS.Size < 10 then
            Exit;
        FS.ReadBuffer(Buf, 3);
        Result := (Buf[0] = Ord('I')) and (Buf[1] = Ord('D')) and (Buf[2] = Ord('3'));
    finally
        FS.Free;
    end;
end;

{ Id3v2_Major: ID3v2 major version, 0 when absent }
function Id3v2_Major(const F: string): Integer;
var
    FS: TFileStream;
    B: Byte;
begin
    Result := 0;
    if not Id3v2_Present(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        FS.Position := 3;
        FS.ReadBuffer(B, 1);
        Result := B;
    finally
        FS.Free;
    end;
end;

{ Id3v2_Tag_Size: synchsafe size from the 10-byte header }
function Id3v2_Tag_Size(const F: string): Integer;
var
    FS: TFileStream;
    Buf: array[0..3] of Byte;
begin
    Result := 0;
    if not Id3v2_Present(F) then
        Exit;
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        FS.Position := 6;
        FS.ReadBuffer(Buf, 4);
        Result := (Buf[0] shl 21) or (Buf[1] shl 14) or (Buf[2] shl 7) or Buf[3];
    finally
        FS.Free;
    end;
end;

{ Id3v2_Field: walk the frames, return the wanted text frame decoded }
function Id3v2_Field(const F, Frame: string): string;
var
    FS: TFileStream;
    Hdr: array[0..9] of Byte;
    Ver, TagSize, Off, EndOff, HdrLen, FSize, I: Integer;
    FID: string;
    Payload: string;
    Enc: Byte;
begin
    Result := '';
    if not Id3v2_Present(F) then
        Exit;
    Ver := Id3v2_Major(F);
    TagSize := Id3v2_Tag_Size(F);
    FS := TFileStream.Create(F, fmOpenRead or fmShareDenyWrite);
    try
        Off := 10;
        EndOff := 10 + TagSize;
        while Off < EndOff do
        begin
            FS.Position := Off;
            if FS.Read(Hdr, 10) < 10 then
                Break;
            if Ver = 2 then
            begin
                { v2.2: 3-char frame id, 3-byte big-endian size, no flags }
                HdrLen := 6;
                FID := '';
                for I := 0 to 2 do
                    FID := FID + Chr(Hdr[I]);
                if not (Hdr[0] in [Ord('A')..'Z', Ord('0')..'9']) then
                    Break;
                FSize := (Hdr[3] shl 16) or (Hdr[4] shl 8) or Hdr[5];
            end
            else
            begin
                HdrLen := 10;
                FID := '';
                for I := 0 to 3 do
                    FID := FID + Chr(Hdr[I]);
                if not (Hdr[0] in [Ord('A')..'Z', Ord('0')..'9']) then
                    Break;
                if Ver >= 4 then
                    FSize := (Hdr[4] shl 21) or (Hdr[5] shl 14) or (Hdr[6] shl 7) or Hdr[7]
                else
                    FSize := (Hdr[4] shl 24) or (Hdr[5] shl 16) or (Hdr[6] shl 8) or Hdr[7];
            end;
            if (FSize <= 0) or (Off + HdrLen + FSize > FS.Size) then
                Break;

            if FID = Frame then
            begin
                SetLength(Payload, FSize);
                FS.Position := Off + HdrLen;
                FS.ReadBuffer(Payload[1], FSize);
                Enc := Ord(Payload[1]);
                Delete(Payload, 1, 1);
                case Enc of
                    1: Result := Trim_Tags(Utf16_To_Utf8(Payload, False));
                    2: Result := Trim_Tags(Utf16_To_Utf8(Payload, True));
                    0: Result := Trim_Tags(Latin1_To_Utf8(Payload));
                else
                    Result := Trim_Tags(Payload);
                end;
                Exit;
            end;
            Off := Off + HdrLen + FSize;
        end;
    finally
        FS.Free;
    end;
end;

{ Id3_Field: friendly name -> ID3v2 frames, then ID3v1 field }
function Id3_Field(const F, Field: string): string;
var
    Field_L: string;
begin
    Result := '';
    Field_L := LowerCase(Field);
    case Field_L of
        'title':
            Result := Id3v2_Field(F, 'TIT2');
        'artist':
            Result := Id3v2_Field(F, 'TPE1');
        'album':
            Result := Id3v2_Field(F, 'TALB');
        'year':
        begin
            Result := Id3v2_Field(F, 'TDRC');
            if Result = '' then
                Result := Id3v2_Field(F, 'TYER');
        end;
        'genre':
            Result := Id3v2_Field(F, 'TCON');
        'track':
            Result := Id3v2_Field(F, 'TRCK');
    else
        Exit;
    end;

    { v2.2 3-character ids }
    if Result = '' then
        case Field_L of
            'title': Result := Id3v2_Field(F, 'TT2');
            'artist': Result := Id3v2_Field(F, 'TP1');
            'album': Result := Id3v2_Field(F, 'TAL');
            'year': Result := Id3v2_Field(F, 'TYE');
            'genre': Result := Id3v2_Field(F, 'TCO');
            'track': Result := Id3v2_Field(F, 'TRK');
        end;

    { ID3v1 fallback }
    if Result = '' then
        Result := Id3v1_Field(F, Field_L);

    { genre: "(17)" or plain "17" -> genre name }
    if (Field_L = 'genre') and (Result <> '') then
    begin
        if (Length(Result) > 2) and (Result[1] = '(') then
            Result := Copy(Result, 2, Pos(')', Result) - 2);
        if Result = IntToStr(StrToIntDef(Result, -1)) then
        begin
            if Id3v1_Genre_Name(StrToIntDef(Result, -1)) <> '' then
                Result := Id3v1_Genre_Name(StrToIntDef(Result, -1));
        end;
    end;
end;

{ Get_Audio_Title: audio title tag }
function Get_Audio_Title(const F: string): string;
begin
    Result := Id3_Field(F, 'title');
end;

{ Get_Audio_Artist: audio artist tag }
function Get_Audio_Artist(const F: string): string;
begin
    Result := Id3_Field(F, 'artist');
end;

{ Get_Audio_Album: audio album tag }
function Get_Audio_Album(const F: string): string;
begin
    Result := Id3_Field(F, 'album');
end;

{ Get_Audio_Year: audio year tag }
function Get_Audio_Year(const F: string): string;
begin
    Result := Id3_Field(F, 'year');
end;

{ Get_Audio_Genre: audio genre tag }
function Get_Audio_Genre(const F: string): string;
begin
    Result := Id3_Field(F, 'genre');
end;

{ Get_Audio_Track: audio track-number tag }
function Get_Audio_Track(const F: string): string;
begin
    Result := Id3_Field(F, 'track');
end;

{ Tags_Sanitize: make one tag component safe as a directory name }
function Tags_Sanitize(const S: string): string;
var
    I: Integer;
begin
    Result := '';
    for I := 1 to Length(S) do
        if S[I] = ' ' then
            Result := Result + '_'
        else if not (S[I] in ['/', '\', ':', '*', '?', '"', '<', '>', '|']) then
            Result := Result + S[I];
end;

{ Get_Audio_Tags_Dir: "<Artist>/<Year - Album>" composite, empty levels
  skipped, components sanitized }
function Get_Audio_Tags_Dir(const F: string): string;
var
    A, Y, Al, Sub: string;
begin
    Result := '';
    A := Tags_Sanitize(Get_Audio_Artist(F));
    Y := Get_Audio_Year(F);
    Al := Tags_Sanitize(Get_Audio_Album(F));
    if (Y <> '') and (Al <> '') then
        Sub := Y + ' - ' + Al
    else
        Sub := Y + Al;
    if A <> '' then
        Result := A;
    if Sub <> '' then
    begin
        if Result <> '' then
            Result := Result + '/' + Sub
        else
            Result := Sub;
    end;
end;

end.
