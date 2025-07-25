unit Horse.Jhonson;

{$IF DEFINED(FPC)}
{$MODE DELPHI}{$H+}
{$ENDIF}

interface

uses
{$IF DEFINED(FPC)}
  SysUtils, Classes, HTTPDefs, fpjson, jsonparser,
{$ELSE}
  System.Classes, System.JSON, System.SysUtils, Web.HTTPApp,
{$ENDIF}
  Horse, Horse.Commons;

function Jhonson: THorseCallback; overload;
function Jhonson(const ACharset: string): THorseCallback; overload;

procedure Middleware(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF});

implementation

var
  Charset: string;

function Jhonson: THorseCallback; overload;
begin
  Result := Jhonson('UTF-8');
end;

function Jhonson(const ACharset: string): THorseCallback; overload;
begin
  Charset := ACharset;
  Result := Middleware;
end;

procedure Middleware(Req: THorseRequest; Res: THorseResponse; Next: {$IF DEFINED(FPC)}TNextProc{$ELSE}TProc{$ENDIF});
var
  LJSON: {$IF DEFINED(FPC)}TJsonData{$ELSE}TJSONValue{$ENDIF};
  {$IF CompilerVersion >= 36}
  ops: TJSONValue.TJsonOutputOptions;
  {$ENDIF}
begin
  if (Req.MethodType in [mtPost, mtPut, mtPatch]) and (Pos('application/json', Req.RawWebRequest.ContentType) > 0) then
  begin
    try
      LJSON := {$IF DEFINED(FPC)} GetJSON(Req.Body) {$ELSE}TJSONObject.ParseJSONValue(Req.Body){$ENDIF};
    except
      Res.Send('Invalid JSON').Status(THTTPStatus.BadRequest);
      raise EHorseCallbackInterrupted.Create;
    end;

    if not Assigned(LJSON) then
    begin
      Res.Send('Invalid JSON').Status(THTTPStatus.BadRequest);
      raise EHorseCallbackInterrupted.Create;
    end;

    {$IF DEFINED(FPC)}
    if Assigned(Req.Body<TObject>) then
      Req.Body<TObject>.Free;
    {$ENDIF}

    Req.Body(LJSON);
  end;

  try
    Next;
  finally
    if (Res.Content <> nil) and Res.Content.InheritsFrom({$IF DEFINED(FPC)}TJsonData{$ELSE}TJSONValue{$ENDIF}) then
    begin
      {$IF DEFINED(FPC)}
      Res.RawWebResponse.ContentStream := TStringStream.Create(TJsonData(Res.Content).AsJSON);
      {$ELSE}
    		{$IF CompilerVersion >= 36}
    		  if SameText(Charset, 'utf-8') then
    			  ops := [TJSONValue.TJSONOutputOption.EncodeBelow32]
    		  else
    			  ops := [TJSONValue.TJSONOutputOption.EncodeBelow32, TJSONValue.TJSONOutputOption.EncodeAbove127];
    
    		  Res.RawWebResponse.Content := TJSONValue(Res.Content).ToJSON(ops);
    		{$ELSE}
    		  Res.RawWebResponse.Content := TJSONValue(Res.Content).ToJSON;
    		{$ENDIF}
      {$ENDIF}
      Res.RawWebResponse.ContentType := 'application/json; charset=' + Charset;
    end;
  end;
end;

end.
