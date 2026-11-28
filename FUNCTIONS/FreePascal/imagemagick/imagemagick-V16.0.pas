{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : imagemagick.pas                                                  }
{  Version : 1.0                                                              }
{  Desc    : Image toolkit - dimensions, tiers, orientation (identify)        }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh imagemagick.pas }
{                                                                             }
{*****************************************************************************}
unit imagemagick;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, systools;

{ Image_WxH: image width and height via identify }
function Image_WxH(const F: string; out W, H: Integer): Boolean;

{ Media_Tier: size tier name (TINY..HUGE) for width x height }
function Media_Tier(const W, H: Integer): string;

{ Media_Orient: orientation name (WIDE/HIGH/SQUARE) for width x height }
function Media_Orient(const W, H: Integer): string;

implementation

function Image_WxH(const F: string; out W, H: Integer): Boolean;
var
    Res: string;
    P: Integer;
begin
    Result := False;
    W := 0;
    H := 0;
    if RunTool('identify', ['-format', '%w:%h', F], Res) <> 0 then
        Exit;
    Res := Trim(Res);
    P := Pos(':', Res);
    if P = 0 then
        Exit;
    W := StrToIntDef(Copy(Res, 1, P - 1), 0);
    H := StrToIntDef(Copy(Res, P + 1, MaxInt), 0);
    Result := (W > 0) and (H > 0);
end;

function Media_Tier(const W, H: Integer): string;
begin
    if (W < 64) or (H < 64) then Result := 'TINY'
    else if (W < 128) or (H < 128) then Result := 'MINI'
    else if (W < 320) or (H < 320) then Result := 'SMALLER'
    else if (W < 640) or (H < 640) then Result := 'SMALL'
    else if (W < 1280) or (H < 1280) then Result := 'MEDIUM'
    else if (W < 1920) or (H < 1920) then Result := 'BIG'
    else if (W < 3840) or (H < 3840) then Result := 'BIGGER'
    else Result := 'HUGE';
end;

function Media_Orient(const W, H: Integer): string;
begin
    if W > H then Result := 'WIDE'
    else if W < H then Result := 'HIGH'
    else Result := 'SQUARE';
end;

end.
