{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : colors.pas                                                       }
{  Version : 1.0                                                              }
{  Desc    : Color toolkit - ANSI colors and thread-safe print helpers        }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh colors.pas  }
{                                                                             }
{*****************************************************************************}
unit colors;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, SyncObjs;

const
    C_Reset  = #27 + '[0m';
    C_Red    = #27 + '[31m';
    C_Green  = #27 + '[32m';
    C_Yellow = #27 + '[33m';
    C_Blue   = #27 + '[34m';
    C_Bold   = #27 + '[1m';

{ PrintLock: guards stdout/stderr when several threads print at once }
var
    PrintLock: TCriticalSection;

{ Write_Msg: plain message on stdout }
procedure Write_Msg(const S: string);

{ Write_Tagged: one line with a bold tag, e.g. Write_Tagged('COPIED', F) }
procedure Write_Tagged(const Tag, S: string);

{ Write_Err: error line on stderr (red when colors are on) }
procedure Write_Err(const S: string);

{ Write_Warn: warning line on stderr (yellow when colors are on) }
procedure Write_Warn(const S: string);

{ Write_Log: timestamped log line on stderr }
procedure Write_Log(const S: string);

implementation

procedure Write_Msg(const S: string);
begin
    PrintLock.Enter;
    try
        WriteLn(S);
    finally
        PrintLock.Leave;
    end;
end;

procedure Write_Tagged(const Tag, S: string);
begin
    PrintLock.Enter;
    try
        WriteLn(C_Bold + Tag + C_Reset + ' ' + S);
    finally
        PrintLock.Leave;
    end;
end;

procedure Write_Err(const S: string);
begin
    PrintLock.Enter;
    try
        WriteLn(StdErr, C_Red + S + C_Reset);
    finally
        PrintLock.Leave;
    end;
end;

procedure Write_Warn(const S: string);
begin
    PrintLock.Enter;
    try
        WriteLn(StdErr, C_Yellow + S + C_Reset);
    finally
        PrintLock.Leave;
    end;
end;

procedure Write_Log(const S: string);
begin
    PrintLock.Enter;
    try
        WriteLn(StdErr, FormatDateTime('(yyyy-mm-dd hh:nn:ss)', Now) + ' ' + S);
    finally
        PrintLock.Leave;
    end;
end;

initialization
    PrintLock := TCriticalSection.Create;

finalization
    PrintLock.Free;

end.
