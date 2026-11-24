{*****************************************************************************}
{  NB/This code is not tested yet!                                            }
{                                                                             }
{  Unit    : docs.pas                                                         }
{  Version : 1.0                                                              }
{  Desc    : Document toolkit - embedded titles via exiftool                  }
{  Author  : HEjder                                                           }
{                                                                             }
{  FreePascal 3.2.2 - mode objfpc, H+ - compile: fpc -Mobjfpc -Sh docs.pas    }
{                                                                             }
{*****************************************************************************}
unit docs;

{$MODE OBJFPC}{$H+}

interface

uses
    SysUtils, exif;

{ Doc_Title: embedded document title (PDF /Title etc.), '' when absent }
function Doc_Title(const F: string): string;

implementation

function Doc_Title(const F: string): string;
begin
    Result := Exif_Field(F, 'Title');
end;

end.
