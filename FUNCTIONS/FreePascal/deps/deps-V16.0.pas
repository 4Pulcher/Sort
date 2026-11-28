{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : deps.pas                                                         }
{  Version : 1.0                                                              }
{  Desc    : Dependency toolkit - check a whole tool list at once             }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh deps.pas    }
{                                                                             }
{*****************************************************************************}
unit deps;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, Classes, systools;

{ Deps_Missing: fill Missing with every tool of the list that is absent;
  returns True when at least one tool is missing }
function Deps_Missing(const Tools: array of string;
                      Missing: TStringList): Boolean;

{ Deps_All_Present: true when every tool of the list exists on PATH }
function Deps_All_Present(const Tools: array of string): Boolean;

implementation

function Deps_Missing(const Tools: array of string;
                      Missing: TStringList): Boolean;
var
    I: Integer;
begin
    Missing.Clear;
    for I := Low(Tools) to High(Tools) do
        if not HaveTool(Tools[I]) then
            Missing.Add(Tools[I]);
    Result := Missing.Count > 0;
end;

function Deps_All_Present(const Tools: array of string): Boolean;
var
    I: Integer;
begin
    Result := True;
    for I := Low(Tools) to High(Tools) do
        if not HaveTool(Tools[I]) then
            Exit(False);
end;

end.
