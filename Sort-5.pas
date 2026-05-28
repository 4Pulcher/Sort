{ Sort.pas }
program Sort;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, StrUtils, Process, MD5, fpjson, jsonparser;

type
  TMode = (moDummy, moCopy, moMove, moCompare, moFind, moDelete, moDestroy);

  TMimeRule = record
    HexSignatures: TStringList;
    Offsets: TStringList;
    Extensions: TStringList;
    Description: string;
  end;

  TOptions = record
    Probe: Boolean;
    Recursive: Boolean;
    ReplaceExisting: Boolean;
    ShowHelp: Boolean;
    SelfTest: Boolean;
    Mode: TMode;
    TypeFilter: string;
    DirsSpec: string;
    SubDirsSpec: string;
    RenameSpec: string;
    ExtensionSpec: string;
    Target: string;
    Inputs: TStringList;
    ReplaceConfirmed: Boolean;
  end;

var
  MimeRules: array of TMimeRule;
  MimeRulesLoaded: Boolean = False;
  MimeCache: TStringList;
  HashCache: TStringList;

procedure InitOptions(out Opts: TOptions);
begin
  Opts.Probe := False;
  Opts.Recursive := False;
  Opts.ReplaceExisting := False;
  Opts.ShowHelp := False;
  Opts.SelfTest := False;
  Opts.Mode := moDummy;
  Opts.TypeFilter := '';
  Opts.DirsSpec := '';
  Opts.SubDirsSpec := '';
  Opts.RenameSpec := 'original';
  Opts.ExtensionSpec := 'original';
  Opts.Target := '';
  Opts.Inputs := TStringList.Create;
  Opts.ReplaceConfirmed := False;
end;

procedure FreeOptions(var Opts: TOptions);
begin
  if Assigned(Opts.Inputs) then
    Opts.Inputs.Free;
  Opts.Inputs := nil;
end;

procedure FreeMimeRule(var Rule: TMimeRule);
begin
  Rule.HexSignatures.Free;
  Rule.Offsets.Free;
  Rule.Extensions.Free;
  Rule.Description := '';
end;

procedure FreeMimeRules;
var
  I: Integer;
begin
  for I := 0 to High(MimeRules) do
    FreeMimeRule(MimeRules[I]);
  SetLength(MimeRules, 0);
  MimeRulesLoaded := False;
end;

procedure InitMimeCache;
begin
  if Assigned(MimeCache) then
    Exit;
  MimeCache := TStringList.Create;
  MimeCache.CaseSensitive := False;
  MimeCache.NameValueSeparator := '=';
end;

procedure FreeMimeCache;
begin
  MimeCache.Free;
  MimeCache := nil;
end;

function GetCachedMime(const FilePath: string): string;
var
  I: Integer;
begin
  Result := '';
  if not Assigned(MimeCache) then
    Exit;
  I := MimeCache.IndexOfName(FilePath);
  if I >= 0 then
    Result := MimeCache.ValueFromIndex[I];
end;

procedure PutCachedMime(const FilePath, Mime: string);
var
  I: Integer;
begin
  InitMimeCache;
  I := MimeCache.IndexOfName(FilePath);
  if I >= 0 then
    MimeCache.ValueFromIndex[I] := Mime
  else
    MimeCache.Add(FilePath + '=' + Mime);
end;

procedure InitHashCache;
begin
  if Assigned(HashCache) then
    Exit;
  HashCache := TStringList.Create;
  HashCache.CaseSensitive := False;
  HashCache.NameValueSeparator := '=';
end;

procedure FreeHashCache;
begin
  HashCache.Free;
  HashCache := nil;
end;

function MakeHashCacheKey(const Algo, FilePath: string): string;
begin
  Result := LowerCase(Trim(Algo)) + '|' + ExpandFileName(FilePath);
end;

function GetCachedHash(const Algo, FilePath: string): string;
var
  Key: string;
  I: Integer;
begin
  Result := '';
  if not Assigned(HashCache) then
    Exit;
  Key := MakeHashCacheKey(Algo, FilePath);
  I := HashCache.IndexOfName(Key);
  if I >= 0 then
    Result := HashCache.ValueFromIndex[I];
end;

procedure PutCachedHash(const Algo, FilePath, Digest: string);
var
  Key: string;
  I: Integer;
begin
  InitHashCache;
  Key := MakeHashCacheKey(Algo, FilePath);
  I := HashCache.IndexOfName(Key);
  if I >= 0 then
    HashCache.ValueFromIndex[I] := Digest
  else
    HashCache.Add(Key + '=' + Digest);
end;

procedure PrintUsage;
begin
  Writeln('Usage:');
  Writeln('  sort [options] [files and directories]');
  Writeln;
  Writeln('Options:');
  Writeln('  --Help');
  Writeln('      Print this help.');
  Writeln;
  Writeln('  --SelfTest');
  Writeln('      Run built-in MIME/filter/path self-tests and exit.');
  Writeln;
  Writeln('  --Probe');
  Writeln('      Check whether the computed target file is an exact copy.');
  Writeln;
  Writeln('  --Mode=[dummy|copy|move|compare|find|delete|destroy]');
  Writeln('      dummy   : dry-run only, print planned actions');
  Writeln('      copy    : copy source file to computed target path');
  Writeln('      move    : move source file to computed target path');
  Writeln('      compare : report whether source and target are exact matches');
  Writeln('      find    : print only target paths that exactly match the source');
  Writeln('      delete  : move matching target files into TARGET/DELETE/');
  Writeln('      destroy : permanently delete matching target files');
  Writeln;
  Writeln('  --Type=[string[,string...]]');
  Writeln('      Process only matching MIME, MIME main type, or MIME subtype.');
  Writeln('      Multiple values are allowed, separated by commas: image,json,text');
  Writeln;
  Writeln('  --Recursive');
  Writeln('      Recurse into subdirectories.');
  Writeln;
  Writeln('  --Replace');
  Writeln('      Confirm once at startup, then replace existing target files.');
  Writeln;
  Writeln('  --Dirs=[item[,item...]]');
  Writeln('      Items: mime, mime-main, mime-sub, extension, md5sum, sha...sum, random[length]');
  Writeln;
  Writeln('  --SubDirs=[item[,item...]]');
  Writeln('      Items: format, size, format[sep]size, date[:year][:month][:day], random[length]');
  Writeln;
  Writeln('  --Rename=[original|long|md5sum|sha...sum|time[:hour][:minute][:second][:milliseconds]|random[length]|name]');
  Writeln;
  Writeln('  --Extension=[original|mime|mime-main|mime-sub|random[length]|ext]');
  Writeln;
  Writeln('  --Target=[directory]');
  Writeln('      If the directory exists, it is used as-is.');
  Writeln('      Otherwise it is created under the current working directory.');
end;

function LowerTrim(const S: string): string;
begin
  Result := LowerCase(Trim(S));
end;

function IsSwitch(const S: string): Boolean;
begin
  Result := (Length(S) >= 2) and (S[1] = '-') and (S[2] = '-');
end;

function SplitOption(const Arg: string; out Key, Value: string): Boolean;
var
  P: SizeInt;
begin
  Result := False;
  Key := '';
  Value := '';
  if not IsSwitch(Arg) then
    Exit;
  P := Pos('=', Arg);
  if P > 0 then
  begin
    Key := Copy(Arg, 3, P - 3);
    Value := Copy(Arg, P + 1, MaxInt);
  end
  else
    Key := Copy(Arg, 3, MaxInt);
  Result := True;
end;

function ParseMode(const S: string; out Mode: TMode): Boolean;
var
  V: string;
begin
  V := LowerTrim(S);
  Result := True;
  if V = 'dummy' then Mode := moDummy
  else if V = 'copy' then Mode := moCopy
  else if V = 'move' then Mode := moMove
  else if V = 'compare' then Mode := moCompare
  else if V = 'find' then Mode := moFind
  else if V = 'delete' then Mode := moDelete
  else if V = 'destroy' then Mode := moDestroy
  else Result := False;
end;

function ExpandToAbsolute(const Path: string): string;
begin
  if Path = '' then
    Exit('');
  Result := ExpandFileName(Path);
end;

function EnsureDirExists(const DirPath: string): Boolean;
begin
  if DirPath = '' then
    Exit(False);
  if DirectoryExists(DirPath) then
    Exit(True);
  Result := ForceDirectories(DirPath);
end;

function FileNameNoExt(const Path: string): string;
begin
  Result := ChangeFileExt(ExtractFileName(Path), '');
end;

function FileExtNoDot(const Path: string): string;
var
  E: string;
begin
  E := ExtractFileExt(Path);
  if (E <> '') and (E[1] = '.') then
    Delete(E, 1, 1);
  Result := E;
end;

function JoinPath2(const A, B: string): string;
begin
  if A = '' then
    Result := B
  else if B = '' then
    Result := A
  else
    Result := IncludeTrailingPathDelimiter(A) + B;
end;

function RandomString(ALength: Integer): string;
const
  CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
var
  I: Integer;
begin
  if ALength <= 0 then
    ALength := 4;
  SetLength(Result, ALength);
  for I := 1 to ALength do
    Result[I] := CHARS[Random(Length(CHARS)) + 1];
end;

function IsRandomSpec(const S: string; out N: Integer): Boolean;
var
  V: string;
  P1, P2: Integer;
begin
  Result := False;
  N := 0;
  V := LowerTrim(S);
  if not StartsText('random', V) then
    Exit;
  P1 := Pos('[', V);
  P2 := Pos(']', V);
  if (P1 > 0) and (P2 > P1) then
    N := StrToIntDef(Copy(V, P1 + 1, P2 - P1 - 1), 0);
  Result := True;
end;

function IsTimeSpec(const S: string): Boolean;
begin
  Result := StartsText('time', LowerTrim(S));
end;

function IsDateSpec(const S: string): Boolean;
begin
  Result := StartsText('date', LowerTrim(S));
end;

function IsHashSpec(const S: string): Boolean;
var
  V: string;
begin
  V := LowerTrim(S);
  Result := (V = 'md5sum') or EndsText('sum', V);
end;

function SplitSpecList(const Spec: string): TStringList;
var
  Parts: TStringList;
  I: Integer;
  Item: string;
begin
  Result := TStringList.Create;
  Result.StrictDelimiter := True;
  Result.Delimiter := ',';

  if Trim(Spec) = '' then
    Exit;

  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ',';
    Parts.DelimitedText := Spec;
    for I := 0 to Parts.Count - 1 do
    begin
      Item := Trim(Parts[I]);
      if Item <> '' then
        Result.Add(Item);
    end;
  finally
    Parts.Free;
  end;
end;

function FileSizeInt64(const FilePath: string): Int64;
var
  Info: TSearchRec;
begin
  Result := -1;
  if FindFirst(FilePath, faAnyFile, Info) = 0 then
  begin
    Result := Info.Size;
    FindClose(Info);
  end;
end;

function SizeBucket(const FilePath: string): string;
var
  S: Int64;
begin
  S := FileSizeInt64(FilePath);
  if S < 0 then Result := 'UNKNOWN'
  else if S < 1024 then Result := 'BYTE'
  else if S < 1024 * 1024 then Result := 'KILO'
  else if S < 1024 * 1024 * 1024 then Result := 'MEGA'
  else if S < Int64(1024) * 1024 * 1024 * 1024 then Result := 'GIGA'
  else Result := 'TERA';
end;

function ExactSizeLabel(const FilePath: string): string;
var
  S: Int64;
begin
  S := FileSizeInt64(FilePath);
  if S < 0 then
    Exit('UNKNOWN');

  if S < 1024 then
    Result := IntToStr(S) + 'B'
  else if S < 1024 * 1024 then
    Result := IntToStr(S div 1024) + 'KIB'
  else if S < 1024 * 1024 * 1024 then
    Result := IntToStr(S div (1024 * 1024)) + 'MIB'
  else if S < Int64(1024) * 1024 * 1024 * 1024 then
    Result := IntToStr(S div (1024 * 1024 * 1024)) + 'GIB'
  else
    Result := IntToStr(S div (Int64(1024) * 1024 * 1024 * 1024)) + 'TIB';
end;

function FileDateTime(const FilePath: string): TDateTime;
var
  Info: TSearchRec;
begin
  Result := 0;
  if FindFirst(FilePath, faAnyFile, Info) = 0 then
  begin
    Result := FileDateToDateTime(Info.Time);
    FindClose(Info);
  end;
end;

function BuildDateToken(const Spec, FilePath: string): string;
var
  V: string;
  DT: TDateTime;
  Y, M, D: Word;
begin
  V := LowerTrim(Spec);
  DT := FileDateTime(FilePath);
  DecodeDate(DT, Y, M, D);

  if Pos(':', V) = 0 then
    Result := Format('%.4d-%.2d-%.2d', [Y, M, D])
  else
  begin
    Result := '';
    if Pos(':year', V) > 0 then
      Result := Result + Format('%.4d', [Y]);
    if Pos(':month', V) > 0 then
    begin
      if Result <> '' then Result := Result + '-';
      Result := Result + Format('%.2d', [M]);
    end;
    if Pos(':day', V) > 0 then
    begin
      if Result <> '' then Result := Result + '-';
      Result := Result + Format('%.2d', [D]);
    end;
    if Result = '' then
      Result := Format('%.4d-%.2d-%.2d', [Y, M, D]);
  end;

  Result := UpperCase(Result);
end;

function BuildTimeToken(const Spec: string): string;
var
  V: string;
  H, N, S, MS: Word;
  NowDT: TDateTime;
  Added: Boolean;
begin
  V := LowerTrim(Spec);
  NowDT := Now;
  DecodeTime(NowDT, H, N, S, MS);

  Added := False;
  Result := '';

  if Pos(':', V) = 0 then
    Exit(Format('%.2d:%.2d:%.2d', [H, N, S]));

  if Pos(':hour', V) > 0 then
  begin
    Result := Result + Format('%.2d', [H]);
    Added := True;
  end;
  if Pos(':minute', V) > 0 then
  begin
    if Added then Result := Result + ':';
    Result := Result + Format('%.2d', [N]);
    Added := True;
  end;
  if Pos(':second', V) > 0 then
  begin
    if Added then Result := Result + ':';
    Result := Result + Format('%.2d', [S]);
    Added := True;
  end;
  if (Pos(':milliseconds', V) > 0) or (Pos(':ms', V) > 0) then
  begin
    if Added then Result := Result + ':';
    Result := Result + Format('%.3d', [MS]);
  end;
end;

function ParseHexSignature(const S: string; out Bytes: array of Integer; out Count: Integer): Boolean;
var
  Parts: TStringList;
  I: Integer;
  Token: string;
begin
  Result := False;
  Count := 0;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ' ';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := Trim(S);
    if (Parts.Count = 0) or (Parts.Count > Length(Bytes)) then
      Exit;
    for I := 0 to Parts.Count - 1 do
    begin
      Token := UpperCase(Trim(Parts[I]));
      if Token = '??' then
        Bytes[I] := 256
      else
        Bytes[I] := StrToInt('$' + Token);
    end;
    Count := Parts.Count;
    Result := True;
  finally
    Parts.Free;
  end;
end;

function ReadFileBytes(const FilePath: string; Offset, Count: Integer; out Buffer: TBytes): Boolean;
var
  FS: TFileStream;
  ReadCount: Integer;
begin
  Result := False;
  SetLength(Buffer, 0);

  if (Offset < 0) or (Count <= 0) or (not FileExists(FilePath)) then
    Exit;

  FS := nil;
  try
    FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
    if Offset >= FS.Size then
      Exit;
    FS.Position := Offset;
    SetLength(Buffer, Count);
    ReadCount := FS.Read(Buffer[0], Count);
    if ReadCount <> Count then
      Exit;
    Result := True;
  finally
    FS.Free;
  end;
end;

function FileMatchesHexSignature(const FilePath, HexSignature: string; Offset: Integer): Boolean;
var
  Parsed: array[0..255] of Integer;
  ParsedCount: Integer;
  Buffer: TBytes;
  I: Integer;
begin
  Result := False;
  if not ParseHexSignature(HexSignature, Parsed, ParsedCount) then
    Exit;
  if not ReadFileBytes(FilePath, Offset, ParsedCount, Buffer) then
    Exit;
  for I := 0 to ParsedCount - 1 do
  begin
    if Parsed[I] = 256 then
      Continue;
    if Buffer[I] <> Byte(Parsed[I]) then
      Exit(False);
  end;
  Result := True;
end;

function MimeFromExtension(const Ext: string): string;
var
  E: string;
begin
  E := LowerCase(Ext);

  if (E = 'txt') or (E = 'text') or (E = 'log') or (E = 'md') or (E = 'markdown') then Result := 'text/plain'
  else if E = 'csv' then Result := 'text/csv'
  else if E = 'tsv' then Result := 'text/tab-separated-values'
  else if (E = 'html') or (E = 'htm') then Result := 'text/html'
  else if E = 'css' then Result := 'text/css'
  else if (E = 'js') or (E = 'mjs') then Result := 'text/javascript'
  else if E = 'xml' then Result := 'application/xml'
  else if E = 'json' then Result := 'application/json'
  else if (E = 'yaml') or (E = 'yml') then Result := 'application/yaml'
  else if E = 'toml' then Result := 'application/toml'
  else if (E = 'ini') or (E = 'cfg') or (E = 'conf') then Result := 'text/plain'
  else if (E = 'bat') or (E = 'cmd') then Result := 'text/x-script'
  else if (E = 'sh') or (E = 'bash') or (E = 'zsh') or (E = 'fish') then Result := 'text/x-script'
  else if E = 'py' then Result := 'text/x-python'
  else if (E = 'pas') or (E = 'pp') or (E = 'lpr') then Result := 'text/x-pascal'
  else if (E = 'c') or (E = 'h') then Result := 'text/x-c'
  else if (E = 'cpp') or (E = 'cxx') or (E = 'cc') or (E = 'hpp') then Result := 'text/x-c++'
  else if E = 'java' then Result := 'text/x-java'
  else if E = 'cs' then Result := 'text/x-csharp'
  else if E = 'go' then Result := 'text/x-go'
  else if E = 'rs' then Result := 'text/x-rust'
  else if E = 'php' then Result := 'text/x-php'
  else if E = 'sql' then Result := 'text/x-sql'
  else if E = 'tex' then Result := 'text/x-tex'
  else if E = 'rtf' then Result := 'application/rtf'
  else if E = 'svg' then Result := 'image/svg+xml'
  else if (E = 'jpg') or (E = 'jpeg') then Result := 'image/jpeg'
  else if E = 'png' then Result := 'image/png'
  else if E = 'gif' then Result := 'image/gif'
  else if (E = 'bmp') or (E = 'dib') then Result := 'image/bmp'
  else if E = 'webp' then Result := 'image/webp'
  else if E = 'pdf' then Result := 'application/pdf'
  else if E = 'zip' then Result := 'application/zip'
  else if E = 'gz' then Result := 'application/gzip'
  else if E = 'tar' then Result := 'application/x-tar'
  else if E = '7z' then Result := 'application/x-7z-compressed'
  else if E = 'rar' then Result := 'application/vnd.rar'
  else if E = 'mp3' then Result := 'audio/mpeg'
  else if E = 'wav' then Result := 'audio/wav'
  else if E = 'flac' then Result := 'audio/flac'
  else if E = 'ogg' then Result := 'audio/ogg'
  else if E = 'mp4' then Result := 'video/mp4'
  else if E = 'mkv' then Result := 'video/x-matroska'
  else if E = 'webm' then Result := 'video/webm'
  else if E = 'avi' then Result := 'video/x-msvideo'
  else if E = 'mov' then Result := 'video/quicktime'
  else if E = 'docx' then Result := 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  else if E = 'xlsx' then Result := 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  else if E = 'pptx' then Result := 'application/vnd.openxmlformats-officedocument.presentationml.presentation'
  else if E = 'odt' then Result := 'application/vnd.oasis.opendocument.text'
  else if E = 'ods' then Result := 'application/vnd.oasis.opendocument.spreadsheet'
  else if E = 'odp' then Result := 'application/vnd.oasis.opendocument.presentation'
  else if E = 'jar' then Result := 'application/java-archive'
  else if E = 'apk' then Result := 'application/vnd.android.package-archive'
  else if E = 'epub' then Result := 'application/epub+zip'
  else if (E = 'sqlite') or (E = 'sqlitedb') or (E = 'db') then Result := 'application/vnd.sqlite3'
  else if (E = 'exe') or (E = 'dll') or (E = 'sys') then Result := 'application/vnd.microsoft.portable-executable'
  else if E = 'elf' then Result := 'application/x-elf'
  else Result := '';
end;

function MimeFromDescription(const Description: string): string;
var
  D: string;
begin
  D := LowerCase(Description);
  if Pos('jpeg', D) > 0 then Result := 'image/jpeg'
  else if Pos('png', D) > 0 then Result := 'image/png'
  else if Pos('gif', D) > 0 then Result := 'image/gif'
  else if Pos('bitmap', D) > 0 then Result := 'image/bmp'
  else if Pos('pdf', D) > 0 then Result := 'application/pdf'
  else if Pos('zip', D) > 0 then Result := 'application/zip'
  else if Pos('gzip', D) > 0 then Result := 'application/gzip'
  else if Pos('7-zip', D) > 0 then Result := 'application/x-7z-compressed'
  else if Pos('rar', D) > 0 then Result := 'application/vnd.rar'
  else if Pos('sqlite', D) > 0 then Result := 'application/vnd.sqlite3'
  else if Pos('matroska', D) > 0 then Result := 'video/x-matroska'
  else if Pos('webm', D) > 0 then Result := 'video/webm'
  else if Pos('mpeg-4', D) > 0 then Result := 'video/mp4'
  else if Pos('script', D) > 0 then Result := 'text/x-script'
  else Result := 'application/octet-stream';
end;

function MimeFromRule(const Rule: TMimeRule): string;
var
  I: Integer;
begin
  for I := 0 to Rule.Extensions.Count - 1 do
  begin
    Result := MimeFromExtension(Rule.Extensions[I]);
    if Result <> '' then
      Exit;
  end;
  Result := MimeFromDescription(Rule.Description);
end;

procedure LoadMimeRules;
var
  JsonPath: string;
  JsonStream: TFileStream;
  Root, Data: TJSONData;
  Arr: TJSONArray;
  Obj: TJSONObject;
  I, J: Integer;
  Rule: TMimeRule;
begin
  if MimeRulesLoaded then
    Exit;

  JsonPath := IncludeTrailingPathDelimiter(ExtractFileDir(ParamStr(0))) + 'MIMEs.json';
  if not FileExists(JsonPath) then
    raise Exception.CreateFmt('MIMEs.json not found at: %s', [JsonPath]);

  JsonStream := TFileStream.Create(JsonPath, fmOpenRead or fmShareDenyWrite);
  Root := nil;
  try
    Root := GetJSON(JsonStream);
    if Root.JSONType <> jtArray then
      raise Exception.Create('MIMEs.json must contain a JSON array.');

    Arr := TJSONArray(Root);
    SetLength(MimeRules, Arr.Count);

    for I := 0 to Arr.Count - 1 do
    begin
      Obj := Arr.Objects[I];
      Rule.HexSignatures := TStringList.Create;
      Rule.Offsets := TStringList.Create;
      Rule.Extensions := TStringList.Create;
      Rule.Description := Obj.Get('description', '');

      Data := Obj.FindPath('hex_signature');
      if Assigned(Data) and (Data.JSONType = jtArray) then
        for J := 0 to TJSONArray(Data).Count - 1 do
          Rule.HexSignatures.Add(TJSONArray(Data).Strings[J]);

      Data := Obj.FindPath('offset');
      if Assigned(Data) and (Data.JSONType = jtArray) then
        for J := 0 to TJSONArray(Data).Count - 1 do
          Rule.Offsets.Add(TJSONArray(Data).Strings[J]);

      Data := Obj.FindPath('extensions');
      if Assigned(Data) and (Data.JSONType = jtArray) then
        for J := 0 to TJSONArray(Data).Count - 1 do
          Rule.Extensions.Add(TJSONArray(Data).Strings[J]);

      MimeRules[I] := Rule;
    end;

    MimeRulesLoaded := True;
  finally
    Root.Free;
    JsonStream.Free;
  end;
end;

function IsLikelyTextByte(B: Byte): Boolean;
begin
  Result := (B = 9) or (B = 10) or (B = 13) or ((B >= 32) and (B <= 126)) or (B >= 128);
end;

function IsLikelyTextFile(const FilePath: string): Boolean;
var
  FS: TFileStream;
  Buffer: array[0..4095] of Byte;
  ReadCount, I: Integer;
begin
  Result := False;
  FS := nil;
  try
    FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
    ReadCount := FS.Read(Buffer, SizeOf(Buffer));
    if ReadCount <= 0 then
      Exit(False);
    for I := 0 to ReadCount - 1 do
    begin
      if Buffer[I] = 0 then
        Exit(False);
      if not IsLikelyTextByte(Buffer[I]) then
        Exit(False);
    end;
    Result := True;
  finally
    FS.Free;
  end;
end;

function ReadTextSample(const FilePath: string; MaxBytes: Integer; out Sample: string): Boolean;
var
  FS: TFileStream;
  Buffer: AnsiString;
  ReadCount: Integer;
begin
  Result := False;
  Sample := '';
  if MaxBytes <= 0 then
    Exit;
  FS := nil;
  try
    FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
    if FS.Size = 0 then
      Exit(False);
    if FS.Size < MaxBytes then
      MaxBytes := FS.Size;
    SetLength(Buffer, MaxBytes);
    ReadCount := FS.Read(Buffer[1], MaxBytes);
    if ReadCount <= 0 then
      Exit(False);
    SetLength(Buffer, ReadCount);
    Sample := Buffer;
    Result := True;
  finally
    FS.Free;
  end;
end;

function TrimLeadingText(const S: string): string;
var
  I: Integer;
begin
  I := 1;
  while (I <= Length(S)) and (S[I] <= ' ') do
    Inc(I);
  Result := Copy(S, I, MaxInt);
end;

function LooksLikeJson(const S: string): Boolean;
var
  T: string;
  I: Integer;
begin
  T := TrimLeadingText(S);
  if T = '' then
    Exit(False);

  if T[1] = '{' then
  begin
    I := 2;
    while (I <= Length(T)) and (T[I] <= ' ') do
      Inc(I);
    Result := (I > Length(T)) or (T[I] in ['"', '}']);
    Exit;
  end;

  if T[1] = '[' then
  begin
    I := 2;
    while (I <= Length(T)) and (T[I] <= ' ') do
      Inc(I);
    Result := (I > Length(T)) or (T[I] in ['"', '{', ']', '-', '0'..'9']);
    Exit;
  end;

  Result := False;
end;

function LooksLikeXml(const S: string): Boolean;
var
  T: string;
  P: Integer;
begin
  T := TrimLeadingText(S);
  if AnsiStartsText('<?xml', T) then
    Exit(True);
  if (Length(T) < 3) or (T[1] <> '<') then
    Exit(False);
  if not (T[2] in ['A'..'Z', 'a'..'z', '_', ':']) then
    Exit(False);
  P := Pos('>', T);
  Result := P > 2;
end;

function LooksLikeHtml(const S: string): Boolean;
var
  T: string;
begin
  T := LowerCase(TrimLeadingText(S));
  Result :=
    AnsiStartsText('<!doctype html', T) or
    AnsiStartsText('<html', T) or
    AnsiStartsText('<head', T) or
    AnsiStartsText('<body', T) or
    AnsiStartsText('<meta', T) or
    AnsiStartsText('<title', T) or
    AnsiStartsText('<script', T) or
    AnsiStartsText('<style', T) or
    AnsiStartsText('<div', T) or
    AnsiStartsText('<span', T) or
    AnsiStartsText('<p', T) or
    AnsiStartsText('<a ', T);
end;

function LooksLikeYaml(const S: string): Boolean;
var
  T: string;
  Lines: TStringList;
  I: Integer;
  LineText: string;
  KeyPos: Integer;
  KeyName: string;
  MatchCount: Integer;
begin
  Result := False;
  T := TrimLeadingText(S);
  if T = '' then
    Exit(False);
  if AnsiStartsText('---', T) then
    Exit(True);

  Lines := TStringList.Create;
  try
    Lines.Text := StringReplace(T, #13, '', [rfReplaceAll]);
    MatchCount := 0;
    for I := 0 to Lines.Count - 1 do
    begin
      LineText := Trim(Lines[I]);
      if LineText = '' then
        Continue;
      if LineText[1] = '#' then
        Continue;

      if (Length(LineText) >= 2) and (Copy(LineText, 1, 2) = '- ') then
      begin
        Inc(MatchCount);
        Continue;
      end;

      KeyPos := Pos(':', LineText);
      if KeyPos > 1 then
      begin
        KeyName := Trim(Copy(LineText, 1, KeyPos - 1));
        if (KeyName <> '') and
           (Pos('{', LineText) = 0) and (Pos('}', LineText) = 0) and
           (Pos('[', LineText) = 0) and (Pos(']', LineText) = 0) then
        begin
          Inc(MatchCount);
          Continue;
        end;
      end;

      if MatchCount = 0 then
        Exit(False);
    end;
    Result := MatchCount >= 2;
  finally
    Lines.Free;
  end;
end;

function LooksLikeShellScript(const S: string): Boolean;
var
  T, L: string;
  Lines: TStringList;
  I: Integer;
  MatchCount: Integer;
begin
  Result := False;
  T := TrimLeadingText(S);
  if T = '' then
    Exit(False);

  L := LowerCase(T);

  if AnsiStartsText('#!/bin/sh', L) or
     AnsiStartsText('#!/usr/bin/sh', L) or
     AnsiStartsText('#!/bin/bash', L) or
     AnsiStartsText('#!/usr/bin/bash', L) or
     AnsiStartsText('#!/usr/bin/env bash', L) or
     AnsiStartsText('#!/bin/zsh', L) or
     AnsiStartsText('#!/usr/bin/zsh', L) or
     AnsiStartsText('#!/usr/bin/env zsh', L) or
     AnsiStartsText('#!/bin/dash', L) or
     AnsiStartsText('#!/usr/bin/env sh', L) then
    Exit(True);

  Lines := TStringList.Create;
  try
    Lines.Text := StringReplace(T, #13, '', [rfReplaceAll]);
    MatchCount := 0;

    for I := 0 to Lines.Count - 1 do
    begin
      L := Trim(LowerCase(Lines[I]));
      if L = '' then
        Continue;
      if L[1] = '#' then
        Continue;

      if AnsiStartsText('if [', L) or
         AnsiStartsText('if test ', L) or
         AnsiStartsText('for ', L) or
         AnsiStartsText('while ', L) or
         AnsiStartsText('case ', L) or
         AnsiStartsText('function ', L) or
         AnsiStartsText('export ', L) then
        Inc(MatchCount)
      else if (L = 'then') or (L = 'do') or (L = 'done') or (L = 'fi') or (L = 'esac') then
        Inc(MatchCount);

      if MatchCount >= 2 then
        Exit(True);
    end;

    Result := False;
  finally
    Lines.Free;
  end;
end;

function SniffStructuredTextMime(const FilePath: string): string;
var
  Sample: string;
begin
  Result := '';
  if not IsLikelyTextFile(FilePath) then
    Exit;
  if not ReadTextSample(FilePath, 8192, Sample) then
    Exit;

  if LooksLikeHtml(Sample) then Exit('text/html');
  if LooksLikeJson(Sample) then Exit('application/json');
  if LooksLikeXml(Sample) then Exit('application/xml');
  if LooksLikeYaml(Sample) then Exit('application/yaml');
  if LooksLikeShellScript(Sample) then Exit('text/x-script');
end;

function SniffTextMime(const FilePath: string): string;
var
  ExtMime, Ext, StructuredMime: string;
begin
  Ext := FileExtNoDot(FilePath);
  ExtMime := MimeFromExtension(Ext);
  if ExtMime <> '' then
    Exit(ExtMime);

  StructuredMime := SniffStructuredTextMime(FilePath);
  if StructuredMime <> '' then
    Exit(StructuredMime);

  if IsLikelyTextFile(FilePath) then
    Exit('text/plain');

  Result := '';
end;

function FindMime(const FilePath: string): string;
var
  I, J, OffsetValue: Integer;
  OffsetText, NormalizedPath, FallbackMime: string;
begin
  NormalizedPath := ExpandFileName(FilePath);

  Result := GetCachedMime(NormalizedPath);
  if Result <> '' then
    Exit;

  LoadMimeRules;
  for I := 0 to High(MimeRules) do
  begin
    for J := 0 to MimeRules[I].HexSignatures.Count - 1 do
    begin
      if J < MimeRules[I].Offsets.Count then
        OffsetText := MimeRules[I].Offsets[J]
      else if MimeRules[I].Offsets.Count > 0 then
        OffsetText := MimeRules[I].Offsets[0]
      else
        OffsetText := '0';

      OffsetValue := StrToIntDef(Trim(OffsetText), 0);

      if FileMatchesHexSignature(NormalizedPath, MimeRules[I].HexSignatures[J], OffsetValue) then
      begin
        Result := MimeFromRule(MimeRules[I]);
        if Result = '' then
          Result := 'application/octet-stream';
        PutCachedMime(NormalizedPath, Result);
        Exit;
      end;
    end;
  end;

  FallbackMime := SniffTextMime(NormalizedPath);
  if FallbackMime <> '' then
    Result := FallbackMime
  else
    Result := 'application/octet-stream';

  PutCachedMime(NormalizedPath, Result);
end;

function MimeMain(const Mime: string): string;
var
  P: Integer;
begin
  P := Pos('/', Mime);
  if P > 0 then
    Result := Copy(Mime, 1, P - 1)
  else
    Result := Mime;
end;

function MimeSub(const Mime: string): string;
var
  P: Integer;
begin
  P := Pos('/', Mime);
  if P > 0 then
    Result := Copy(Mime, P + 1, MaxInt)
  else
    Result := Mime;
end;

function MatchesOneTypeFilter(const Mime, FilterValue: string): Boolean;
var
  MainT, SubT, F: string;
begin
  F := LowerTrim(FilterValue);
  if F = '' then
    Exit(False);

  MainT := LowerCase(MimeMain(Mime));
  SubT := LowerCase(MimeSub(Mime));
  Result := (F = LowerCase(Mime)) or (F = MainT) or (F = SubT);
end;

function MatchesTypeFilter(const FilePath, TypeFilter: string): Boolean;
var
  Mime: string;
  Parts: TStringList;
  I: Integer;
  Item: string;
begin
  if Trim(TypeFilter) = '' then
    Exit(True);

  Mime := LowerCase(FindMime(FilePath));
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ',';
    Parts.DelimitedText := TypeFilter;
    for I := 0 to Parts.Count - 1 do
    begin
      Item := Trim(Parts[I]);
      if MatchesOneTypeFilter(Mime, Item) then
        Exit(True);
    end;
    Result := False;
  finally
    Parts.Free;
  end;
end;

function ReadProcessOutput(const ExePath: string; const Args: array of string; out OutputText: string): Boolean;
var
  P: TProcess;
  SL: TStringList;
  I: Integer;
begin
  Result := False;
  OutputText := '';
  P := TProcess.Create(nil);
  SL := TStringList.Create;
  try
    P.Executable := ExePath;
    for I := Low(Args) to High(Args) do
      P.Parameters.Add(Args[I]);
    P.Options := [poUsePipes, poWaitOnExit];
    P.Execute;
    SL.LoadFromStream(P.Output);
    OutputText := Trim(SL.Text);
    Result := P.ExitStatus = 0;
  finally
    SL.Free;
    P.Free;
  end;
end;

function MD5HexOfFile(const FilePath: string): string;
begin
  Result := MD5Print(MD5File(FilePath));
end;

function ExternalHashOfFile(const Algo, FilePath: string): string;
var
  OutText, ToolName: string;
  P: Integer;
begin
  Result := '';
  ToolName := LowerTrim(Algo);
  if not EndsText('sum', ToolName) then
    Exit;
  if ReadProcessOutput(ToolName, [FilePath], OutText) then
  begin
    P := Pos(' ', OutText);
    if P > 1 then
      Result := Copy(OutText, 1, P - 1)
    else
      Result := OutText;
  end;
end;

function HashOfFile(const Kind, FilePath: string): string;
var
  K, NormalizedPath: string;
begin
  K := LowerTrim(Kind);
  NormalizedPath := ExpandFileName(FilePath);

  Result := GetCachedHash(K, NormalizedPath);
  if Result <> '' then
    Exit;

  if K = 'md5sum' then
    Result := LowerCase(MD5HexOfFile(NormalizedPath))
  else
    Result := LowerCase(ExternalHashOfFile(K, NormalizedPath));

  PutCachedHash(K, NormalizedPath, Result);
end;

function ReadBE32(const B: TBytes; Index: Integer): Cardinal;
begin
  Result :=
    (Cardinal(B[Index]) shl 24) or
    (Cardinal(B[Index + 1]) shl 16) or
    (Cardinal(B[Index + 2]) shl 8) or
    Cardinal(B[Index + 3]);
end;

function ReadLE16(const B: TBytes; Index: Integer): Word;
begin
  Result := Word(B[Index]) or (Word(B[Index + 1]) shl 8);
end;

function ReadLE32(const B: TBytes; Index: Integer): Cardinal;
begin
  Result :=
    Cardinal(B[Index]) or
    (Cardinal(B[Index + 1]) shl 8) or
    (Cardinal(B[Index + 2]) shl 16) or
    (Cardinal(B[Index + 3]) shl 24);
end;

function IsImageMime(const Mime: string): Boolean;
begin
  Result := SameText(MimeMain(Mime), 'image');
end;

function IsVideoMime(const Mime: string): Boolean;
begin
  Result := SameText(MimeMain(Mime), 'video');
end;

function GetPngDimensions(const FilePath: string; out Width, Height: Integer): Boolean;
var
  B: TBytes;
begin
  Result := False;
  Width := 0;
  Height := 0;
  if not ReadFileBytes(FilePath, 0, 24, B) then
    Exit;
  if Length(B) < 24 then
    Exit;
  if not (
    (B[0] = $89) and (B[1] = $50) and (B[2] = $4E) and (B[3] = $47) and
    (B[4] = $0D) and (B[5] = $0A) and (B[6] = $1A) and (B[7] = $0A)
  ) then
    Exit;
  Width := Integer(ReadBE32(B, 16));
  Height := Integer(ReadBE32(B, 20));
  Result := (Width > 0) and (Height > 0);
end;

function GetGifDimensions(const FilePath: string; out Width, Height: Integer): Boolean;
var
  B: TBytes;
begin
  Result := False;
  Width := 0;
  Height := 0;
  if not ReadFileBytes(FilePath, 0, 10, B) then
    Exit;
  if Length(B) < 10 then
    Exit;
  if not (
    (B[0] = Ord('G')) and (B[1] = Ord('I')) and (B[2] = Ord('F')) and
    (B[3] = Ord('8')) and ((B[4] = Ord('7')) or (B[4] = Ord('9'))) and
    (B[5] = Ord('a'))
  ) then
    Exit;
  Width := Integer(ReadLE16(B, 6));
  Height := Integer(ReadLE16(B, 8));
  Result := (Width > 0) and (Height > 0);
end;

function GetBmpDimensions(const FilePath: string; out Width, Height: Integer): Boolean;
var
  B: TBytes;
  RawWidth, RawHeight: LongInt;
begin
  Result := False;
  Width := 0;
  Height := 0;
  if not ReadFileBytes(FilePath, 0, 26, B) then
    Exit;
  if Length(B) < 26 then
    Exit;
  if not ((B[0] = Ord('B')) and (B[1] = Ord('M'))) then
    Exit;
  RawWidth := LongInt(ReadLE32(B, 18));
  RawHeight := LongInt(ReadLE32(B, 22));
  if RawHeight < 0 then
    RawHeight := -RawHeight;
  Width := RawWidth;
  Height := RawHeight;
  Result := (Width > 0) and (Height > 0);
end;

function GetJpegDimensions(const FilePath: string; out Width, Height: Integer): Boolean;
var
  FS: TFileStream;
  B1, B2, Marker, DummyPrecision: Byte;
  SegmentLen: Word;
  TempH, TempW: Word;
begin
  Result := False;
  Width := 0;
  Height := 0;
  FS := nil;
  try
    FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
    if FS.Size < 4 then
      Exit;
    FS.ReadBuffer(B1, 1);
    FS.ReadBuffer(B2, 1);
    if not ((B1 = $FF) and (B2 = $D8)) then
      Exit;

    while FS.Position < FS.Size do
    begin
      FS.ReadBuffer(B1, 1);
      while (B1 <> $FF) and (FS.Position < FS.Size) do
        FS.ReadBuffer(B1, 1);

      repeat
        FS.ReadBuffer(Marker, 1);
      until (Marker <> $FF) or (FS.Position >= FS.Size);

      if (Marker = $D9) or (Marker = $DA) then
        Break;
      if FS.Position + 1 >= FS.Size then
        Break;

      FS.ReadBuffer(B1, 1);
      FS.ReadBuffer(B2, 1);
      SegmentLen := (Word(B1) shl 8) or Word(B2);
      if SegmentLen < 2 then
        Exit;

      if ((Marker >= $C0) and (Marker <= $C3)) or
         ((Marker >= $C5) and (Marker <= $C7)) or
         ((Marker >= $C9) and (Marker <= $CB)) or
         ((Marker >= $CD) and (Marker <= $CF)) then
      begin
        if SegmentLen < 7 then
          Exit;
        FS.ReadBuffer(DummyPrecision, 1);
        FS.ReadBuffer(B1, 1);
        FS.ReadBuffer(B2, 1);
        TempH := (Word(B1) shl 8) or Word(B2);
        FS.ReadBuffer(B1, 1);
        FS.ReadBuffer(B2, 1);
        TempW := (Word(B1) shl 8) or Word(B2);
        Width := TempW;
        Height := TempH;
        Result := (Width > 0) and (Height > 0);
        Exit;
      end
      else
        FS.Position := FS.Position + SegmentLen - 2;
    end;
  finally
    FS.Free;
  end;
end;

function GetWebpDimensions(const FilePath: string; out Width, Height: Integer): Boolean;
var
  FS: TFileStream;
  Header: array[0..11] of Byte;
  ChunkHeader: array[0..7] of Byte;
  ChunkName: string;
  ChunkSize: Cardinal;
  B: TBytes;
  W24, H24: Cardinal;
  TmpW, TmpH: Word;
begin
  Result := False;
  Width := 0;
  Height := 0;
  FS := nil;
  try
    FS := TFileStream.Create(FilePath, fmOpenRead or fmShareDenyWrite);
    if FS.Size < 12 then
      Exit;
    FS.ReadBuffer(Header, SizeOf(Header));
    if not (
      (Header[0] = Ord('R')) and (Header[1] = Ord('I')) and
      (Header[2] = Ord('F')) and (Header[3] = Ord('F')) and
      (Header[8] = Ord('W')) and (Header[9] = Ord('E')) and
      (Header[10] = Ord('B')) and (Header[11] = Ord('P'))
    ) then
      Exit;

    while FS.Position + 8 <= FS.Size do
    begin
      FS.ReadBuffer(ChunkHeader, SizeOf(ChunkHeader));
      SetLength(ChunkName, 4);
      ChunkName[1] := Chr(ChunkHeader[0]);
      ChunkName[2] := Chr(ChunkHeader[1]);
      ChunkName[3] := Chr(ChunkHeader[2]);
      ChunkName[4] := Chr(ChunkHeader[3]);

      ChunkSize :=
        Cardinal(ChunkHeader[4]) or
        (Cardinal(ChunkHeader[5]) shl 8) or
        (Cardinal(ChunkHeader[6]) shl 16) or
        (Cardinal(ChunkHeader[7]) shl 24);

      if ChunkName = 'VP8X' then
      begin
        if ChunkSize < 10 then
          Exit;
        SetLength(B, 10);
        FS.ReadBuffer(B[0], 10);
        W24 := Cardinal(B[4]) or (Cardinal(B[5]) shl 8) or (Cardinal(B[6]) shl 16);
        H24 := Cardinal(B[7]) or (Cardinal(B[8]) shl 8) or (Cardinal(B[9]) shl 16);
        Width := Integer(W24) + 1;
        Height := Integer(H24) + 1;
        Exit((Width > 0) and (Height > 0));
      end
      else if ChunkName = 'VP8 ' then
      begin
        if ChunkSize < 10 then
          Exit;
        SetLength(B, 10);
        FS.ReadBuffer(B[0], 10);
        if not ((B[3] = $9D) and (B[4] = $01) and (B[5] = $2A)) then
          Exit;
        TmpW := ReadLE16(B, 6) and $3FFF;
        TmpH := ReadLE16(B, 8) and $3FFF;
        Width := TmpW;
        Height := TmpH;
        Exit((Width > 0) and (Height > 0));
      end
      else if ChunkName = 'VP8L' then
      begin
        if ChunkSize < 5 then
          Exit;
        SetLength(B, 5);
        FS.ReadBuffer(B[0], 5);
        if B[0] <> $2F then
          Exit;
        Width := 1 + (((Integer(B[2]) and $3F) shl 8) or Integer(B[1]));
        Height := 1 + (((Integer(B[4]) and $0F) shl 10) or (Integer(B[3]) shl 2) or ((Integer(B[2]) and $C0) shr 6));
        Exit((Width > 0) and (Height > 0));
      end
      else
        FS.Position := FS.Position + ChunkSize;

      if Odd(ChunkSize) and (FS.Position < FS.Size) then
        FS.Position := FS.Position + 1;
    end;
  finally
    FS.Free;
  end;
end;

function TryGetMediaDimensions(const FilePath: string; out Width, Height: Integer): Boolean;
var
  Mime: string;
begin
  Width := 0;
  Height := 0;
  Mime := FindMime(FilePath);

  if IsImageMime(Mime) then
  begin
    if SameText(Mime, 'image/png') then Exit(GetPngDimensions(FilePath, Width, Height));
    if SameText(Mime, 'image/gif') then Exit(GetGifDimensions(FilePath, Width, Height));
    if SameText(Mime, 'image/bmp') then Exit(GetBmpDimensions(FilePath, Width, Height));
    if SameText(Mime, 'image/jpeg') then Exit(GetJpegDimensions(FilePath, Width, Height));
    if SameText(Mime, 'image/webp') then Exit(GetWebpDimensions(FilePath, Width, Height));
  end;

  Result := False;
end;

function BuildDirToken(const Spec, FilePath: string): string;
var
  V, Mime, MainT, SubT, ExtS: string;
  N: Integer;
begin
  V := LowerTrim(Spec);
  if V = '' then
    Exit('');

  Mime := FindMime(FilePath);
  MainT := MimeMain(Mime);
  SubT := MimeSub(Mime);
  ExtS := FileExtNoDot(FilePath);

  if V = 'mime' then Result := UpperCase(Mime)
  else if V = 'mime-main' then Result := UpperCase(MainT)
  else if V = 'mime-sub' then Result := UpperCase(SubT)
  else if V = 'extension' then Result := UpperCase(ExtS)
  else if IsHashSpec(V) then Result := UpperCase(HashOfFile(V, FilePath))
  else if IsRandomSpec(V, N) then
  begin
    if N <= 0 then N := 4;
    Result := UpperCase(RandomString(N));
  end
  else
    Result := UpperCase(V);
end;

function ParseSubDirFormatSpec(const Spec: string; out Sep: string): Boolean;
var
  V: string;
  P1, P2: Integer;
begin
  V := LowerTrim(Spec);
  Result := StartsText('format', V) and (Pos('size', V) > 0);
  Sep := '_';
  if not Result then
    Exit;
  P1 := Pos('[', V);
  P2 := Pos(']', V);
  if (P1 > 0) and (P2 > P1) then
    Sep := Copy(V, P1 + 1, P2 - P1 - 1);
end;

function MediaFormatLabel(const FilePath: string): string;
var
  W, H: Integer;
begin
  if TryGetMediaDimensions(FilePath, W, H) then
  begin
    if W > H then Exit('WIDE')
    else if H > W then Exit('TALL')
    else Exit('SQUARE');
  end;
  Result := SizeBucket(FilePath);
end;

function MediaSizeLabel(const FilePath: string): string;
var
  W, H: Integer;
begin
  if TryGetMediaDimensions(FilePath, W, H) then
    Exit(Format('%dx%d', [W, H]));
  Result := ExactSizeLabel(FilePath);
end;

function BuildSubDirToken(const Spec, FilePath: string): string;
var
  V, Sep: string;
  N: Integer;
begin
  V := LowerTrim(Spec);
  if V = '' then
    Exit('');

  if V = 'format' then
    Result := UpperCase(MediaFormatLabel(FilePath))
  else if V = 'size' then
    Result := UpperCase(MediaSizeLabel(FilePath))
  else if ParseSubDirFormatSpec(V, Sep) then
    Result := UpperCase(MediaFormatLabel(FilePath) + Sep + MediaSizeLabel(FilePath))
  else if IsDateSpec(V) then
    Result := BuildDateToken(V, FilePath)
  else if IsRandomSpec(V, N) then
  begin
    if N <= 0 then N := 4;
    Result := UpperCase(RandomString(N));
  end
  else
    Result := UpperCase(V);
end;

function BuildDirPath(const Spec, FilePath: string): string;
var
  Parts: TStringList;
  I: Integer;
  Token: string;
begin
  Result := '';
  Parts := SplitSpecList(Spec);
  try
    for I := 0 to Parts.Count - 1 do
    begin
      Token := BuildDirToken(Parts[I], FilePath);
      if Token <> '' then
        Result := JoinPath2(Result, Token);
    end;
  finally
    Parts.Free;
  end;
end;

function BuildSubDirPath(const Spec, FilePath: string): string;
var
  Parts: TStringList;
  I: Integer;
  Token: string;
begin
  Result := '';
  Parts := SplitSpecList(Spec);
  try
    for I := 0 to Parts.Count - 1 do
    begin
      Token := BuildSubDirToken(Parts[I], FilePath);
      if Token <> '' then
        Result := JoinPath2(Result, Token);
    end;
  finally
    Parts.Free;
  end;
end;

function BuildRenameBase(const Spec, FilePath: string): string;
var
  V, Mime: string;
  N: Integer;
begin
  V := Trim(Spec);
  Mime := FindMime(FilePath);

  if V = '' then
    Exit(FileNameNoExt(FilePath));

  if SameText(V, 'original') then
    Result := FileNameNoExt(FilePath)
  else if SameText(V, 'long') then
    Result := StringReplace(ExpandToAbsolute(ChangeFileExt(FilePath, '')), PathDelim, '~', [rfReplaceAll])
  else if SameText(V, 'mime') then
    Result := StringReplace(Mime, '/', '_', [rfReplaceAll])
  else if SameText(V, 'mime-main') then
    Result := MimeMain(Mime)
  else if SameText(V, 'mime-sub') then
    Result := MimeSub(Mime)
  else if IsHashSpec(V) then
    Result := HashOfFile(V, FilePath)
  else if IsTimeSpec(V) then
    Result := StringReplace(BuildTimeToken(V), ':', '-', [rfReplaceAll])
  else if IsRandomSpec(V, N) then
  begin
    if N <= 0 then N := 8;
    Result := RandomString(N);
  end
  else
    Result := V;
end;

function BuildExtension(const Spec, FilePath: string): string;
var
  V, Mime: string;
  N: Integer;
begin
  V := Trim(Spec);
  Mime := FindMime(FilePath);

  if V = '' then
    Exit(FileExtNoDot(FilePath));

  if SameText(V, 'original') then
    Result := FileExtNoDot(FilePath)
  else if SameText(V, 'mime') then
    Result := StringReplace(Mime, '/', '.', [])
  else if SameText(V, 'mime-main') then
    Result := MimeMain(Mime)
  else if SameText(V, 'mime-sub') then
    Result := MimeSub(Mime)
  else if IsRandomSpec(V, N) then
  begin
    if N <= 0 then N := 4;
    Result := LowerCase(RandomString(N));
  end
  else
    Result := V;

  Result := StringReplace(Result, '/', '.', [rfReplaceAll]);
  Result := StringReplace(Result, '\', '.', [rfReplaceAll]);
  Result := StringReplace(Result, ':', '.', [rfReplaceAll]);
end;

function ComputeTargetRoot(const Opts: TOptions): string;
var
  Candidate: string;
begin
  if Trim(Opts.Target) = '' then
    Exit(GetCurrentDir);

  Candidate := ExpandToAbsolute(Opts.Target);
  if DirectoryExists(Candidate) then
    Result := Candidate
  else
    Result := ExpandFileName(IncludeTrailingPathDelimiter(GetCurrentDir) + Trim(Opts.Target));
end;

function ComputeTargetFile(const Opts: TOptions; const SourceFile: string): string;
var
  RootDir, DirPath, SubDirPath, BaseName, ExtName, FinalDir: string;
begin
  RootDir := ComputeTargetRoot(Opts);
  DirPath := BuildDirPath(Opts.DirsSpec, SourceFile);
  SubDirPath := BuildSubDirPath(Opts.SubDirsSpec, SourceFile);
  BaseName := BuildRenameBase(Opts.RenameSpec, SourceFile);
  ExtName := BuildExtension(Opts.ExtensionSpec, SourceFile);

  FinalDir := RootDir;
  if DirPath <> '' then
    FinalDir := JoinPath2(FinalDir, DirPath);
  if SubDirPath <> '' then
    FinalDir := JoinPath2(FinalDir, SubDirPath);

  if ExtName <> '' then
    Result := JoinPath2(FinalDir, BaseName + '.' + ExtName)
  else
    Result := JoinPath2(FinalDir, BaseName);
end;

function CopyFileSimple(const Src, Dst: string): Boolean;
var
  InS, OutS: TFileStream;
begin
  Result := False;
  InS := nil;
  OutS := nil;
  try
    InS := TFileStream.Create(Src, fmOpenRead or fmShareDenyWrite);
    EnsureDirExists(ExtractFileDir(Dst));
    OutS := TFileStream.Create(Dst, fmCreate);
    OutS.CopyFrom(InS, 0);
    Result := True;
  finally
    OutS.Free;
    InS.Free;
  end;
end;

function MoveFileSimple(const Src, Dst: string): Boolean;
begin
  EnsureDirExists(ExtractFileDir(Dst));
  if RenameFile(Src, Dst) then
    Exit(True);

  if CopyFileSimple(Src, Dst) then
  begin
    Result := DeleteFile(Src);
    Exit(Result);
  end;

  Result := False;
end;

function FilesAreExactlyEqual(const A, B: string): Boolean;
const
  BUF_SIZE = 65536;
var
  SA, SB: TFileStream;
  BA, BB: array[0..BUF_SIZE - 1] of Byte;
  RA, RB: Integer;
begin
  Result := False;
  if (not FileExists(A)) or (not FileExists(B)) then
    Exit;
  if FileSizeInt64(A) <> FileSizeInt64(B) then
    Exit;

  SA := nil;
  SB := nil;
  try
    SA := TFileStream.Create(A, fmOpenRead or fmShareDenyWrite);
    SB := TFileStream.Create(B, fmOpenRead or fmShareDenyWrite);

    repeat
      RA := SA.Read(BA, SizeOf(BA));
      RB := SB.Read(BB, SizeOf(BB));
      if RA <> RB then
        Exit(False);
      if CompareByte(BA, BB, RA) <> 0 then
        Exit(False);
    until RA = 0;

    Result := True;
  finally
    SA.Free;
    SB.Free;
  end;
end;

procedure AddFile(List: TStringList; const FilePath: string);
begin
  if FileExists(FilePath) then
    List.Add(ExpandToAbsolute(FilePath));
end;

procedure CollectFromDirectory(const DirPath: string; Recursive: Boolean; List: TStringList);
var
  SR: TSearchRec;
  FullPath: string;
begin
  if FindFirst(IncludeTrailingPathDelimiter(DirPath) + '*', faAnyFile, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;

      FullPath := IncludeTrailingPathDelimiter(DirPath) + SR.Name;
      if (SR.Attr and faDirectory) <> 0 then
      begin
        if Recursive then
          CollectFromDirectory(FullPath, Recursive, List);
      end
      else
        AddFile(List, FullPath);
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

function BuildDeleteTarget(const Opts: TOptions; const ExistingTarget: string): string;
var
  RootDir, DeleteRoot, RelativePath: string;
begin
  RootDir := ComputeTargetRoot(Opts);
  DeleteRoot := JoinPath2(RootDir, 'DELETE');

  RelativePath := ExistingTarget;
  if Pos(IncludeTrailingPathDelimiter(RootDir), ExistingTarget) = 1 then
    Delete(RelativePath, 1, Length(IncludeTrailingPathDelimiter(RootDir)));

  Result := JoinPath2(DeleteRoot, RelativePath);
end;

procedure ParseCommandLine(var Opts: TOptions);
var
  I: Integer;
  Arg, Key, Value: string;
begin
  for I := 1 to ParamCount do
  begin
    Arg := ParamStr(I);

    if not SplitOption(Arg, Key, Value) then
    begin
      Opts.Inputs.Add(Arg);
      Continue;
    end;

    Key := LowerTrim(Key);

    if Key = 'help' then
      Opts.ShowHelp := True
    else if Key = 'selftest' then
      Opts.SelfTest := True
    else if Key = 'probe' then
      Opts.Probe := True
    else if Key = 'recursive' then
      Opts.Recursive := True
    else if Key = 'replace' then
      Opts.ReplaceExisting := True
    else if Key = 'mode' then
    begin
      if not ParseMode(Value, Opts.Mode) then
        raise Exception.CreateFmt('Invalid --Mode value: %s', [Value]);
    end
    else if Key = 'type' then
      Opts.TypeFilter := Trim(Value)
    else if Key = 'dirs' then
      Opts.DirsSpec := Trim(Value)
    else if Key = 'subdirs' then
      Opts.SubDirsSpec := Trim(Value)
    else if Key = 'rename' then
      Opts.RenameSpec := Trim(Value)
    else if Key = 'extension' then
      Opts.ExtensionSpec := Trim(Value)
    else if Key = 'target' then
      Opts.Target := Trim(Value)
    else
      raise Exception.CreateFmt('Unknown option: --%s', [Key]);
  end;
end;

function ConfirmReplaceOnce(var Opts: TOptions): Boolean;
var
  Answer: string;
begin
  if not Opts.ReplaceExisting then
    Exit(False);
  if Opts.ReplaceConfirmed then
    Exit(True);

  Write('Replace existing target files? [y/N]: ');
  ReadLn(Answer);
  Opts.ReplaceConfirmed := SameText(Trim(Answer), 'y') or SameText(Trim(Answer), 'yes');
  Result := Opts.ReplaceConfirmed;
end;

function ExpandInputsToFiles(const Opts: TOptions): TStringList;
var
  I: Integer;
  P: string;
begin
  Result := TStringList.Create;
  Result.Sorted := False;
  Result.Duplicates := dupIgnore;

  for I := 0 to Opts.Inputs.Count - 1 do
  begin
    P := ExpandToAbsolute(Opts.Inputs[I]);
    if FileExists(P) then
      AddFile(Result, P)
    else if DirectoryExists(P) then
      CollectFromDirectory(P, Opts.Recursive, Result)
    else
      Writeln('WARN: input not found: ', Opts.Inputs[I]);
  end;
end;

procedure HandleProbe(const SourceFile, TargetFile: string);
begin
  if FileExists(TargetFile) and FilesAreExactlyEqual(SourceFile, TargetFile) then
    Writeln('PROBE MATCH: ', SourceFile, ' == ', TargetFile)
  else
    Writeln('PROBE MISS : ', SourceFile, ' <> ', TargetFile);
end;

procedure HandleDummy(const SourceFile, TargetFile: string);
begin
  Writeln('DUMMY  : ', SourceFile, ' -> ', TargetFile);
end;

procedure HandleCopy(var Opts: TOptions; const SourceFile, TargetFile: string);
begin
  EnsureDirExists(ExtractFileDir(TargetFile));

  if FileExists(TargetFile) then
  begin
    if not ConfirmReplaceOnce(Opts) then
    begin
      Writeln('SKIP   : target exists: ', TargetFile);
      Exit;
    end;
    DeleteFile(TargetFile);
  end;

  if CopyFileSimple(SourceFile, TargetFile) then
    Writeln('COPIED : ', SourceFile, ' -> ', TargetFile)
  else
    Writeln('ERROR  : failed to copy: ', SourceFile, ' -> ', TargetFile);
end;

procedure HandleMove(var Opts: TOptions; const SourceFile, TargetFile: string);
begin
  EnsureDirExists(ExtractFileDir(TargetFile));

  if FileExists(TargetFile) then
  begin
    if not ConfirmReplaceOnce(Opts) then
    begin
      Writeln('SKIP   : target exists: ', TargetFile);
      Exit;
    end;
    DeleteFile(TargetFile);
  end;

  if MoveFileSimple(SourceFile, TargetFile) then
    Writeln('MOVED  : ', SourceFile, ' -> ', TargetFile)
  else
    Writeln('ERROR  : failed to move: ', SourceFile, ' -> ', TargetFile);
end;

procedure HandleCompare(const SourceFile, TargetFile: string);
begin
  if FileExists(TargetFile) and FilesAreExactlyEqual(SourceFile, TargetFile) then
    Writeln('MATCH  : ', TargetFile)
  else
    Writeln('DIFF   : ', TargetFile);
end;

procedure HandleFind(const SourceFile, TargetFile: string);
begin
  if FileExists(TargetFile) and FilesAreExactlyEqual(SourceFile, TargetFile) then
    Writeln(TargetFile);
end;

procedure HandleDelete(var Opts: TOptions; const SourceFile, TargetFile: string);
var
  DeleteTarget: string;
begin
  if not FileExists(TargetFile) then
  begin
    Writeln('MISS   : ', TargetFile);
    Exit;
  end;

  if not FilesAreExactlyEqual(SourceFile, TargetFile) then
  begin
    Writeln('DIFF   : ', TargetFile);
    Exit;
  end;

  DeleteTarget := BuildDeleteTarget(Opts, TargetFile);
  EnsureDirExists(ExtractFileDir(DeleteTarget));

  if FileExists(DeleteTarget) then
  begin
    if not ConfirmReplaceOnce(Opts) then
    begin
      Writeln('SKIP   : delete target exists: ', DeleteTarget);
      Exit;
    end;
    DeleteFile(DeleteTarget);
  end;

  if MoveFileSimple(TargetFile, DeleteTarget) then
    Writeln('DELETED: ', TargetFile, ' -> ', DeleteTarget)
  else
    Writeln('ERROR  : failed delete(move): ', TargetFile);
end;

procedure HandleDestroy(const SourceFile, TargetFile: string);
begin
  if not FileExists(TargetFile) then
  begin
    Writeln('MISS   : ', TargetFile);
    Exit;
  end;

  if not FilesAreExactlyEqual(SourceFile, TargetFile) then
  begin
    Writeln('DIFF   : ', TargetFile);
    Exit;
  end;

  if DeleteFile(TargetFile) then
    Writeln('DESTROY: ', TargetFile)
  else
    Writeln('ERROR  : failed destroy: ', TargetFile);
end;

procedure ProcessFile(var Opts: TOptions; const SourceFile: string);
var
  TargetFile: string;
begin
  if not MatchesTypeFilter(SourceFile, Opts.TypeFilter) then
    Exit;

  TargetFile := ComputeTargetFile(Opts, SourceFile);

  if Opts.Probe then
    HandleProbe(SourceFile, TargetFile);

  case Opts.Mode of
    moDummy: HandleDummy(SourceFile, TargetFile);
    moCopy: HandleCopy(Opts, SourceFile, TargetFile);
    moMove: HandleMove(Opts, SourceFile, TargetFile);
    moCompare: HandleCompare(SourceFile, TargetFile);
    moFind: HandleFind(SourceFile, TargetFile);
    moDelete: HandleDelete(Opts, SourceFile, TargetFile);
    moDestroy: HandleDestroy(SourceFile, TargetFile);
  end;
end;

procedure WriteTextFile(const FilePath, Content: string);
var
  FS: TFileStream;
  S: UTF8String;
begin
  EnsureDirExists(ExtractFileDir(FilePath));
  S := UTF8String(Content);
  FS := TFileStream.Create(FilePath, fmCreate);
  try
    if Length(S) > 0 then
      FS.WriteBuffer(S[1], Length(S));
  finally
    FS.Free;
  end;
end;

procedure DeleteDirectoryTree(const DirPath: string);
var
  SR: TSearchRec;
  FullPath: string;
begin
  if not DirectoryExists(DirPath) then
    Exit;

  if FindFirst(IncludeTrailingPathDelimiter(DirPath) + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;

      FullPath := IncludeTrailingPathDelimiter(DirPath) + SR.Name;
      if (SR.Attr and faDirectory) <> 0 then
        DeleteDirectoryTree(FullPath)
      else
        DeleteFile(FullPath);
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;

  RemoveDir(DirPath);
end;

procedure AddTestCase(Names, Expected: TStringList; const FileName, ExpectedMime: string);
begin
  Names.Add(FileName);
  Expected.Add(ExpectedMime);
end;

procedure CreateSniffFixtures(const RootDir: string; Names, Expected: TStringList);
begin
  EnsureDirExists(RootDir);

  WriteTextFile(JoinPath2(RootDir, 'json_ok'), '{"name":"test","value":1}');
  AddTestCase(Names, Expected, 'json_ok', 'application/json');

  WriteTextFile(JoinPath2(RootDir, 'json_array_ok'),
    '[' + LineEnding +
    '  {"id":1},' + LineEnding +
    '  {"id":2}' + LineEnding +
    ']');
  AddTestCase(Names, Expected, 'json_array_ok', 'application/json');

  WriteTextFile(JoinPath2(RootDir, 'json_empty_ok'), '{}');
  AddTestCase(Names, Expected, 'json_empty_ok', 'application/json');

  WriteTextFile(JoinPath2(RootDir, 'xml_ok'),
    '<?xml version="1.0" encoding="UTF-8"?>' + LineEnding +
    '<root><item>value</item></root>');
  AddTestCase(Names, Expected, 'xml_ok', 'application/xml');

  WriteTextFile(JoinPath2(RootDir, 'xml_tag_ok'),
    '<root>' + LineEnding +
    '  <item>value</item>' + LineEnding +
    '</root>');
  AddTestCase(Names, Expected, 'xml_tag_ok', 'application/xml');

  WriteTextFile(JoinPath2(RootDir, 'html_ok'),
    '<!doctype html>' + LineEnding +
    '<html>' + LineEnding +
    '  <head><title>T</title></head>' + LineEnding +
    '  <body>Hello</body>' + LineEnding +
    '</html>');
  AddTestCase(Names, Expected, 'html_ok', 'text/html');

  WriteTextFile(JoinPath2(RootDir, 'html_fragment_ok'), '<div class="note">Hello</div>');
  AddTestCase(Names, Expected, 'html_fragment_ok', 'text/html');

  WriteTextFile(JoinPath2(RootDir, 'yaml_ok'),
    '---' + LineEnding +
    'name: test' + LineEnding +
    'items:' + LineEnding +
    '  - one' + LineEnding +
    '  - two');
  AddTestCase(Names, Expected, 'yaml_ok', 'application/yaml');

  WriteTextFile(JoinPath2(RootDir, 'yaml_map_ok'),
    'name: test' + LineEnding +
    'enabled: true' + LineEnding +
    'count: 3');
  AddTestCase(Names, Expected, 'yaml_map_ok', 'application/yaml');

  WriteTextFile(JoinPath2(RootDir, 'script_ok'),
    '#!/usr/bin/env bash' + LineEnding +
    'echo "hello"');
  AddTestCase(Names, Expected, 'script_ok', 'text/x-script');

  WriteTextFile(JoinPath2(RootDir, 'script_if_ok'),
    '#!/bin/sh' + LineEnding +
    'if [ -f test.txt ]; then' + LineEnding +
    '  echo ok' + LineEnding +
    'fi');
  AddTestCase(Names, Expected, 'script_if_ok', 'text/x-script');

  WriteTextFile(JoinPath2(RootDir, 'plain_ok'),
    'This is a plain text note.' + LineEnding +
    'Nothing structured here.');
  AddTestCase(Names, Expected, 'plain_ok', 'text/plain');

  WriteTextFile(JoinPath2(RootDir, 'json_bad'), '{not really json');
  AddTestCase(Names, Expected, 'json_bad', 'text/plain');

  WriteTextFile(JoinPath2(RootDir, 'json_array_bad'), '[not really json');
  AddTestCase(Names, Expected, 'json_array_bad', 'text/plain');

  WriteTextFile(JoinPath2(RootDir, 'xml_bad'), '< hello');
  AddTestCase(Names, Expected, 'xml_bad', 'text/plain');

  WriteTextFile(JoinPath2(RootDir, 'xml_bad_unclosed'), '<not closed');
  AddTestCase(Names, Expected, 'xml_bad_unclosed', 'text/plain');

  WriteTextFile(JoinPath2(RootDir, 'yaml_bad_title'), 'Title: test');
  AddTestCase(Names, Expected, 'yaml_bad_title', 'text/plain');

  WriteTextFile(JoinPath2(RootDir, 'yaml_bad_bullet'), '- one line bullet only');
  AddTestCase(Names, Expected, 'yaml_bad_bullet', 'text/plain');

  WriteTextFile(JoinPath2(RootDir, 'script_bad_note'),
    'then we went home' + LineEnding +
    'fi was written in a note');
  AddTestCase(Names, Expected, 'script_bad_note', 'text/plain');

  WriteTextFile(JoinPath2(RootDir, 'script_bad_export'), 'export quality matters');
  AddTestCase(Names, Expected, 'script_bad_export', 'text/plain');

  WriteTextFile(JoinPath2(RootDir, 'plain_utf8_ok.txt'), 'Café résumé naïve jalapeño');
  AddTestCase(Names, Expected, 'plain_utf8_ok.txt', 'text/plain');

  WriteTextFile(JoinPath2(RootDir, 'test.json'), '{"name":"test","value":1}');
  AddTestCase(Names, Expected, 'test.json', 'application/json');

  WriteTextFile(JoinPath2(RootDir, 'test.xml'),
    '<?xml version="1.0" encoding="UTF-8"?>' + LineEnding +
    '<root><item>value</item></root>');
  AddTestCase(Names, Expected, 'test.xml', 'application/xml');

  WriteTextFile(JoinPath2(RootDir, 'test.html'),
    '<!doctype html>' + LineEnding + '<html><body>Hello</body></html>');
  AddTestCase(Names, Expected, 'test.html', 'text/html');

  WriteTextFile(JoinPath2(RootDir, 'test.yaml'),
    '---' + LineEnding + 'name: test' + LineEnding + 'count: 3');
  AddTestCase(Names, Expected, 'test.yaml', 'application/yaml');

  WriteTextFile(JoinPath2(RootDir, 'test.sh'),
    '#!/bin/sh' + LineEnding + 'echo hello');
  AddTestCase(Names, Expected, 'test.sh', 'text/x-script');

  WriteTextFile(JoinPath2(RootDir, 'test.txt'), 'Just plain text.');
  AddTestCase(Names, Expected, 'test.txt', 'text/plain');
end;

procedure AssertTestResult(const LabelText: string; Condition: Boolean; var Passed, Failed: Integer);
begin
  if Condition then
  begin
    Inc(Passed);
    Writeln('[PASS] ', LabelText);
  end
  else
  begin
    Inc(Failed);
    Writeln('[FAIL] ', LabelText);
  end;
end;

procedure RunTypeFilterSelfTests(const RootDir: string; var Passed, Failed: Integer);
begin
  AssertTestResult('--Type=json matches json_ok',
    MatchesTypeFilter(JoinPath2(RootDir, 'json_ok'), 'json'), Passed, Failed);
  AssertTestResult('--Type=json does not match plain_ok',
    not MatchesTypeFilter(JoinPath2(RootDir, 'plain_ok'), 'json'), Passed, Failed);
  AssertTestResult('--Type=text matches plain_ok',
    MatchesTypeFilter(JoinPath2(RootDir, 'plain_ok'), 'text'), Passed, Failed);
  AssertTestResult('--Type=text matches html_ok by main type',
    MatchesTypeFilter(JoinPath2(RootDir, 'html_ok'), 'text'), Passed, Failed);
  AssertTestResult('--Type=html matches html_ok by subtype',
    MatchesTypeFilter(JoinPath2(RootDir, 'html_ok'), 'html'), Passed, Failed);
  AssertTestResult('--Type=xml matches xml_ok',
    MatchesTypeFilter(JoinPath2(RootDir, 'xml_ok'), 'xml'), Passed, Failed);
  AssertTestResult('--Type=yaml matches yaml_ok',
    MatchesTypeFilter(JoinPath2(RootDir, 'yaml_ok'), 'yaml'), Passed, Failed);
  AssertTestResult('--Type=x-script matches script_ok',
    MatchesTypeFilter(JoinPath2(RootDir, 'script_ok'), 'x-script'), Passed, Failed);
  AssertTestResult('--Type=image,json,text matches json_ok',
    MatchesTypeFilter(JoinPath2(RootDir, 'json_ok'), 'image,json,text'), Passed, Failed);
  AssertTestResult('--Type=image,json,text matches plain_ok',
    MatchesTypeFilter(JoinPath2(RootDir, 'plain_ok'), 'image,json,text'), Passed, Failed);
  AssertTestResult('--Type=image,json,text does not match xml_ok',
    not MatchesTypeFilter(JoinPath2(RootDir, 'xml_ok'), 'image,json,text'), Passed, Failed);
  AssertTestResult('--Type=image,xml,text matches xml_ok',
    MatchesTypeFilter(JoinPath2(RootDir, 'xml_ok'), 'image,xml,text'), Passed, Failed);
  AssertTestResult('--Type=application matches json_ok by main type',
    MatchesTypeFilter(JoinPath2(RootDir, 'json_ok'), 'application'), Passed, Failed);
  AssertTestResult('--Type=text,application matches yaml_ok',
    MatchesTypeFilter(JoinPath2(RootDir, 'yaml_ok'), 'text,application'), Passed, Failed);
end;

procedure RunPathGenerationSelfTests(const RootDir: string; var Passed, Failed: Integer);
var
  Opts: TOptions;
  FilePath, TargetFile, ExpectedRoot: string;
begin
  FilePath := JoinPath2(RootDir, 'test.json');
  ExpectedRoot := JoinPath2(GetCurrentDir, 'OUT');

  InitOptions(Opts);
  try
    Opts.Target := 'OUT';
    Opts.DirsSpec := 'mime-main,mime-sub';
    Opts.SubDirsSpec := 'date:year:month';
    Opts.RenameSpec := 'original';
    Opts.ExtensionSpec := 'original';

    TargetFile := ComputeTargetFile(Opts, FilePath);

    AssertTestResult('path contains target root',
      Pos(ExpectedRoot, TargetFile) = 1, Passed, Failed);
    AssertTestResult('path contains dirs mime-main/mime-sub',
      Pos(JoinPath2('APPLICATION', 'JSON'), UpperCase(TargetFile)) > 0, Passed, Failed);
    AssertTestResult('path keeps original extension',
      AnsiEndsText('.json', LowerCase(TargetFile)), Passed, Failed);
    AssertTestResult('path ends with original file name',
      AnsiEndsText('test.json', LowerCase(TargetFile)), Passed, Failed);
  finally
    FreeOptions(Opts);
  end;

  InitOptions(Opts);
  try
    Opts.Target := 'OUT2';
    Opts.DirsSpec := 'extension';
    Opts.SubDirsSpec := 'format,size';
    Opts.RenameSpec := 'mime-sub';
    Opts.ExtensionSpec := 'mime-main';

    TargetFile := ComputeTargetFile(Opts, FilePath);

    AssertTestResult('path contains extension dir',
      Pos(PathDelim + 'JSON' + PathDelim, UpperCase(TargetFile)) > 0, Passed, Failed);
    AssertTestResult('path contains BYTE size bucket',
      Pos(PathDelim + 'BYTE' + PathDelim, UpperCase(TargetFile)) > 0, Passed, Failed);
    Writeln('[INFO] generated filename = ', ExtractFileName(TargetFile));
    AssertTestResult('rename=mime-sub and extension=mime-main', SameText(LowerCase(ExtractFileName(TargetFile)), 'json.application'), Passed, Failed);
  finally
    FreeOptions(Opts);
  end;
end;

procedure RunSelfTest;
var
  RootDir: string;
  Names, Expected: TStringList;
  I, Passed, Failed: Integer;
  FilePath, ActualMime, ExpectedMime: string;
begin
  RootDir := JoinPath2(GetCurrentDir, 'sniff-tests-runtime');

  if DirectoryExists(RootDir) then
    DeleteDirectoryTree(RootDir);

  Names := TStringList.Create;
  Expected := TStringList.Create;
  try
    CreateSniffFixtures(RootDir, Names, Expected);

    Passed := 0;
    Failed := 0;

    Writeln('Running built-in sniff tests in: ', RootDir);
    Writeln;

    for I := 0 to Names.Count - 1 do
    begin
      FilePath := JoinPath2(RootDir, Names[I]);
      ExpectedMime := Expected[I];
      ActualMime := FindMime(FilePath);

      if SameText(ActualMime, ExpectedMime) then
      begin
        Inc(Passed);
        Writeln('[PASS] MIME ', Names[I], ' -> ', ActualMime);
      end
      else
      begin
        Inc(Failed);
        Writeln('[FAIL] MIME ', Names[I], ' -> got=', ActualMime, ' expected=', ExpectedMime);
      end;
    end;

    Writeln;
    Writeln('Running type-filter self-tests...');
    Writeln;
    RunTypeFilterSelfTests(RootDir, Passed, Failed);

    Writeln;
    Writeln('Running path-generation self-tests...');
    Writeln;
    RunPathGenerationSelfTests(RootDir, Passed, Failed);

    Writeln;
    Writeln('Passed: ', Passed);
    Writeln('Failed: ', Failed);

    if Failed > 0 then
      Halt(2);
  finally
    Expected.Free;
    Names.Free;
  end;
end;

procedure Main;
var
  Opts: TOptions;
  Files: TStringList;
  I: Integer;
begin
  Randomize;
  InitMimeCache;
  InitHashCache;
  InitOptions(Opts);
  try
    ParseCommandLine(Opts);

    if Opts.SelfTest then
    begin
      RunSelfTest;
      Exit;
    end;

    if (ParamCount = 0) or Opts.ShowHelp or ((Opts.Inputs.Count = 0) and (not Opts.ShowHelp)) then
    begin
      PrintUsage;
      Exit;
    end;

    Files := ExpandInputsToFiles(Opts);
    try
      if Files.Count = 0 then
      begin
        Writeln('No files to process.');
        Exit;
      end;

      for I := 0 to Files.Count - 1 do
        ProcessFile(Opts, Files[I]);
    finally
      Files.Free;
    end;
  finally
    FreeHashCache;
    FreeMimeCache;
    FreeMimeRules;
    FreeOptions(Opts);
  end;
end;

begin
  try
    Main;
  except
    on E: Exception do
    begin
      Writeln('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
