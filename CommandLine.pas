unit CommandLine;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Variants;

type
   ECommandLine = class(Exception);

   IAppParam = interface
     ['{77EC9C5D-121B-4742-88A4-639BBAAF83EC}']
     function GetName: String;
     function GetMandatory: Boolean;
     function GetValue: Variant;
     function GetHelp: String;
     function Valid(const AText: String): Boolean;
   end;

   EParamValueNotDefined = class(ECommandLine)
   public
     constructor Create(AObject: IAppParam);
   end;

   EMandatoryParamNotFound = class(ECommandLine)
   public
     constructor Create(AObject: IAppParam);
   end;

   EInvalidValueParam = class(ECommandLine)
   public
     constructor Create(AObject: IAppParam);
   end;

   ICommandTemplate = interface
     ['{0EEA4DCB-1D9B-476B-AA5F-55D60B060820}']
     procedure AddParam(const AParamName: String; AMandatory: Boolean);
     procedure AddNumbParam(const AParamName: String; AMandatory: Boolean; AMin: Integer; AMax: Integer);
     procedure AddTextParam(const AParamName: String; AMandatory: Boolean; AMaxLength: Integer);
     procedure AddEnumParam(const AParamName: String; AMandatory: Boolean; AValues: array of string);
   end;

   ICommandLine = interface
     function CreateCommand(const ACommand: String): ICommandTemplate;
     function GetApplicationPath: String;
     function GetApplicationFileName: String;
     function GetHelp: String;

     function IsCommand(const ACommand: String): Boolean;

     function GetParam(const AParamName: String): String;
     function HasParam(const AParamName: String): Boolean;
   end;

   function CreateCommandLine: ICommandLine;

implementation

uses
  Vcl.Forms,
  StrUtils,
  Winapi.Windows,
  System.RegularExpressions,
  System.RegularExpressionsCore,
  System.Generics.Collections;

type
   TCustomParam = class(TInterfacedPersistent, IAppParam)
   strict private
     FName: String;
     FMandatory: Boolean;
     function GetName: String;
     function GetMandatory: Boolean;
   protected
     function GetValue: Variant; virtual;
     function MandatoryToString(const AValue: String): String;
   public
     constructor Create(const AParamName: String; AMandatory: Boolean);

     property Mandatory: Boolean read FMandatory;
     property Name: String read GetName;


     function GetHelp: String; virtual; abstract;
     function Valid(const AText: String): Boolean; virtual; abstract;

     class function GetReqularExpression: String; virtual; abstract;
   end;

   TSimpleParam = class(TCustomParam)
   public
     class function GetReqularExpression: String; override;

     function Valid(const AText: String): Boolean; override;
     function GetHelp: String; override;
   end;

   TValuedParam = class(TCustomParam)
   public
     class function GetReqularExpression: String; override;
   end;

   TNumberParam = class(TValuedParam)
   private
     FMin: Integer;
     FMax: Integer;
   public
     constructor Create(const AParamName: String; AMandatory: Boolean; AMin: Integer; AMax: Integer);

     property Min: Integer read FMin;
     property Max: Integer read FMax;

     function GetHelp: String; override;

     function Valid(const AText: String): Boolean; override;
   end;

   TTextParam = class(TValuedParam)
   private
     FMaxLength: Integer;
   public
     constructor Create(const AParamName: String; AMandatory: Boolean; AMaxLength: Integer);

     property MaxLength: Integer read FMaxLength;

     function Valid(const AText: String): Boolean; override;

     function GetHelp: String; override;
   end;

   TEnumerationParam = class(TValuedParam)
   private
     FList: TStringList;
   public
     constructor Create(const AParamName: String; AMandatory: Boolean; APossibleValues: array of string);
     destructor Destroy; override;

     function Valid(const AText: String): Boolean; override;
     function GetHelp: String; override;
   end;

   TCommandLineParcer = class
   private
     FAppFileName: String;
     FAppFilePath: String;
     FCommand: String;
     FParams: TDictionary<String, String>;
   public
     constructor Create(const ACommandLine: String);

     property Command: String read FCommand;

     property ApplicationPath: String read FAppFileName;
     property ApplicationFileName: String read FAppFilePath;

     function HasParam(const AParamName: String): Boolean;
     function GetParam(const AParamName: String): String;
   end;

   TCommandTemplate = class(TInterfacedPersistent, ICommandTemplate)
   private
     FParams: TInterfaceList;
   public
     constructor Create;
     destructor Destroy; override;

     procedure AddParam(const AParamName: String; AMandatory: Boolean);
     procedure AddNumbParam(const AParamName: String; AMandatory: Boolean; AMin: Integer; AMax: Integer);
     procedure AddTextParam(const AParamName: String; AMandatory: Boolean; AMaxLength: Integer);
     procedure AddEnumParam(const AParamName: String; AMandatory: Boolean; AValues: array of string);

     function Validate(AParamList: TCommandLineParcer): Boolean;

     function ToString: String;

   end;

   TCommandLine = class(TInterfacedObject, ICommandLine)
   private
     FCommandLine: String;
     FParcer: TCommandLineParcer;
     FTemplates: TDictionary<String, TCommandTemplate>;

     function GetApplicationPath: String;
     function GetApplicationFileName: String;
     function GetParcer: TCommandLineParcer;
   public
     constructor Create(const ACommandLine: String);
     destructor Destroy; override;

     function CreateCommand(const ACommand: String): ICommandTemplate;
     function GetCommand: String;
     function IsCommand(const ACommand: String): Boolean;

     function GetHelp: String;

     function GetParam(const AParamName: String): String;
     function HasParam(const AParamName: String): Boolean;
   end;

var
  CmdLine: ICommandLine;

resourcestring
  StrString = 'String';
  StrNumber = 'Number';
  StrChar = 'Char';
  StrNone = 'None';

const
  PARAM_REGEXP_EXPRESSION = '^\-\-(\w+)\=?(.+)?';
  HELP_COMMAND = 'help';

function CreateCommandLine: ICommandLine;
begin
  Result := TCommandLine.Create(GetCommandLine);
end;

{ TAppParam }

constructor TCustomParam.Create(const AParamName: String;
  AMandatory: Boolean);
begin
  FName := AParamName.Trim.ToLower;
  FMandatory := AMandatory;
end;

function TCustomParam.GetMandatory: Boolean;
begin
  Result := FMandatory;
end;

function TCustomParam.GetName: String;
begin
  Result := FName;
end;

function TCustomParam.GetValue: Variant;
begin
  Result := String.Empty;
end;

function TCustomParam.MandatoryToString(const AValue: String): String;
begin
  Result := AValue;
  if not FMandatory then
    Result := '[' + AValue + ']';
end;

{ TExceptionParamNotFound }

constructor EMandatoryParamNotFound.Create(AObject: IAppParam);
begin
  inherited Create(Format('''%s'' parameter is not found.',[AObject.GetName]));
end;

{ ExceptionInvalidParameter }

constructor EParamValueNotDefined.Create(AObject: IAppParam);
begin
  inherited Create(Format('Value ''%s'' parameter is not defined.',[AObject.GetName]));
end;

{ TAppNumberParam }

constructor TNumberParam.Create(const AParamName: String;
  AMandatory: Boolean; AMin, AMax: Integer);
begin
  inherited Create(AParamName, AMandatory);
  FMin := AMin;
  FMax := AMax;
end;

function TNumberParam.GetHelp: String;
begin
  Result := MandatoryToString(Format('--%s=<Number(%d - %d)>', [Self.Name , FMin, FMax]));
end;

function TNumberParam.Valid(const AText: String): Boolean;
var
  paramValue: Integer;
begin
  Result := False;
  if TryStrToInt(AText, paramValue) then
      Result := (paramValue <= FMax) and (paramValue >= FMin);
end;

{ TAppEnumerationParam }

constructor TEnumerationParam.Create(const AParamName: String;
  AMandatory: Boolean; APossibleValues: array of string);
var
  i: Integer;
begin
  inherited Create(AParamName, AMandatory);

  FList := TStringList.Create;
  for i := Low(APossibleValues) to High(APossibleValues) do
    FList.Add(APossibleValues[i]);
end;

destructor TEnumerationParam.Destroy;
begin
  FreeAndNil(FList);
  inherited;
end;

function TEnumerationParam.GetHelp: String;
begin
  Result := MandatoryToString(Format('--%s=<Enum(%s)>', [Self.Name, FList.DelimitedText]));
end;

function TEnumerationParam.Valid(const AText: String): Boolean;
begin
  Result := FList.IndexOf(AText) >= 0;
end;

{ TAppTextParam }

constructor TTextParam.Create(const AParamName: String; AMandatory: Boolean;
  AMaxLength: Integer);
begin
  inherited Create(AParamName, AMandatory);
  FMaxLength := AMaxLength;
end;

function TTextParam.GetHelp: String;
begin
  Result := MandatoryToString(Format('--%s=<Text(%d)>', [Self.Name, FMaxLength]));
end;

function TTextParam.Valid(const AText: String): Boolean;
begin
  Result := AText.Length <= MaxLength;
end;

{ TAppValuedParam }

class function TValuedParam.GetReqularExpression: String;
begin
  Result := '^\-\-(\w+)\=?(.+)?';
end;

{ ExceptionInvalidValueParam }

constructor EInvalidValueParam.Create(AObject: IAppParam);
begin
 inherited Create(Format('Invalid value of ''%s'' parameter. Please use following syntax: %s',[AObject.GetName, AObject.GetHelp]));
end;

{ TAppSimpleParam }

class function TSimpleParam.GetReqularExpression: String;
begin
  Result := '^\-\-(\w+)';
end;

function TSimpleParam.Valid(const AText: String): Boolean;
begin
  Result := True;
end;

function TSimpleParam.GetHelp: String;
begin
  Result := MandatoryToString(Format('--%s', [Self.Name]));
end;

{ TApplicationParams }

constructor TCommandLine.Create(const ACommandLine: String);
begin
  FCommandLine := ACommandLine;
  FTemplates := TDictionary<String, TCommandTemplate>.Create;
end;

function TCommandLine.CreateCommand(
  const ACommand: String): ICommandTemplate;
var
  template: TCommandTemplate;
begin
  template := TCommandTemplate.Create;
  FTemplates.Add(ACommand.Trim.ToLower, template);
  Result := template;
end;

destructor TCommandLine.Destroy;
begin
  FreeAndNil(FTemplates);
  inherited;
end;

function TCommandLine.GetApplicationFileName: String;
begin
  Result := GetParcer.ApplicationFileName;
end;

function TCommandLine.GetApplicationPath: String;
begin
  Result := GetParcer.ApplicationPath;
end;

function TCommandLine.GetCommand: String;
begin
  Result := GetParcer.Command;
end;

function TCommandLine.GetHelp: String;
var
  pair: TPair<String, TCommandTemplate>;
begin
  for pair in FTemplates.ToArray do
  begin
    Write(pair.Key + ' ');
    Writeln(pair.Value.ToString);
  end;

end;

function TCommandLine.GetParam(const AParamName: String): String;
begin
  Result := GetParcer.GetParam(AParamName);
end;

function TCommandLine.GetParcer: TCommandLineParcer;
var
  template: TCommandTemplate;
begin
  if not Assigned(FParcer) then
  begin
    FParcer := TCommandLineParcer.Create(FCommandLine);
    template := nil;
    if (not FParcer.Command.Equals(HELP_COMMAND)) and (not FTemplates.TryGetValue(FParcer.Command, template)) then
      raise Exception.Create('Command not found');

    if Assigned(template) then
      template.validate(FParcer);
  end;

  Result := FParcer;
end;

function TCommandLine.HasParam(const AParamName: String): Boolean;
begin
  Result := GetParcer.HasParam(AParamName);
end;

function TCommandLine.IsCommand(const ACommand: String): Boolean;
begin
  Result := ACommand.Trim.ToLower.Equals(GetCommand);
end;

{ TCommandTemplate }

procedure TCommandTemplate.AddEnumParam(const AParamName: String;
  AMandatory: Boolean; AValues: array of string);
begin
  FParams.Add(IAppParam(TEnumerationParam.Create(AParamName,AMandatory, AValues)));
end;

procedure TCommandTemplate.AddNumbParam(const AParamName: String;
  AMandatory: Boolean; AMin, AMax: Integer);
begin
  FParams.Add(IAppParam(TNumberParam.Create(AParamName,AMandatory,  AMin, AMax)));
end;

procedure TCommandTemplate.AddParam(const AParamName: String;
  AMandatory: Boolean);
begin
  FParams.Add(IAppParam(TSimpleParam.Create(AParamName, AMandatory)));
end;

procedure TCommandTemplate.AddTextParam(const AParamName: String;
  AMandatory: Boolean; AMaxLength: Integer);
begin
  FParams.Add(IAppParam(TTextParam.Create(AParamName, AMandatory, AMaxLength)));
end;

constructor TCommandTemplate.Create;
begin
  FParams := TInterfaceList.Create;
end;

destructor TCommandTemplate.Destroy;
begin
  FreeAndNil(FParams);
  inherited;
end;

function TCommandTemplate.ToString: String;
var
  col: IInterface;
begin
  Result := String.Empty;
  for col in FParams do
     Result := Result + Format('%s ',[IAppParam(col).GetHelp]);
end;

function TCommandTemplate.Validate(AParamList: TCommandLineParcer): Boolean;
var
  col: IInterface;
  val: String;
begin
  for col in FParams do
  begin
    if IAppParam(col).GetMandatory then
      if not AParamList.HasParam(IAppParam(col).GetName) then
        raise EMandatoryParamNotFound.Create(IAppParam(col));

    val := AParamList.GetParam(IAppParam(col).GetName);
    if not IAppParam(col).Valid(val) then
      raise EInvalidValueParam.Create(IAppParam(col));
  end;
end;

{ TCommandLineParcer }

constructor TCommandLineParcer.Create(const ACommandLine: String);
var
  regexp: TRegEx;
  regmatch: TMatch;
  str: String;
const
  REXP_BASE_FORMAT = '^(\"?.+\"?)\s+(\w+)(\s+.+)?$';
begin
  FParams := TDictionary<String, String>.Create;

  regmatch := regexp.Match(ACommandLine, REXP_BASE_FORMAT);
  if (regmatch.Success) then
  begin
    FAppFileName := ExtractFileName(regmatch.Groups[1].Value);
    FAppFilePath := ExtractFileDir(regmatch.Groups[1].Value);
    FCommand := regmatch.Groups[2].Value.ToLower;
    if regmatch.Groups.Count > 3 then
    for str in regmatch.Groups[3].Value.Trim.split(['-', '--']) do
      if not str.IsEmpty then
      begin
        regmatch := regexp.Match(str.Trim, '^(\w+)\=?\"?(.+)?\"?$');
        if (regmatch.Success) then
        begin
          if regmatch.Groups.Count > 1 then
            FParams.Add(regmatch.Groups[1].Value.Trim.ToLower, regmatch.Groups[2].Value)
          else
            FParams.Add(regmatch.Groups[1].Value.Trim.ToLower, String.Empty);
        end;
      end;
  end;
end;

function TCommandLineParcer.GetParam(const AParamName: String): String;
begin
  if not FParams.TryGetValue(AParamName.ToLower.Trim, Result) then
    Result := String.Empty;
end;

function TCommandLineParcer.HasParam(const AParamName: String): Boolean;
begin
  Result := FParams.ContainsKey(AParamName.ToLower.Trim);
end;

end.
