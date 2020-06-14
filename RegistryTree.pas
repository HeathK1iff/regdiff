unit RegistryTree;

interface

uses
  SysUtils, Classes, System.Generics.Collections,
  Winapi.Windows, System.Win.Registry, Variants;

type
  TRegistryNode = class;
  TRegistryNodeClass = class of TRegistryNode;

  ERegistryMethodNotImplemented = class(Exception);
  TBinaryData = array of Byte;

  IRegistryNode = interface
    ['{8B480845-7CCA-4918-8785-EB9DC0525096}']
    function GetKey: String;
    function GetOwner: IRegistryNode;
    function GetType: TRegDataType;
    function GetValue: String;
    function GetPath(AAbsolutePath: Boolean = True): String;


    procedure Add(ANode: IRegistryNode);
    procedure Delete(ANode: IRegistryNode);
    function Get(AIndex: Integer): IRegistryNode;
    function Count: Integer;
  end;


  TRegistryNode = class(TInterfacedObject, IRegistryNode)
  private
    FOwner: IRegistryNode;
    FKey: String;
  protected
    function GetKey: String;
    function GetValue: String; virtual; abstract;
    function GetPath(AAbsolutePath: Boolean = True): String; virtual;
    function GetOwner: IRegistryNode;
    function GetType: TRegDataType; virtual;
  public
    constructor Create(AOwner: IRegistryNode; const AKey: String); overload; virtual;
    constructor Create(AOwner: IRegistryNode); overload;

    property Key: String read GetKey;
    property Owner: IRegistryNode read GetOwner;
    procedure SetValue(const AValue: String); virtual; abstract;

    function Compare(ANode: IRegistryNode): Boolean; virtual; abstract;
    procedure Add(ANode: IRegistryNode); virtual; abstract;
    procedure Delete(AItem: IRegistryNode); virtual; abstract;
    function Get(AIndex: Integer): IRegistryNode;  virtual; abstract;
    function Count: Integer; virtual;
  end;

  TRegistryComposite = class(TRegistryNode)
  private
    FList: TInterfaceList;
  protected
    function GetPath(AAbsolutePath: Boolean = True): String; override;
  public
    constructor Create(AOwner: IRegistryNode; const AName: String); override;
    destructor Destroy; override;

    function GetValue: String; override;

    procedure Add(ANode: IRegistryNode); override;
    procedure Delete(AItem: IRegistryNode); override;
    function Get(AIndex: Integer): IRegistryNode;  override;
    function Count: Integer; override;
  end;


  TStringRegistryNode = class(TRegistryNode)
  private
    FData: String;
  protected
    function GetType: TRegDataType; override;
    function GetValue: String; override;
  public
    procedure SetValue(const AValue: String); override;
  end;

  TBinaryRegistryNode = class(TRegistryNode)
  private
    FData: TBinaryData;
  protected
    function GetType: TRegDataType; override;
    function GetValue: String; override;
  public
    procedure SetValue(const AValue: String); override;
  end;

  TIntegerRegistryNode = class(TRegistryNode)
  private
    FData: Integer;
  protected
    function GetType: TRegDataType; override;
    function GetValue: String; override;
  public
    procedure SetValue(const AValue: String); override;
  end;

  TExpandableStringRegistryNode = class(TRegistryNode)
  private
    FData: String;
  protected
    function GetType: TRegDataType; override;
    function GetValue: String; override;
  public
    procedure SetValue(const AValue: String); override;
  end;

  IRegistryNodeState = (rnsModified, rnsInserted, rnsDeleted);

  IRegistryNodeDiff = interface
    ['{2B36BC8A-D0A8-49E4-9C9C-D90D755C01A7}']
    function GetOldNode: IRegistryNode;
    function GetNewNode: IRegistryNode;
    function GetKeyPath: String;
    function GetKey: String;
    function ToString: String;
    function ToCSVString: String;
    function GetState: IRegistryNodeState;
  end;

  TRegistryNodeDiff = class(TInterfacedObject, IRegistryNodeDiff)
  private
    FOldNode, FNewNode: IRegistryNode;
    FState: IRegistryNodeState;

    function GetOldNode: IRegistryNode;
    function GetNewNode: IRegistryNode;
    function GetState: IRegistryNodeState;
    function GetKeyPath: String;
    function GetKey: String;

    function GetOldNodeValue: String;
    function GetNewNodeValue: String;
  public
    constructor Create(AOldNode: IRegistryNode; ANewNode: IRegistryNode;
      AState: IRegistryNodeState);

    property OldNode: IRegistryNode read GetOldNode;
    property NewNode: IRegistryNode read GetNewNode;
    property State: IRegistryNodeState read GetState;

    function ToString: String;
    function ToCSVString: String;
  end;

  IRegistryTreeLoader = interface
    ['{3D8B6FB1-E44C-43E0-AF86-F3E7D4CC6CF3}']
    procedure Load(var ARoot: IRegistryNode);
  end;

  IRegistryTreeOutput = interface
    ['{461CA5D5-F593-4C8B-848D-FA758143BBD9}']
    procedure Save(ARoot: IRegistryNode);
  end;

  TRegistryXMLTreeLoader = class(TInterfacedObject, IRegistryTreeLoader)
  private
    FFileName: String;
    procedure Load(var ARoot: IRegistryNode);
    function PrepareString(const AText: String): String;
  public
    constructor Create(const AFileName: String);
  end;

  TRegistryXMLTreeOutput = class(TInterfacedObject, IRegistryTreeOutput)
  private
    FFileName: String;
    procedure Save(ARoot: IRegistryNode);
    function FormatString(const AText: String): String;
  public
    constructor Create(const AFileName: String);
  end;

  IRegistryTree = interface
    ['{DD802405-0E6B-4622-8C33-D034E28D339B}']
    function GetRoot: IRegistryNode;
  end;

  TRegistryTree = class(TInterfacedPersistent, IRegistryTree)
  private
    FRoot: IRegistryNode;
    FNodeCount: Integer;
    function OpenNode(AParent: IRegistryNode;
      ARootKey: Winapi.Windows.HKEY; AKey: String): IRegistryNode;
     function GetRoot: IRegistryNode;
  public
     property Root: IRegistryNode read GetRoot;
     property NodeCount: Integer read FNodeCount;

     procedure Build(ARootKey: Winapi.Windows.HKEY; AKey: String);
     function Compare(ATree: IRegistryTree): TList<IRegistryNodeDiff>;
     function GetNode(const APath: String): IRegistryNode;


     procedure Save(AOutput: IRegistryTreeOutput);
     procedure Load(ALoader: IRegistryTreeLoader);
  end;


  function StringKeyToHKEY(AStringKey: String): Winapi.Windows.HKEY;
  function HKEYToString(AKey: Winapi.Windows.HKEY): String;
  function IsRegKey(AString: String): Boolean;
  function ExcludeRootKey(AString: String; var APath: String): String;
  function NodeStateToStr(AState: IRegistryNodeState): String;


implementation

uses
  Xml.XmlDoc, Xml.XMLIntf;

const
  XML_ROOT_TAG = 'root';
  XML_NODE_TAG = 'node';
  XML_KEY_TAG = 'key';
  XML_TYPE_TAG = 'type';
  XML_MAIN_TAG = 'root';

  REG_TYPE_STRING = 'string';
  REG_TYPE_EXPSTR = 'expstring';
  REG_TYPE_INTEGER = 'integer';
  REG_TYPE_BINARY = 'binary';

  RK_HKEY_CLASSES_ROOT = 'HKEY_CLASSES_ROOT';
  RK_HKEY_CURRENT_USER = 'HKEY_CURRENT_USER';
  RK_HKEY_LOCAL_MACHINE = 'HKEY_LOCAL_MACHINE';
  RK_HKEY_USERS = 'HKEY_USERS';

 function StringKeyToHKEY(AStringKey: String): Winapi.Windows.HKEY;
 begin
   if AStringKey.Equals(RK_HKEY_CLASSES_ROOT) then
     Result := HKEY_CLASSES_ROOT
   else if AStringKey.Equals(RK_HKEY_LOCAL_MACHINE) then
     Result := HKEY_LOCAL_MACHINE
   else if AStringKey.Equals(RK_HKEY_USERS) then
     Result := HKEY_USERS
   else if AStringKey.Equals(RK_HKEY_CURRENT_USER) then
     Result := HKEY_CURRENT_USER
   else
     Result := 0;
 end;

 function HKEYToString(AKey: Winapi.Windows.HKEY): String;
 begin
   case AKey of
     HKEY_CLASSES_ROOT: Result := RK_HKEY_CLASSES_ROOT;
     HKEY_LOCAL_MACHINE: Result := RK_HKEY_LOCAL_MACHINE;
     HKEY_USERS: Result := RK_HKEY_USERS;
     HKEY_CURRENT_USER: Result := RK_HKEY_CURRENT_USER;
     else
       Result := String.Empty;
   end;
 end;

 function IsRegKey(AString: String): Boolean;
 var
   splRegPath: TArray<String>;
   key: HKEY;
 begin
   splRegPath := AString.Split(['\']);
   Result := (Length(splRegPath) > 0) and (StringKeyToHKEY(splRegPath[0]) > 0);
 end;

 function ExcludeRootKey(AString: String; var APath: String): String;
 var
   splRegPath: TArray<String>;
    i: Integer;
 begin
   Result := String.Empty;
   APath := String.Empty;

   splRegPath := AString.Split(['\']);
   if Length(splRegPath) > 1 then
   begin
     Result := splRegPath[0];
     for i := 1 to High(splRegPath) do
       APath := APath + '\' + splRegPath[i];
   end;
 end;

 function NodeStateToStr(AState: IRegistryNodeState): String;
 begin
   case AState of
     rnsModified: Result := 'MODIFIED';
     rnsInserted: Result := 'INSERTED';
     rnsDeleted: Result := 'DELETED';
   else
     Result := String.Empty;
   end;
end;


{ TRegistryNode }

function TRegistryNode.Count: Integer;
begin
  Result := 0;
end;

constructor TRegistryNode.Create(AOwner: IRegistryNode; const AKey: String);
begin
  FKey := AKey.Trim;
  FOwner := AOwner;
end;

constructor TRegistryNode.Create(AOwner: IRegistryNode);
begin
  Create(AOwner, String.Empty);
end;

function TRegistryNode.GetKey: String;
begin
  Result := FKey;
end;


function TRegistryNode.GetPath(AAbsolutePath: Boolean = True): String;
begin
  Result := String.Empty;
  if GetOwner <> nil then
    if AAbsolutePath then
      Result := GetOwner.GetPath + '\' + GetKey
    else
      Result := GetOwner.GetPath;
end;

function TRegistryNode.GetOwner: IRegistryNode;
begin
  Result := FOwner;
end;

function TRegistryNode.GetType: TRegDataType;
begin
  Result := rdUnknown;
end;

{ TRegistryComposite }

procedure TRegistryComposite.Add(ANode: IRegistryNode);
begin
  FList.Add(ANode);
end;

function TRegistryComposite.Count: Integer;
begin
  Result := FList.Count;
end;

constructor TRegistryComposite.Create(AOwner: IRegistryNode;
  const AName: String);
begin
  inherited Create(AOwner, AName);
  FList := TInterfaceList.Create;
end;

procedure TRegistryComposite.Delete(AItem: IRegistryNode);
var
  iObj: Integer;
begin
  iObj := FList.IndexOf(TRegistryNode(AItem));
  if (iObj >= 0) then
    FList.Delete(iObj);
end;

destructor TRegistryComposite.Destroy;
begin
  FreeAndNil(FList);
  inherited;
end;

function TRegistryComposite.Get(AIndex: Integer): IRegistryNode;
begin
  Result := FList.Items[AIndex] as IRegistryNode;
end;

function TRegistryComposite.GetPath(AAbsolutePath: Boolean = True): String;
var
  path: String;
begin
  path := String.Empty;
  if GetOwner <> nil then
    path := GetOwner.GetPath;
  Result := path + '\' + GetKey;
end;

function TRegistryComposite.GetValue: String;
begin
  Result := '';
end;

{ TStringRegistryNode }


function TStringRegistryNode.GetType: TRegDataType;
begin
  Result := rdString;
end;

function TStringRegistryNode.GetValue: String;
begin
  Result := FData;
end;

procedure TStringRegistryNode.SetValue(const AValue: String);
begin
  FData := AValue;
end;

{ TBinaryRegistryNode }

function TBinaryRegistryNode.GetType: TRegDataType;
begin
  Result := rdBinary;
end;

function TBinaryRegistryNode.GetValue: String;
begin
  Result := '';
end;

procedure TBinaryRegistryNode.SetValue(const AValue: String);
begin

end;

{ TIntegerRegistryNode }

function TIntegerRegistryNode.GetType: TRegDataType;
begin
  Result := rdInteger;
end;

function TIntegerRegistryNode.GetValue: String;
begin
  Result := IntToStr(FData);
end;

procedure TIntegerRegistryNode.SetValue(const AValue: String);
begin
  FData := StrToInt(AValue.Trim);
end;

{ TExpandableStringRegistryNode }

function TExpandableStringRegistryNode.GetType: TRegDataType;
begin
  Result := rdExpandString;
end;

function TExpandableStringRegistryNode.GetValue: String;
begin
  Result := FData;
end;

procedure TExpandableStringRegistryNode.SetValue(const AValue: String);
begin
  FData := AValue.Trim;
end;

{ TRegistryScanner }

function TRegistryTree.Compare(ATree: IRegistryTree): TList<IRegistryNodeDiff>;

  procedure InternalCompare(ANode1, ANode2: IRegistryNode; var AOutList: TList<IRegistryNodeDiff>);
  var
    iNode1, iNode2, iIns: Integer;
    slInserted: TList<IRegistryNode>;
    node1, node2: IRegistryNode;
    handled: Boolean;
  begin
    slInserted := TList<IRegistryNode>.Create;
    try
      slInserted.Clear;
      for iNode2 := 0 to ANode2.Count - 1 do
       slInserted.Add(ANode2.Get(iNode2));

      for iNode1 := 0 to ANode1.Count - 1 do
      begin
        node1 := ANode1.Get(iNode1);
        handled := False;
        for iNode2 := 0 to ANode2.Count - 1 do
        begin
          node2 := ANode2.Get(iNode2);

          if node1.GetPath = node2.GetPath then
          begin
             if (node1.GetType = rdUnknown) and
              (node1.GetType = node2.GetType) then
               InternalCompare(node1, node2, AOutList);

             if node1.GetValue <> node2.GetValue then
               AOutList.Add(TRegistryNodeDiff.Create(node1, node2, rnsModified));

             iIns := slInserted.IndexOf(node2);
             if iIns >= 0 then
               slInserted.Delete(iIns);

             handled := True;
             Break;
          end;
        end;

        if not handled then
          AOutList.Add(TRegistryNodeDiff.Create(node1, nil, rnsDeleted));
      end;

      for iNode1 := 0 to slInserted.Count - 1 do
        AOutList.Add(TRegistryNodeDiff.Create(nil, slInserted[iNode1], rnsInserted));
    finally
      FreeAndNil(slInserted);
    end;
  end;
begin
  Result := TList<IRegistryNodeDiff>.Create;
  InternalCompare(FRoot, ATree.GetRoot, Result);
end;

function TRegistryTree.GetNode(const APath: String): IRegistryNode;
  function ExtractNextKey(const APath: String; var AKey: String): String;
  var
    iChar: Integer;
    path: String;
  begin
    path := APath;
    if path.IndexOf('\') = 0 then
      path := Copy(path, 2, Length(path) - 1);

    iChar := path.IndexOf('\');
    if iChar >= 0 then
    begin
      AKey := copy(path, 0, iChar);
      Result := copy(path, iChar + 1, Length(path)- iChar);
    end else
    begin
      AKey := path;
      Result := String.Empty;
    end;
  end;
var
  path: String;
  node: IRegistryNode;
  i: Integer;
  key: String;
begin
  Result := nil;
  node := FRoot;
  path := APath;
  while not path.IsEmpty do
  begin
    path := ExtractNextKey(path, key);

    if key.Equals(node.GetKey) then
      continue
    else
    begin
      for i := 0 to node.Count - 1 do
      if key.Equals(node.Get(i).GetKey) then
      begin
        node := node.Get(i);
        Break;
      end;
    end
  end;

  if node.GetPath = APath then
    Result := node;
end;

function TRegistryTree.GetRoot: IRegistryNode;
begin
  Result := FRoot;
end;

procedure TRegistryTree.Load(ALoader: IRegistryTreeLoader);
begin
  ALoader.Load(FRoot);
end;

procedure TRegistryTree.Build(ARootKey: Winapi.Windows.HKEY; AKey: String);
begin
  FNodeCount := 0;
  FRoot := OpenNode(FRoot, ARootKey, AKey);
end;

function TRegistryTree.OpenNode(AParent: IRegistryNode;
  ARootKey: Winapi.Windows.HKEY; AKey: String): IRegistryNode;
var
  regWin: TRegistry;
  valNode, valKey, vName: String;
  slNodes: TStringList;
  node: TRegistryNode;
  lastIndex: Integer;
begin
  Result := nil;
  regWin := TRegistry.Create;
  try
    regWin.RootKey := ARootKey;
    if not regWin.OpenKey(AKey, False) then
      Exit;

    lastIndex := AKey.LastDelimiter('\') + 1;
    vName := Copy(AKey, lastIndex + 1, AKey.Length - lastIndex);

    Result := TRegistryComposite.Create(AParent, vName);
    Inc(FNodeCount);

    slNodes := TStringList.Create;
    try
      regWin.GetValueNames(slNodes);

      for valNode in slNodes do
      begin
        case regWin.GetDataType(valNode) of
          rdString: begin
            node := TStringRegistryNode.Create(Result, valNode);
            (node as TStringRegistryNode).SetValue(regWin.ReadString(valNode));
            Inc(FNodeCount);
          end;
          rdExpandString: begin
            node := TExpandableStringRegistryNode.Create(Result, valNode);
            (node as TExpandableStringRegistryNode).SetValue(regWin.ReadString(valNode));
            Inc(FNodeCount);
          end;
          rdInteger: begin
            node := TIntegerRegistryNode.Create(Result, valNode);
            (node as TIntegerRegistryNode).SetValue(IntToStr(regWin.ReadInteger(valNode)));
            Inc(FNodeCount);
          end;
          rdBinary: begin
            node := TBinaryRegistryNode.Create(Result, valNode);
            Inc(FNodeCount);
          end;
        end;
        Result.Add(node);
      end;

      slNodes.Clear;
      regWin.GetKeyNames(slNodes);
      for valNode in slNodes do
      begin
        node := TRegistryNode(OpenNode(Result, ARootKey, AKey + '\' + valNode));
        if Assigned(node) then
          Result.Add(node);
      end;
    finally
      FreeAndNil(slNodes);
    end;

  finally
    FreeAndNil(regWin);
  end;
end;

procedure TRegistryTree.Save(AOutput: IRegistryTreeOutput);
begin
  AOutput.Save(FRoot);
end;

{ TRegistryNodeDiff }

constructor TRegistryNodeDiff.Create(AOldNode, ANewNode: IRegistryNode;
  AState: IRegistryNodeState);
begin
  FOldNode := AOldNode;
  FNewNode := ANewNode;
  FState := AState;
end;

function TRegistryNodeDiff.GetNewNode: IRegistryNode;
begin
  Result := FNewNode;
end;

function TRegistryNodeDiff.GetNewNodeValue: String;
begin
  Result := String.Empty;
  if Assigned(FNewNode) then
    Result := FNewNode.GetValue;
end;

function TRegistryNodeDiff.GetOldNode: IRegistryNode;
begin
  Result := FOldNode;
end;

function TRegistryNodeDiff.GetOldNodeValue: String;
begin
  Result := String.Empty;
  if Assigned(FOldNode) then
    Result := FOldNode.GetValue;
end;

function TRegistryNodeDiff.GetKey: String;
begin
  Result := String.Empty;
  if Assigned(FOldNode) then
    Result := FOldNode.GetKey
  else if Assigned(FNewNode) then
    Result := FNewNode.GetKey;
end;

function TRegistryNodeDiff.GetKeyPath: String;
begin
  Result := String.Empty;
  if Assigned(FOldNode) then
    Result := FOldNode.GetPath(False)
  else if Assigned(FNewNode) then
    Result := FNewNode.GetPath(False);
end;

function TRegistryNodeDiff.GetState: IRegistryNodeState;
begin
  Result := FState;
end;

function TRegistryNodeDiff.ToCSVString: String;
begin
  Result := Format('"%s","%s",%s,"%s","%s";',[GetKeyPath, GetKey, NodeStateToStr(Self.GetState),
    GetOldNodeValue, GetNewNodeValue]);
end;

function TRegistryNodeDiff.ToString: String;
begin
  Result := String.Empty;
  case GetState of
    rnsModified: begin
      Result := Format('%s'+ chr(9) + '%s'+ chr(9) + '%s' + chr(9) + '[%s -> %s];', [GetKeyPath, GetKey, NodeStateToStr(Self.GetState),
        GetOldNodeValue, GetNewNodeValue]);
    end;
    rnsInserted: begin
      Result := Format('%s'+ chr(9) + '%s'+ chr(9) +'%s' + chr(9) + '[%s];', [GetKeyPath, GetKey, NodeStateToStr(Self.GetState),
        GetNewNodeValue]);
    end;
    rnsDeleted: begin
      Result := Format('%s' + chr(9) + '%s'+ chr(9) + '%s;', [GetKeyPath, GetKey, NodeStateToStr(Self.GetState)]);
    end;
  end;
end;

{ TRegistryXMLTreeLoader }

constructor TRegistryXMLTreeLoader.Create(const AFileName: String);
begin
  FFileName := AFileName;
end;

procedure TRegistryXMLTreeLoader.Load(var ARoot: IRegistryNode);
var
  i: Integer;
  xmlDoc: IXMLDocument;

  procedure LoadNode(AParent: IRegistryNode; ANode: IXMLNode);
  var
    i: Integer;
    node: IXMLNode;
    regNodeClass: TRegistryNodeClass;
    regNode: TRegistryNode;
  begin
    for i := 0 to ANode.ChildNodes.Count - 1 do
    begin
      node := ANode.ChildNodes.Get(i);

      if not node.HasAttribute(XML_TYPE_TAG) then
      begin
        regNode := TRegistryComposite.Create(AParent, node.Attributes[XML_KEY_TAG]);
        AParent.Add(regNode);
        LoadNode(regNode, node);
        continue;
      end;

      if node.Attributes[XML_TYPE_TAG] = REG_TYPE_STRING then
         regNodeClass := TStringRegistryNode
      else if node.Attributes[XML_TYPE_TAG] = REG_TYPE_EXPSTR then
         regNodeClass := TExpandableStringRegistryNode
      else if node.Attributes[XML_TYPE_TAG] = REG_TYPE_BINARY then
         regNodeClass := TBinaryRegistryNode
      else if node.Attributes[XML_TYPE_TAG] = REG_TYPE_INTEGER then
         regNodeClass := TIntegerRegistryNode;

      regNode := regNodeClass.Create(AParent, node.Attributes[XML_KEY_TAG]);
      regNode.SetValue(PrepareString(VarToStr(node.NodeValue)));
      AParent.Add(regNode);
    end;
  end;

begin
  xmlDoc := TXMLDocument.Create(nil);
  xmlDoc.LoadFromFile(FFileName);
  if (xmlDoc.DocumentElement.NodeName <> XML_ROOT_TAG) then
    raise Exception.Create('Incorrect format of file');

  ARoot := TRegistryComposite.Create(nil, xmlDoc.DocumentElement.Attributes[XML_KEY_TAG]);
  LoadNode(ARoot, xmlDoc.DocumentElement);
end;

function TRegistryXMLTreeLoader.PrepareString(const AText: String): String;
begin
  Result := StringReplace(AText, '&#xA;', Chr(10), [rfReplaceAll]);
  Result := StringReplace(Result, '&#xD', Chr(13), [rfReplaceAll]);
end;

{ TRegistryXMLTreeOutput }

constructor TRegistryXMLTreeOutput.Create(const AFileName: String);
begin
  FFileName := AFileName;
end;

function TRegistryXMLTreeOutput.FormatString(const AText: String): String;
begin
  Result := StringReplace(AText, Chr(10), '&#xA;', [rfReplaceAll]);
  Result := StringReplace(Result, Chr(13), '&#xD', [rfReplaceAll]);
end;

procedure TRegistryXMLTreeOutput.Save(ARoot: IRegistryNode);
var
  xmlDoc: IXMLDocument;
  node: IXMLNode;
  i: Integer;

  procedure NodeToXML(AXMLNode: IXMLNode; ARegistryNode: IRegistryNode);
  var
    i: Integer;
    node: IXMLNode;
  begin
    node := AXMLNode.AddChild(XML_NODE_TAG);
    node.Attributes[XML_KEY_TAG] := ARegistryNode.GetKey;

    case ARegistryNode.GetType of
      rdString: node.Attributes[XML_TYPE_TAG] := REG_TYPE_STRING;
      rdExpandString: node.Attributes[XML_TYPE_TAG] := REG_TYPE_EXPSTR;
      rdInteger: node.Attributes[XML_TYPE_TAG] := REG_TYPE_INTEGER;
      rdBinary: node.Attributes[XML_TYPE_TAG] := REG_TYPE_BINARY;
    end;

    if (ARegistryNode.GetType = rdUnknown) then
    begin
      for i := 0 to ARegistryNode.Count - 1 do
        NodeToXML(node, ARegistryNode.Get(i));
    end else
    begin

      node.NodeValue := FormatString(ARegistryNode.GetValue);
    end;
  end;

begin
  xmlDoc := TXMLDocument.Create(nil);
  xmlDoc.Active := True;
  xmlDoc.Encoding := 'utf-8';

  node := xmlDoc.Node.AddChild(XML_ROOT_TAG);
  node.Attributes[XML_KEY_TAG] := ARoot.GetKey;

  for i := 0 to ARoot.Count - 1 do
    NodeToXML(node, ARoot.Get(i));

  xmlDoc.SaveToFile(FFileName);
  xmlDoc.Active := False;
end;

end.
