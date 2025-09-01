; GenesysApiExplorer.iss - Inno Setup Script
[Setup]
AppName=Genesys API Explorer
AppVersion=1.0.0
DefaultDirName={pf}\Genesys API Explorer
DefaultGroupName=Genesys API Explorer
OutputBaseFilename=GenesysAPIExplorer_Setup
Compression=lzma
SolidCompression=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a &desktop shortcut"; GroupDescription: "Additional icons:"; Flags: unchecked

[Files]
Source: "..\bin\Release\net6.0-windows\publish\GenesysApiExplorer.exe"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Genesys API Explorer"; Filename: "{app}\GenesysApiExplorer.exe"
Name: "{commondesktop}\Genesys API Explorer"; Filename: "{app}\GenesysApiExplorer.exe"; Tasks: "desktopicon"

[Run]
Filename: "{app}\GenesysApiExplorer.exe"; Description: "Launch Genesys API Explorer"; Flags: nowait postinstall skipifsilent

[Code]
var RegionPage: TWizardPage;
var RegionComboBox: TNewComboBox;

procedure InitializeWizard();
begin
  // Insert custom page after the Select Directory page
  RegionPage := CreateCustomPage(wpSelectDir, 'Genesys Cloud Region', 'Select your Genesys Cloud region for API calls:');
  RegionComboBox := TNewComboBox.Create(WizardForm);
  RegionComboBox.Parent := RegionPage.Surface;
  RegionComboBox.Left := 10;
  RegionComboBox.Top := 10;
  RegionComboBox.Width := 220;
  RegionComboBox.Style := csDropDownList;
  // Populate region options (Name (Domain))
  RegionComboBox.Items.Add('US East (mypurecloud.com)');
  RegionComboBox.Items.Add('EU West (Ireland) (mypurecloud.ie)');
  RegionComboBox.Items.Add('AP Southeast (Sydney) (mypurecloud.com.au)');
  RegionComboBox.Items.Add('AP Northeast (Tokyo) (mypurecloud.jp)');
  RegionComboBox.Items.Add('US West (Oregon) (usw2.pure.cloud)');
  RegionComboBox.Items.Add('Canada (cac1.pure.cloud)');
  RegionComboBox.ItemIndex := 0;
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  cfgFile, choice, domain: string;
  iPos: Integer;
begin
  if (CurStep = ssPostInstall) then
  begin
    choice := RegionComboBox.Text;
    // Extract the domain between parentheses
    iPos := Pos('(', choice);
    if iPos > 0 then begin
      domain := Copy(choice, iPos+1, Length(choice));
      domain := Copy(domain, 1, Pos(')', domain)-1);
    end
      else domain := choice;
    // Write region to config file in the install directory
    cfgFile := ExpandConstant('{app}\userconfig.ini');
    if (domain <> '') then
      WriteIniString('Settings', 'Region', domain, cfgFile);
  end;
end;
