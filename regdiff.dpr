program regdiff;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  ActiveX,
  Classes,
  Winapi.Windows,
  System.Generics.Collections,
  RegistryTree in 'RegistryTree.pas',
  CommandLine in 'CommandLine.pas';

resourcestring
  rsRegistryKeyIsNot = 'Registry key is not defined.';
  rsNotValidInputPara = 'Not valid input parameters';
  rsDumpFileIsNotFound = 'Dump file is not found.';
  rsRegistryKeyIsIncorrect = 'Registry key is incorrect.';
  rsRootKeyIsIncorrec = 'Root key is incorrect.';
  rsDumpWasSavedToFi = 'Dump was saved to file';
  rsDumpFilesIsNot = 'Dump file is not exist';

const
  PRORGRAM_VER = '%s version 1.0';
  MODE_DUMP = 'dump';
  MODE_COMPARE = 'compare';
  PARAM_REG_KEY = 'key';
  PARAM_OUT_FILE = 'out';
  PARAM_DUMP_FILE = 'dump';
  PARAM_DUMP_FILE_2 = 'dump2';
var
  commandLine: ICommandLine;
  regTree, regTree2: TRegistryTree;
  diffList: TList<IRegistryNodeDiff>;
  diffNode: IRegistryNodeDiff;
  regNode: IRegistryNode;
  outFile: TStringList;
  regPath, outFileName: String;
  regHKey: Winapi.Windows.HKEY;
begin
  try
    CoInitialize(nil);
    try
      commandLine := CreateCommandLine;
      with commandLine.CreateCommand(MODE_DUMP) do
      begin
        AddTextParam(PARAM_REG_KEY, True, 255);
        AddTextParam(PARAM_OUT_FILE, True, 255);
      end;

      with commandLine.CreateCommand(MODE_COMPARE) do
      begin
        AddTextParam(PARAM_DUMP_FILE, True, 255);
        AddTextParam(PARAM_DUMP_FILE_2, True, 255);
        AddTextParam(PARAM_OUT_FILE, False, 255);
      end;

      if commandLine.IsCommand(MODE_DUMP) then
      begin
        if not IsRegKey(commandLine.GetParam(PARAM_REG_KEY)) then
          raise Exception.Create(rsRegistryKeyIsIncorrect);

        regHKey := StringKeyToHKEY(ExcludeRootKey(commandLine.GetParam(PARAM_REG_KEY), regPath));
        if regHKey = 0 then
          raise Exception.Create(rsRootKeyIsIncorrec);

        if not DirectoryExists(ExtractFileDir(commandLine.GetParam(PARAM_OUT_FILE))) then
          raise Exception.Create(Format('Output folder (%s) is not exist.', [commandLine.GetParam(PARAM_OUT_FILE)]));

        regTree := TRegistryTree.Create;
        try
          regTree.Build(regHKey, regPath);
          regTree.Save(TRegistryXMLTreeOutput.Create(commandLine.GetParam(PARAM_OUT_FILE)));
          writeln(rsDumpWasSavedToFi + ':' + commandLine.GetParam(PARAM_OUT_FILE));
        finally
          FreeAndNil(regTree);
        end;
      end else
      if commandLine.IsCommand(MODE_COMPARE) then
      begin
        regTree := TRegistryTree.Create;
        regTree2 := TRegistryTree.Create;
        try
          if (not FileExists(commandLine.GetParam(PARAM_DUMP_FILE))) then
            raise Exception.Create(rsDumpFilesIsNot + ' ' + commandLine.GetParam(PARAM_DUMP_FILE));

          if (not FileExists(commandLine.GetParam(PARAM_DUMP_FILE_2))) then
            raise Exception.Create(rsDumpFilesIsNot + ' ' + commandLine.GetParam(PARAM_DUMP_FILE_2));

          regTree.Load(TRegistryXMLTreeLoader.Create(commandLine.GetParam(PARAM_DUMP_FILE)));
          regTree2.Load(TRegistryXMLTreeLoader.Create(commandLine.GetParam(PARAM_DUMP_FILE_2)));
          try
            diffList := regTree.Compare(regTree2);
            if commandLine.HasParam(PARAM_OUT_FILE) then
            begin
              outFile := TStringList.Create;
              try
                for diffNode in diffList do
                  outFile.Append(diffNode.ToCSVString);
                outFile.SaveToFile(commandLine.GetParam(PARAM_OUT_FILE));
              finally
                FreeAndNil(outFile);
              end;
            end else
            begin
              for diffNode in diffList do
                Writeln(diffNode.ToString);
            end;
          finally
            FreeAndNil(regTree2);
          end;
        finally
          FreeAndNil(regTree);
        end;
      end else
      begin
        Writeln('Verion 1.0');
        Writeln('Author: heathk1iff');
        Writeln(commandLine.GetHelp);
      end;
    finally
      CoUninitialize();
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
