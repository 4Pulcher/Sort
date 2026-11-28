{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : uitools.pas                                                      }
{  Version : 1.0                                                              }
{  Desc    : Terminal display toolkit - rules, headers, banners               }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh uitools.pas }
{                                                                             }
{*****************************************************************************}
unit uitools;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, colors;

{ Repeat_Ch: a string of N copies of Ch }
function Repeat_Ch(const Ch: string; N: Integer): string;

{ Draw_Line: print a rule of N characters }
procedure Draw_Line(const Ch: string; N: Integer);

{ Write_Header: title line followed by a rule (like the shell Print_Header) }
procedure Write_Header(const Title, Ch: string; Width: Integer);

implementation

function Repeat_Ch(const Ch: string; N: Integer): string;
var
    I: Integer;
begin
    Result := '';
    for I := 1 to N do
        Result := Result + Ch;
end;

procedure Draw_Line(const Ch: string; N: Integer);
begin
    Write_Msg(Repeat_Ch(Ch, N));
end;

procedure Write_Header(const Title, Ch: string; Width: Integer);
begin
    Write_Msg(Title);
    Draw_Line(Ch, Width);
end;

end.
