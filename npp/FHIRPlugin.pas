unit FHIRPlugin;


{
Copyright (c) 2011+, HL7 and Health Intersections Pty Ltd (http://www.healthintersections.com.au)
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

 * Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.
 * Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.
 * Neither the name of HL7 nor the names of its contributors may be used to
   endorse or promote products derived from this software without specific
   prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 'AS IS' AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.
}

{
[27/10/2015 9:52:30 PM] Grahame Grieve: - validation as you type
- json <--> xml conversion
- smart on fhir rest operations
- cds-hook testing
[27/10/2015 9:52:35 PM] Grahame Grieve: other ideas?
[27/10/2015 9:57:43 PM] Grahame Grieve: + fhir path evaluation
[28/10/2015 12:53:56 AM] Ewout Kramer: "validate on server" ?
[28/10/2015 12:54:08 AM] Ewout Kramer: PUT/POST to server?
[28/10/2015 12:55:00 AM] Ewout Kramer: intellisense for  code elements with required bindings?
[28/10/2015 3:20:35 AM] Josh Mandel: Built-in vocab lookup when writing a Coding}

{
Commands:
About the FHIR Plugin
--
Change Format (XML <--> JSON)
Validate Resource
Clear Validation Information
generate diff
--
Connect to Server
--
New Resource (Template)
Open Resource on Server
PUT resource to existing ID
POST resource to new ID
POST resource as a transaction
Validate resource on server
--
Configure Tools
Close the FHIR Toolbox

}
interface

uses
  Windows, SysUtils, Classes, Forms, Vcl.Dialogs, Messages, Consts, UITypes, System.Generics.Defaults, ActiveX,
  NppPlugin, SciSupport,
  FHIR.Support.System,
  FHIR.Support.Objects, FHIR.Support.Generics, FHIR.Support.Stream, FHIR.Support.WInInet,
  FHIR.Support.Text, FHIR.Support.Zip, FHIR.Support.MsXml,

  FHIR.Base.Objects, FHIR.Base.Parser, FHIR.Base.Validator, FHIR.Base.Narrative, FHIR.Base.Factory, FHIR.Base.PathEngine, FHIR.XVersion.Resources,
  FHIR.R4.Constants,
  FHIR.Tools.PathNode, FHIR.Tools.Validator, FHIR.Tools.Resources, FHIR.Tools.Types, FHIR.Tools.Parser, FHIR.Tools.Utilities, FHIR.Tools.Client, FHIR.Tools.Constants,
  FHIR.Npp.Context,
  FHIRPluginSettings, FHIRPluginValidator, FHIR.Tools.Narrative, FHIR.Tools.PathEngine, FHIR.Base.Xhtml, FHIR.Tools.Context, FHIR.Tools.ExpressionComposer,
  FHIR.Client.SmartUtilities, FHIR.Client.SmartLogin, nppBuildcount, PluginUtilities,
  FHIRToolboxForm, AboutForms, SettingsForm, NewResourceForm, FetchResourceForm, PathDialogForms, ValidationOutcomes, CodeGenerationForm,
  FHIR.Cache.PackageManagerDialog, FHIR.Cache.PackageManager,
  FHIRVisualiser, FHIR.Npp.PathDebugger, WelcomeScreen, UpgradePrompt, FHIR.Tools.DiffEngine, ResDisplayForm;

const
  INDIC_INFORMATION = 21;
  INDIC_WARNING = 22;
  INDIC_ERROR = 23;
  INDIC_MATCH = 24;
  LEVEL_INDICATORS : array [TFHIRAnnotationLevel] of Integer = (INDIC_INFORMATION, INDIC_WARNING, INDIC_ERROR, INDIC_MATCH);


type
  TFHIRPlugin = class;

  TFHIRVersionStatus = (vsUnknown, vsGuessed, vsSpecified);

  TFHIRPluginFileInformation = class (TFslObject)
  private
    FVersion : TFHIRVersion;
    FVersionStatus : TFHIRVersionStatus;
    FFormat: TFHIRFormat;
  public
    function link : TFHIRPluginFileInformation; overload;

    property Format : TFHIRFormat read FFormat write FFormat;
    property Version : TFHIRVersion read FVersion write FVersion;
    property VersionStatus : TFHIRVersionStatus read FVersionStatus write FVersionStatus;

    function summary : String;
  end;

  TContextLoadingThread = class(TThread)
  private
    FPlugin : TFHIRPlugin; // no link
    FFactory : TFHIRFactory;
  public
    constructor Create(plugin : TFHIRPlugin; factory : TFHIRFactory);
    Destructor Destroy; override;
    procedure Execute(); override;
  end;

  TUpgradeCheckThread = class(TThread)
  private
    FPlugin : TFHIRPlugin; // no link
    function getServerLink(doc: IXMLDOMDocument2): string;
    function loadXml(b: TFslBuffer): IXMLDOMDocument2;
    function getUpgradeNotes(doc: IXMLDOMDocument2; current: String): string;
  public
    constructor Create(plugin : TFHIRPlugin);
    procedure Execute(); override;
  end;

  TFHIRPlugin = class(TNppPlugin)
  private
    FContext : TFHIRNppContext;
    FFileInfo : TFslMap<TFHIRPluginFileInformation>;
    FCurrentFileInfo : TFHIRPluginFileInformation;
    FCache : TFHIRPackageManager;

    tipShowing : boolean;
    tipText : AnsiString;
    errors : TFslList<TFHIRAnnotation>;
    matches : TFslList<TFHIRAnnotation>;
    errorSorter : TFHIRAnnotationComparer;
    FClient : TFhirClient;
    FCapabilityStatement : TFhirCapabilityStatement;
    init : boolean;
    FLastSrc : String;
    FLastRes : TFHIRResource;
    FUpgradeReference : String;
    FUpgradeNotes : String;
    FCurrentServer : TRegisteredFHIRServer;

    // this procedure handles validation.
    // it is called whene the text of the scintilla buffer changes
    // first task is to clear any existing error notifications - if there is a reset
    // second task is to abort any existing validation process
    // third task is to start valdiating
    procedure NotifyContent(text : String; reset : boolean);

    // Scintilla control
    procedure setUpSquiggles;
    procedure squiggle(level : integer; line, start, length : integer; message : String);
    procedure clearSquiggle(level : integer; line, start, length : integer);

    // fhir stuff
    function determineFormat(src : String) : TFHIRFormat;
    function waitForValidator(version : TFHIRVersion; manualOp : boolean) : boolean;
    function convertIssue(issue: TFhirOperationOutcomeIssueW): TFHIRAnnotation;
    function findPath(path : String; loc : TSourceLocation; context : TArray<TFHIRObject>; base : TFHIRObject; var focus : TArray<TFHIRObject>) : String;
    function locate(res : TFHIRResource; var path : String; var focus : TArray<TFHIRObject>) : boolean;
    function parse(timeLimit : integer; var fmt : TFHIRFormat; var res : TFHIRResource) : boolean; overload;
    function parse(timeLimit : integer; var fmt : TFHIRFormat; var res : TFHIRResourceV) : boolean; overload;

    function parse(cnt : String; fmt : TFHIRFormat) : TFHIRResource; overload;
    function compose(cnt : TFHIRResourceV; fmt : TFHIRFormat) : String; overload;

    procedure evaluatePath(r : TFHIRResource; out items : TFHIRSelectionList; out expr : TFHIRPathExpressionNodeV; out types : TFHIRTypeDetailsV);
    function showOutcomes(fmt : TFHIRFormat; items : TFHIRObjectList; expr : TFHIRPathExpressionNode; types : TFslStringSet) : string;

    // smart on fhir stuff
    function DoSmartOnFHIR(server : TRegisteredFHIRServer) : boolean;
    procedure configureSSL;

    // version tracking
    procedure launchUpgradeCheck;
    procedure CheckUpgrade;

    procedure AnalyseFile;

    // background validation
    procedure validate(r : TFHIRResource);
  public
    constructor Create;
    destructor Destroy; override;

    function connected : boolean;
    property Context : TFHIRNppContext read FContext;

    // user interface
    procedure FuncValidate;
    procedure FuncValidateClear;
    procedure FuncMatchesClear;
    procedure FuncToolbox;
    procedure FuncVisualiser;
    procedure FuncSettings(servers : boolean);
    procedure FuncPackageManager;
    procedure FuncAbout;
    procedure FuncFormat;
    procedure FuncDebugPath;
    procedure FuncJumpToPath;
    procedure FuncExtractPath;
    procedure FuncServers;
    procedure FuncConnect;
    procedure FuncNewResource;
    procedure FuncOpen;
    procedure FuncPUT;
    procedure FuncPOST;
    procedure FuncTransaction;
    procedure FuncServerValidate;
    procedure FuncNarrative;
    procedure FuncDisconnect;
    procedure funcDifference;
    procedure funcGenerateCode;

    procedure reset;
    procedure SetSelection(start, stop : integer);

    // responding to np++ events
    procedure DoNppnReady; override; // install toolbox if necessary
    procedure DoNppnTextModified; override;
    procedure DoNppnBufferChange; override;
    procedure DoNppnDwellStart(offset : integer); override;
    procedure DoNppnDwellEnd; override;
    procedure DoNppnShutdown; override;
    procedure DoStateChanged; override;
    procedure DoNppnFileOpened; override;
    procedure DoNppnFileClosed; override;
  end;

procedure _FuncValidate; cdecl;
procedure _FuncValidateClear; cdecl;
procedure _FuncToolbox; cdecl;
procedure _FuncVisualiser; cdecl;
procedure _FuncAbout; cdecl;
procedure _FuncSettings; cdecl;
procedure _FuncPackageManager; cdecl;
procedure _FuncDebugPath; cdecl;
procedure _FuncExtractPath; cdecl;
procedure _FuncJumpToPath; cdecl;
procedure _FuncFormat; cdecl;
procedure _FuncServers; cdecl;
procedure _FuncConnect; cdecl;
procedure _FuncNewResource; cdecl;
procedure _FuncOpen; cdecl;
procedure _FuncPUT; cdecl;
procedure _FuncPOST; cdecl;
procedure _FuncTransaction; cdecl;
procedure _FuncServerValidate; cdecl;
procedure _FuncNarrative; cdecl;
procedure _FuncDisconnect; cdecl;
procedure _FuncDebug; cdecl;
procedure _FuncDifference; cdecl;
procedure _FuncGenerateCode; cdecl;

var
  FNpp: TFHIRPlugin;

implementation

uses
  IdSSLOpenSSLHeaders,
  FHIR.R2.Factory,
  FHIR.R3.Factory,
  FHIR.R4.Factory;

var
  ms : String;

procedure mcheck(i : integer);
begin
  ms := ms + inttostr(i) +' ';
end;


{ TFHIRPlugin }

constructor TFHIRPlugin.Create;
var
//  sk: TShortcutKey;
  i: Integer;
begin
  inherited;
  FContext := TFHIRNppContext.Create;
  FFileInfo := TFslMap<TFHIRPluginFileInformation>.create;
  FCache := TFHIRPackageManager.Create(true);

  errors := TFslList<TFHIRAnnotation>.create;
  errorSorter := TFHIRAnnotationComparer.create;
  errors.Sort(errorSorter);
  matches := TFslList<TFHIRAnnotation>.create;
  matches.Sort(errorSorter);

  self.PluginName := '&FHIR';
  i := 0;

{  sk.IsCtrl := true;
  sk.IsAlt := true;
  sk.Key := 'F';}

  self.AddFuncItem('&About the FHIR Plugin', _FuncAbout);
  self.AddFuncItem('-', Nil);
  self.AddFuncItem('Change &Format (XML <--> JSON)', _FuncFormat);
  self.AddFuncItem('&Validate Resource', _FuncValidate);
  self.AddFuncItem('Clear Validation Information', _FuncValidateClear);
  self.AddFuncItem('&Make Patch', _FuncDifference);
  self.AddFuncItem('-', Nil);
  self.AddFuncItem('&Jump to Path', _FuncJumpToPath);
  self.AddFuncItem('&Debug Path Expression', _FuncDebugPath);
  self.AddFuncItem('&Extract Path from Cursor', _FuncExtractPath);
  self.AddFuncItem('Generate &Code', _FuncGenerateCode);

  self.AddFuncItem('-', Nil);
  self.AddFuncItem('Connect to &Server', _FuncConnect);
  self.AddFuncItem('-', Nil);
  self.AddFuncItem('&New Resource (Template)', _FuncNewResource);
  self.AddFuncItem('&Open Resource on Server', _FuncOpen);
  self.AddFuncItem('P&UT resource to existing ID', _FuncPUT);
  self.AddFuncItem('&POST resource to new ID', _FuncPOST);
  self.AddFuncItem('POST resource as a &Transaction', _FuncTransaction);
  self.AddFuncItem('Validate &resource on server', _FuncServerValidate);
  self.AddFuncItem('-', Nil);
  self.AddFuncItem('Pac&kage Manager', _FuncPackageManager);
  self.AddFuncItem('Confi&gure Tools', _FuncSettings);
  self.AddFuncItem('Vie&w Toolbox', _FuncToolbox);
  self.AddFuncItem('View Visuali&zer', _FuncVisualiser);
  self.AddFuncItem('Debug Install', _FuncDebug);

  configureSSL;
end;

function TFHIRPlugin.compose(cnt: TFHIRResourceV; fmt: TFHIRFormat): String;
var
  s : TStringStream;
  comp : TFHIRComposer;
begin
  s := TStringStream.Create;
  try
    if fmt = ffXml then
      comp := FContext.Version[FCurrentFileInfo.Version].makeComposer(ffXml)
    else
      comp := FContext.Version[FCurrentFileInfo.Version].makeComposer(ffJson);
    try
      comp.Compose(s, cnt);
      result := s.DataString;
    finally
     comp.free;
    end;
  finally
    s.Free;
  end;
end;

procedure TFHIRPlugin.configureSSL;
begin
  IdOpenSSLSetLibPath(IncludeTrailingBackslash(ExtractFilePath(GetModuleName(HInstance)))+'ssl');
end;

procedure _FuncValidate; cdecl;
begin
  FNpp.FuncValidate;
end;

procedure _FuncValidateClear; cdecl;
begin
  FNpp.FuncValidateClear;
end;

procedure _FuncAbout; cdecl;
begin
  FNpp.FuncAbout;
end;

procedure _FuncVisualiser; cdecl;
begin
  FNpp.FuncVisualiser;
end;

procedure _FuncToolbox; cdecl;
begin
  FNpp.FuncToolbox;
end;

procedure _FuncSettings; cdecl;
begin
  FNpp.FuncSettings(false);
end;

procedure _FuncPackageManager; cdecl;
begin
  FNpp.FuncPackageManager;
end;

procedure _FuncDebugPath; cdecl;
begin
  FNpp.FuncDebugPath;
end;

procedure _FuncJumpToPath; cdecl;
begin
  FNpp.FuncJumpToPath;
end;

procedure _FuncExtractPath; cdecl;
begin
  FNpp.FuncExtractPath;
end;

procedure _FuncFormat; cdecl;
begin
  FNpp.FuncFormat;
end;

procedure _FuncServers; cdecl;
begin
  FNpp.FuncServers;
end;

procedure _FuncConnect; cdecl;
begin
  FNpp.FuncConnect;
end;

procedure _FuncNewResource; cdecl;
begin
  FNpp.FuncNewResource;
end;

procedure _FuncOpen; cdecl;
begin
  FNpp.FuncOpen;
end;

procedure _FuncPUT; cdecl;
begin
  FNpp.FuncPUT;
end;

procedure _FuncPOST; cdecl;
begin
  FNpp.FuncPOST;
end;

procedure _FuncTransaction; cdecl;
begin
  FNpp.FuncTransaction;
end;

procedure _FuncServerValidate; cdecl;
begin
  FNpp.FuncServerValidate;
end;

procedure _FuncGenerateCode; cdecl;
begin
  FNpp.FuncGenerateCode;
end;


procedure _FuncNarrative; cdecl;
begin
  FNpp.FuncNarrative;
end;

procedure _FuncDisconnect; cdecl;
begin
  FNpp.FuncDisconnect;
end;

procedure _FuncDifference; cdecl;
begin
  FNpp.FuncDifference;
end;


procedure _FuncDebug; cdecl;
var
  s : String;
begin
  try
    s := 'plugin: '+inttohex(cardinal(FNpp), 8)+#13#10;
    s := s + 'config: '+IncludeTrailingBackslash(FNpp.GetPluginsConfigDir)+'fhirplugin.json';
    s := s + 'init: '+BoolToStr(FNpp.init)+#13#10;
    s := s + 'client: '+ inttohex(cardinal(FNpp.FClient), 8)+ #13#10;
    s := s + 'conformance: '+ inttohex(cardinal(FNpp.FCapabilityStatement), 8)+ #13#10;
    s := s + 'server: '+ inttohex(cardinal(FNpp.FCurrentServer), 8)+ #13#10;
  except
    on e : exception do
      s := s + 'exception: '+e.Message;
  end;
  ShowMessage(s);
end;

function TFHIRPlugin.connected: boolean;
begin
  result := FClient <> nil;
end;

function TFHIRPlugin.convertIssue(issue : TFhirOperationOutcomeIssueW) : TFHIRAnnotation;
var
  s, e : integer;
  msg : String;
begin
  s := SendMessage(NppData.ScintillaMainHandle, SCI_FINDCOLUMN, StrToIntDef(issue.element.Tags['s-l'], 1)-1, StrToIntDef(issue.element.Tags['s-c'], 1)-1);
  e := SendMessage(NppData.ScintillaMainHandle, SCI_FINDCOLUMN, StrToIntDef(issue.element.Tags['e-l'], 1)-1, StrToIntDef(issue.element.Tags['e-c'], 1)-1);
  if (e = s) then
    e := s + 1;
  msg := issue.display;
  case issue.severity of
    isWarning : result := TFHIRAnnotation.create(alWarning, StrToIntDef(issue.element.Tags['s-l'], 1)-1, s, e, msg, msg);
    isInformation : result := TFHIRAnnotation.create(alHint, StrToIntDef(issue.element.Tags['s-l'], 1)-1, s, e, msg, msg);
  else
    result := TFHIRAnnotation.create(alError, StrToIntDef(issue.element.Tags['s-l'], 1)-1, s, e, msg, msg);
  end;
end;

procedure TFHIRPlugin.FuncValidate;
var
  src : String;
  buffer : TFslBuffer;
  error : TFHIRAnnotation;
  iss : TFhirOperationOutcomeIssueW;
  ctxt: TFHIRValidatorContext;
  val : TFHIRValidatorV;
begin
  FuncValidateClear;
  if not waitForValidator(FCurrentFileInfo.Version, true) then
    exit;

  if (FCurrentFileInfo.Format <> ffUnspecified) then
  begin
    src := CurrentText;
    try
      buffer := TFslBuffer.Create;
      try
        buffer.AsText := src;
        ctxt := TFHIRValidatorContext.Create;
        try
          ctxt.ResourceIdRule := risOptional;
          ctxt.OperationDescription := 'validate';
          val := FContext.Version[FCurrentFileInfo.Version].makeValidator;
          try
            try
              val.validate(ctxt, buffer, FCurrentFileInfo.Format);
            except
              on e : exception do
              begin
                errors.add(TFHIRAnnotation.create(alError, 0, 0, 0, 'Validation Processf Failed: '+e.Message, e.Message));
                raise;
              end;
            end;
          finally
            val.free;
          end;
          for iss in ctxt.Issues do
            errors.add(convertIssue(iss));
          if not ValidationSummary(self, ctxt.Issues) then
            MessageBeep(MB_OK);
        finally
          ctxt.Free;
        end;
      finally
        buffer.Free;
      end;
    except
      on e: Exception do
      begin
        if not ValidationError(self, e.message) then
          errors.Add(TFHIRAnnotation.create(alError, 0, 0, 4, e.Message, e.Message));
      end;
    end;
  end
  else if not ValidationError(self, 'This does not appear to be valid FHIR content') then
    errors.Add(TFHIRAnnotation.create(alError, 0, 0, 4, 'This does not appear to be valid FHIR content', ''));
  setUpSquiggles;
  for error in errors do
    squiggle(LEVEL_INDICATORS[error.level], error.line, error.start, error.stop - error.start, error.message);
  if FHIRVisualizer <> nil then
    FHIRVisualizer.setValidationOutcomes(errors);
end;

procedure TFHIRPlugin.FuncMatchesClear;
var
  annot : TFHIRAnnotation;
begin
  for annot in matches do
    clearSquiggle(LEVEL_INDICATORS[annot.level], annot.line, annot.start, annot.stop - annot.start);
  matches.Clear;
  if tipShowing then
    mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_CALLTIPCANCEL, 0, 0));
  tipText := '';
end;

procedure TFHIRPlugin.FuncValidateClear;
var
  annot : TFHIRAnnotation;
begin
  for annot in errors do
    clearSquiggle(LEVEL_INDICATORS[annot.level], annot.line, annot.start, annot.stop - annot.start);
  errors.Clear;
  if tipShowing then
    mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_CALLTIPCANCEL, 0, 0));
  tipText := '';
end;

procedure TFHIRPlugin.FuncVisualiser;
begin
  if (not Assigned(FHIRVisualizer)) then
    FHIRVisualizer := TFHIRVisualizer.Create(self, 2);
  FHIRVisualizer.Show;
end;

function SplitElement(var src : String) : String;
var
  i : integer;
  s : string;
begin
  if src = '' then
    exit('');

  if src.StartsWith('<?') then
    s := '?>'
  else if src.StartsWith('<!--') then
    s := '->'
  else if src.StartsWith('<!DOCTYPE') then
    s := ']>'
  else
    s := '>';

  i := 1;
  while (i <= length(src)) and not (src.Substring(i).StartsWith(s)) do
    inc(i);
  inc(i, length(s));
  result := src.Substring(0, i);
  src := src.Substring(i).trim;
end;

function TFHIRPlugin.determineFormat(src: String): TFHIRFormat;
var
  s : String;
begin
  result := ffUnspecified; // null
  src := src.Trim;
  if (src <> '') then
    begin
    if src[1] = '<' then
    begin
      while src.StartsWith('<!') or src.StartsWith('<?') do
        splitElement(src);
      s := splitElement(src);
      if s.Contains('"http://hl7.org/fhir"') then
        result := ffXml
      else if s.Contains('''http://hl7.org/fhir''') then
        result := ffXml
    end
    else if src[1] = '{' then
    begin
      if src.Contains('"resourceType"') then
        result := ffJson;
    end;
  end;
end;

procedure TFHIRPlugin.launchUpgradeCheck;
begin
  // TUpgradeCheckThread.create(self);
end;

function TFHIRPlugin.locate(res: TFHIRResource; var path: String; var focus : TArray<TFHIRObject>): boolean;
var
  sp : integer;
  loc : TSourceLocation;
begin
  sp := SendMessage(NppData.ScintillaMainHandle, SCI_GETCURRENTPOS, 0, 0);
  loc.line := SendMessage(NppData.ScintillaMainHandle, SCI_LINEFROMPOSITION, sp, 0)+1;
  loc.col := sp - SendMessage(NppData.ScintillaMainHandle, SCI_POSITIONFROMLINE, loc.line-1, 0)+1;
  path := findPath(CODES_TFHIRResourceType[res.ResourceType], loc, [], res, focus);
  result := path <> '';
end;

procedure TFHIRPlugin.FuncServers;
begin
  ShowMessage('not done yet');
end;

procedure TFHIRPlugin.FuncServerValidate;
begin
  if (FClient = nil) then
  begin
    MessageDlg('You must connect to a server first', mtInformation, [mbok], 0);
    exit;
  end;
  ShowMessage('not done yet');
end;

procedure TFHIRPlugin.FuncGenerateCode;
var
  fmt : TFHIRFormat;
  s : TStringStream;
  res : TFHIRResource;
  comp : TFHIRComposer;
begin
  if not init then
    exit;
  if not waitForValidator(FCurrentFileInfo.Version, true) then
    exit;

  if (parse(0, fmt, res)) then
  try
    CodeGeneratorForm := TCodeGeneratorForm.create(self);
    try
      CodeGeneratorForm.Resource := res.Link;
      CodeGeneratorForm.Context := FContext.Version[FCurrentFileInfo.Version].Worker.Link as TFHIRWorkerContext;
      CodeGeneratorForm.showModal;
    finally
      CodeGeneratorForm.free;
    end;
  finally
    res.Free;
  end
  else
    ShowMessage('This does not appear to be valid FHIR content');
end;

procedure TFHIRPlugin.FuncSettings(servers : boolean);
var
  a: TSettingForm;
begin
  a := TSettingForm.Create(self);
  try
    if servers then
      a.PageControl1.ActivePageIndex := 2
    else
      a.PageControl1.ActivePageIndex := 0;
    a.versions := FContext.versions.Link;
    a.Context := FContext.link;
    a.ShowModal;
  finally
    a.Free;
  end;
end;

procedure TFHIRPlugin.FuncPackageManager;
begin
  PackageCacheForm := TPackageCacheForm.Create(self);
  try
    PackageCacheForm.ShowModal;
  finally
    PackageCacheForm.Free;
  end;
end;

procedure TFHIRPlugin.FuncAbout;
var
  a: TAboutForm;
begin
  a := TAboutForm.Create(self);
  try
    a.lblDefinitions.Caption := FContext.VersionInfo;
    a.ShowModal;
  finally
    a.Free;
  end;
end;

procedure TFHIRPlugin.FuncConnect;
var
  index : integer;
  server : TRegisteredFHIRServer;
  ok : boolean;
begin
  index := 0;
  server := TRegisteredFHIRServer(FHIRToolbox.cbxServers.Items.Objects[FHIRToolbox.cbxServers.ItemIndex]).link;
  try
    try
      try
        OpMessage('Connecting to Server', 'Connecting to Server '+server.fhirEndpoint);
        FClient := TFhirClients.makeHTTP(FContext.Version[COMPILED_FHIR_VERSION].Worker.link as TFHIRWorkerContext, server.fhirEndpoint, false, 5000);
        ok := true;
        if server.SmartAppLaunchMode <> salmNone then
          if not DoSmartOnFHIR(server) then
          begin
            ok := false;
            FuncDisconnect;
          end;

        if ok then
        begin
          try
            FClient.format := ffXml;
            FCapabilityStatement := FClient.conformance(false);
          except
            FClient.format := ffJson;
            FCapabilityStatement := FClient.conformance(false);
          end;
          FCapabilityStatement.checkCompatible();
          if (Assigned(FHIRToolbox)) then
            if FClient.smartToken = nil then
              FHIRToolbox.connected(server.name, server.fhirEndpoint, '', '')
            else
              FHIRToolbox.connected(server.name, server.fhirEndpoint, FClient.smartToken.username, FClient.smartToken.scopes);
          FCurrentServer := server.Link;
          if assigned(FHIRVisualizer) and (FClient.smartToken <> nil) then
            FHIRVisualizer.CDSManager.connectToServer(server, FClient.smartToken);
        end;
      finally
        OpMessage('', '');
      end;
    except
      on e : Exception do
      begin
        MessageDlg('Error connecting to server: '+e.Message, mtError, [mbok], 0);
        FuncDisconnect;
      end;
    end;
  finally
    server.Free;
  end;
end;

procedure TFHIRPlugin.FuncDisconnect;
begin
  if (Assigned(FHIRVisualizer)) and (FCurrentServer <> nil) then
     FHIRVisualizer.CDSManager.disconnectFromServer(FCurrentServer);
  if (Assigned(FHIRToolbox)) then
    FHIRToolbox.disconnected;
  if (Assigned(FetchResourceFrm)) then
    FreeAndNil(FetchResourceFrm);
  FCurrentServer.Free;
  FCurrentServer := nil;
  FClient.Free;
  FClient := nil;
  FCapabilityStatement.Free;
  FCapabilityStatement := nil;
end;


function TFHIRPlugin.findPath(path : String; loc : TSourceLocation; context : TArray<TFHIRObject>; base : TFHIRObject; var focus : TArray<TFHIRObject>) : String;
var
  i, j : integer;
  pl : TFHIRPropertyList;
  p : TFHIRProperty;
  list : TArray<TFHIRObject>;
begin
  setlength(list, length(context) + 1);
  for i := 0 to length(context) - 1 do
    list[i] := context[i];
  list[length(list)-1] := base;

  if locLessOrEqual(loc, base.LocationEnd) then
  begin
    result := path;
    focus := list;
  end
  else
  begin
    result := '';
    pl := base.createPropertyList(false);
    try
      for i := pl.Count - 1 downto 0 do
      begin
        p := pl[i];
        if (p.hasValue) and locGreatorOrEqual(loc, p.Values[0].LocationStart) then
        begin
          path := path + '.'+p.Name;
          if p.IsList then
          begin
            for j := p.Values.Count - 1 downto 0 do
              if (result = '') and locGreatorOrEqual(loc, p.Values[j].LocationStart) then
                result := findPath(path+'.item('+inttostr(j)+')', loc, list, p.Values[j], focus);
          end
          else
            result := findPath(path, loc, list, p.Values[0], focus);
          break;
        end;
      end;
    finally
      pl.Free;
    end;
  end;
end;

procedure TFHIRPlugin.FuncExtractPath;
var
  fmt : TFHIRFormat;
  res : TFHIRResourceV;
  sp : integer;
  focus : TArray<TFHIRObject>;
  loc : TSourceLocation;
begin
  if assigned(FHIRToolbox) and (parse(0, fmt, res)) then
  try
    sp := SendMessage(NppData.ScintillaMainHandle, SCI_GETCURRENTPOS, 0, 0);
    loc.line := SendMessage(NppData.ScintillaMainHandle, SCI_LINEFROMPOSITION, sp, 0)+1;
    loc.col := sp - SendMessage(NppData.ScintillaMainHandle, SCI_POSITIONFROMLINE, loc.line-1, 0)+1;
    FHIRToolbox.mPath.Text := findPath(res.fhirType, loc, [], res, focus);
  finally
    res.Free;
  end;
end;

procedure TFHIRPlugin.FuncFormat;
var
  fmt : TFHIRFormat;
  s : TStringStream;
  res : TFHIRResourceV;
  comp : TFHIRComposer;
begin
  if not init then
    exit;
  if (parse(0, fmt, res)) then
  try
    FuncValidateClear;
    FuncMatchesClear;
    if fmt = ffJson then
      comp := FContext.Version[COMPILED_FHIR_VERSION].makeComposer(ffXml)
    else
      comp := FContext.Version[COMPILED_FHIR_VERSION].makeComposer(ffJson);
    s := TStringStream.Create('');
    try
      comp.Compose(s, res);
      CurrentText := s.DataString;
      FCurrentFileInfo.Format := comp.Format;
    finally
      s.Free;
      comp.Free;
    end;
  finally
    res.Free;
  end
  else
    ShowMessage('This does not appear to be valid FHIR content');
end;

procedure TFHIRPlugin.FuncJumpToPath;
var
  fmt : TFHIRFormat;
  res : TFHIRResource;
  items : TFHIRSelectionList;
  expr : TFHIRPathExpressionNodeV;
  engine : TFHIRPathEngineV;
  sp, ep : integer;
begin
  if assigned(FHIRToolbox) and (FHIRToolbox.hasValidPath) then
  begin
    if not waitForValidator(FCurrentFileInfo.Version, true) then
      exit;
    if parse(0, fmt, res) then
    try
      engine := FContext.Version[FCurrentFileInfo.Version].makePathEngine;
      try
        expr := engine.parseV(FHIRToolbox.mPath.Text);
        try
          items := engine.evaluate(nil, res, expr);
          try
            if (items.Count > 0) and not isNullLoc(items[0].value.LocationStart) then
            begin
              sp := SendMessage(NppData.ScintillaMainHandle, SCI_FINDCOLUMN, items[0].value.LocationStart.line - 1, items[0].value.LocationStart.col-1);
              ep := SendMessage(NppData.ScintillaMainHandle, SCI_FINDCOLUMN, items[0].value.LocationEnd.line - 1, items[0].value.LocationEnd.col-1);
              SetSelection(sp, ep);
            end
            else
              MessageBeep(MB_ICONERROR);
          finally
            items.Free;
          end;
        finally
          expr.Free;
        end;
      finally
        engine.Free;
      end;
    finally
      res.Free;
    end;
  end
  else
    MessageDlg('Enter a FHIRPath statement in the toolbox editor', mtInformation, [mbok], 0);
end;

procedure TFHIRPlugin.FuncNarrative;
var
  buffer : TFslBuffer;
  fmt : TFHIRFormat;
  s : TStringStream;
  res : TFHIRResource;
  comp : TFHIRComposer;
  d : TFhirDomainResource;
  narr : TFHIRNarrativeGeneratorBase;
begin
  if not waitForValidator(FCurrentFileInfo.Version, true) then
    exit;
  if (parse(0, fmt, res)) then
  try
    FuncValidateClear;
    FuncMatchesClear;
    if (res is TFhirDomainResource) then
    begin
      d := res as TFhirDomainResource;
      d.text := nil;
      narr := FContext.Version[FCurrentFileInfo.Version].makeNarrative;
      try
        narr.generate(d);
      finally
        narr.Free;
      end;
    end;

    comp := FContext.Version[FCurrentFileInfo.Version].makeComposer(fmt);
    try
      s := TStringStream.Create('');
      try
        comp.Compose(s, res);
        CurrentText := s.DataString;
      finally
        s.Free;
      end;
    finally
      comp.Free;
    end;
  finally
    res.Free;
  end
  else
    ShowMessage('This does not appear to be valid FHIR content');
end;

procedure TFHIRPlugin.FuncNewResource;
begin
  if not waitForValidator(FCurrentFileInfo.Version, true) then
    exit;
  ResourceNewForm := TResourceNewForm.Create(self);
  try
    ResourceNewForm.Context := FContext.Version[FCurrentFileInfo.Version].Worker.Link as TFHIRWorkerContext;
    ResourceNewForm.ShowModal;
  finally
    FreeAndNil(ResourceNewForm);
  end;
end;

procedure TFHIRPlugin.FuncOpen;
var
  res : TFHIRResource;
  comp : TFHIRComposer;
  s : TStringStream;
begin
  if (FClient = nil) then
  begin
    MessageDlg('You must connect to a server first', mtInformation, [mbok], 0);
    exit;
  end;
  if not waitForValidator(FCurrentFileInfo.Version, true) then
    exit;
  if not assigned(FetchResourceFrm) then
    FetchResourceFrm := TFetchResourceFrm.create(self);
  FetchResourceFrm.Conformance := FCapabilityStatement.link;
  FetchResourceFrm.Client := FClient.link;
  FetchResourceFrm.Profiles := TFHIRPluginValidatorContext(FContext.Version[FCurrentFileInfo.Version].Worker).Profiles.Link;
  if FetchResourceFrm.ShowModal = mrOk then
  begin
    res := FClient.readResource(FetchResourceFrm.SelectedType, FetchResourceFrm.SelectedId);
    try
      if FetchResourceFrm.rbJson.Checked then
        comp := FContext.Version[FCurrentFileInfo.Version].makeComposer(ffJson)
      else
        comp := FContext.Version[FCurrentFileInfo.Version].makeComposer(ffXml);
      try
        s := TStringStream.Create;
        try
          comp.Compose(s, res);
          NewFile(s.DataString);
          if FetchResourceFrm.rbJson.Checked then
            saveFileAs(IncludeTrailingPathDelimiter(SystemTemp)+CODES_TFhirResourceType[res.ResourceType]+'-'+res.id+'.json')
          else
            saveFileAs(IncludeTrailingPathDelimiter(SystemTemp)+CODES_TFhirResourceType[res.ResourceType]+'-'+res.id+'.xml');
        finally
          s.Free;
        end;
      finally
        comp.Free;
      end;
    finally
      res.Free;
    end;
  end;
end;

procedure TFHIRPlugin.FuncDebugPath;
var
  src : String;
  fmt : TFHIRFormat;
  s : TStringStream;
  res : TFHIRResource;
  query : TFHIRPathEngine;
  item : TFHIRSelection;
  allSource : boolean;
  sp, ep : integer;
  annot : TFHIRAnnotation;
  types : TFHIRTypeDetailsV;
  items : TFHIRSelectionList;
  expr : TFHIRPathExpressionNode;
  ok : boolean;
begin
  FuncMatchesClear;
  if not waitForValidator(FCurrentFileInfo.Version, true) then
    exit;

  if (parse(0, fmt, res)) then
  try
    FuncMatchesClear;
    ok := RunPathDebugger(self, FContext.Version[FCurrentFileInfo.Version].Worker, FContext.Version[FCurrentFileInfo.Version].Factory, res, res, FHIRToolbox.mPath.Text, fmt, types, items);
    try
      if ok then
      begin
        allSource := true;
        for item in items do
          allSource := allSource and not isNullLoc(item.value.LocationStart);

        if Items.Count = 0 then
          pathOutcomeDialog(self, FHIRToolbox.mPath.Text, CODES_TFHIRResourceType[res.ResourceType], types, pomNoMatch, 'no items matched')
        else if not allSource then
          pathOutcomeDialog(self, FHIRToolbox.mPath.Text, CODES_TFHIRResourceType[res.ResourceType], types, pomNoMatch, query.convertToString(items))
        else
        begin
          if (items.Count = 1) then
            pathOutcomeDialog(self, FHIRToolbox.mPath.Text, CODES_TFHIRResourceType[res.ResourceType], types, pomMatch, '1 matching item')
          else
            pathOutcomeDialog(self, FHIRToolbox.mPath.Text, CODES_TFHIRResourceType[res.ResourceType], types, pomMatch, inttostr(items.Count)+' matching items');
        end;
      end;
    finally
      types.Free;
      items.Free;
    end;
  finally
    res.Free;
  end
  else
    ShowMessage('This does not appear to be valid FHIR content');
end;

procedure TFHIRPlugin.funcDifference;
var
  current, original, output : string;
  fmtc, fmto : TFHIRFormat;
  rc, ro : TFHIRResourceV;
  op : TFHIRParametersW;
  diff : TDifferenceEngine;
  html : String;
begin
  try
    if not waitForValidator(FCurrentFileInfo.Version, true) then
      exit;

    current := CurrentText;
    fmtc := determineFormat(current);
    if (fmtc = ffUnspecified) then
      raise Exception.Create('Unable to parse current content');
    original := FileToString(CurrentFileName, TEncoding.UTF8);
    fmto := determineFormat(current);
    if (fmto = ffUnspecified) then
      raise Exception.Create('Unable to parse original file');

    rc := parse(current, fmtc);
    try
      ro := parse(original, fmto);
      try
        diff := TDifferenceEngine.Create(FContext.Version[FCurrentFileInfo.Version].Worker.link as TFHIRWorkerContext, FContext.Version[FCurrentFileInfo.Version].Factory.link);
        try
          op := diff.generateDifference(ro, rc, html);
          try
            output := compose(op.Resource, fmtc);
            ShowResource(self, 'Difference', html, output);
          finally
            op.free;
          end;
        finally
          diff.Free;
        end;
      finally
        ro.Free;
      end;
    finally
      rc.free;
    end;
  except
    on e : exception do
      MessageDlg(e.Message, mtError, [mbok], 0);
  end;
end;

procedure TFHIRPlugin.FuncPOST;
var
  id : String;
  fmt : TFHIRFormat;
  s : TStringStream;
  res : TFHIRResource;
  comp : TFHIRComposer;
begin
  if (FClient = nil) then
  begin
    MessageDlg('You must connect to a server first', mtInformation, [mbok], 0);
    exit;
  end;
  if (parse(0, fmt, res)) then
  try
    FuncValidateClear;
    FuncMatchesClear;
    FClient.createResource(res, id).Free;
    res.id := id;
    if fmt = ffXml then
      comp := FContext.Version[FCurrentFileInfo.Version].makeComposer(ffXml)
    else
      comp := FContext.Version[FCurrentFileInfo.Version].makeComposer(ffJson);
    try
      s := TStringStream.Create('');
      try
        comp.Compose(s, res);
        CurrentText := s.DataString;
      finally
        s.Free;
      end;
    finally
      comp.Free;
    end;
    if fmt = ffJson then
      saveFileAs(IncludeTrailingPathDelimiter(ExtractFilePath(currentFileName))+CODES_TFhirResourceType[res.ResourceType]+'-'+id+'.json')
    else
      saveFileAs(IncludeTrailingPathDelimiter(ExtractFilePath(currentFileName))+CODES_TFhirResourceType[res.ResourceType]+'-'+id+'.xml');
    ShowMessage('POST completed. The resource ID has been updated');
  finally
    res.Free;
  end
  else
    ShowMessage('This does not appear to be valid FHIR content');
end;

procedure TFHIRPlugin.FuncPUT;
var
  src : String;
  fmt : TFHIRFormat;
  res : TFHIRResource;
begin
  if (FClient = nil) then
  begin
    MessageDlg('You must connect to a server first', mtInformation, [mbok], 0);
    exit;
  end;
  if (parse(0, fmt, res)) then
  try
    if (res.id = '') then
      ShowMessage('Cannot PUT this as it does not have an id')
    else
    begin
      FClient.updateResource(res);
      ShowMessage('PUT succeded')
    end;
  finally
    res.Free;
  end
  else
    ShowMessage('This does not appear to be valid FHIR content');
end;

procedure TFHIRPlugin.FuncToolbox;
begin
  if (not Assigned(FHIRToolbox)) then
    FHIRToolbox := TFHIRToolbox.Create(self, 1);
  FHIRToolbox.Show;
end;

procedure TFHIRPlugin.FuncTransaction;
var
  id : String;
  fmt : TFHIRFormat;
  r, res : TFHIRResource;
  s : TStringStream;
  comp : TFHIRComposer;
begin
  if (FClient = nil) then
  begin
    MessageDlg('You must connect to a server first', mtInformation, [mbok], 0);
    exit;
  end;
  if (parse(0, fmt, res)) then
  try
    r.id := '';
    if r.ResourceType <> frtBundle then
      ShowMessage('This is not a Bundle')
    else
    begin
      res := FClient.transaction(r as TFhirBundle);
      try
        if (MessageDlg('Success. Open transaction response?', mtConfirmation, mbYesNo, 0) = mrYes) then
        begin
          comp := FClient.makeComposer(FClient.format, OutputStylePretty);
          try
            s := TStringStream.Create;
            try
              comp.Compose(s, res);
              NewFile(s.DataString);
              saveFileAs(IncludeTrailingPathDelimiter(SystemTemp)+CODES_TFhirResourceType[res.ResourceType]+'-'+res.id+EXT_ACTUAL_TFHIRFormat[FClient.format]);
            finally
              s.Free;
            end;
          finally
            comp.Free;
          end;
        end;
      finally
        res.Free;
      end;
    end;
  finally
    r.Free;
  end
  else
    ShowMessage('This does not appear to be valid FHIR content');
end;

procedure TFHIRPlugin.NotifyContent(text: String; reset: boolean);
begin
  squiggle(INDIC_ERROR, 0, 2, 4, 'test');
end;

function TFHIRPlugin.parse(timeLimit: integer; var fmt: TFHIRFormat; var res: TFHIRResourceV): boolean;
var
  src : String;
  s : TStringStream;
  prsr : TFHIRParser;
begin
  if FCurrentFileInfo.Format = ffUnspecified then
    exit(false);

  result := true;
  fmt := FCurrentFileInfo.Format;
  src := CurrentText;
  s := TStringStream.Create(src);
  try
    prsr := FContext.Version[FCurrentFileInfo.Version].makeParser(fmt);
    try
      prsr.timeLimit := timeLimit;
      prsr.KeepLineNumbers := true;
      prsr.source := s;
      try
        prsr.Parse;
      except
        // actually, we don't care why this excepted.
        on e : Exception do
        begin
          exit(false);
        end;
      end;
      res := prsr.resource.Link;
    finally
      prsr.Free;
    end;
  finally
    s.free;
  end;
end;

function TFHIRPlugin.parse(cnt: String; fmt: TFHIRFormat): TFHIRResource;
var
  prsr : TFHIRParser;
  s : TStringStream;
begin
  s := TStringStream.Create(cnt, TEncoding.UTF8);
  try
    prsr := FContext.Version[FCurrentFileInfo.Version].makeParser(FCurrentFileInfo.Format);
    try
      prsr.KeepLineNumbers := false;
      prsr.source := s;
      prsr.Parse;
      result := prsr.resource.Link as TFHIRResource;
    finally
      prsr.Free;
    end;
  finally
    s.free;
  end;
end;

function TFHIRPlugin.parse(timeLimit : integer; var fmt : TFHIRFormat; var res : TFHIRResource) : boolean;
var
  src : String;
  s : TStringStream;
  prsr : TFHIRParser;
begin
  src := CurrentText;
  fmt := determineFormat(src);
  res := nil;
  result := fmt <> ffUnspecified;
  if (result) then
  begin
    s := TStringStream.Create(src);
    try
      prsr := FContext.Version[FCurrentFileInfo.Version].makeParser(FCurrentFileInfo.Format);
      try
        prsr.timeLimit := timeLimit;
        prsr.KeepLineNumbers := true;
        prsr.source := s;
        try
          prsr.Parse;
        except
          // actually, we don't care why this excepted.
          on e : Exception do
          begin
            exit(false);
          end;
        end;
        res := prsr.resource.Link as TFHIRResource;
      finally
        prsr.Free;
      end;
    finally
      s.free;
    end;
  end;
end;

procedure TFHIRPlugin.reset;
begin
  FLastSrc := #1;
end;

procedure TFHIRPlugin.SetSelection(start, stop: integer);
begin
  SendMessage(NppData.ScintillaMainHandle, SCI_SETSEL, start, stop);
end;

procedure TFHIRPlugin.setUpSquiggles;
begin
  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_INDICSETSTYLE, INDIC_INFORMATION, INDIC_SQUIGGLE));
  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_INDICSETSTYLE, INDIC_WARNING, INDIC_SQUIGGLE));
  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_INDICSETSTYLE, INDIC_ERROR, INDIC_SQUIGGLE));
  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_INDICSETSTYLE, INDIC_MATCH, INDIC_SQUIGGLE));

  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_INDICSETFORE, INDIC_INFORMATION, $770000));
  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_INDICSETFORE, INDIC_WARNING, $7777FF));
  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_INDICSETFORE, INDIC_ERROR, $000077));
  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_INDICSETFORE, INDIC_MATCH, $007700));

  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_SETMOUSEDWELLTIME, 200, 0));

{  squiggle(INDIC_INFORMATION, 0, 3);
  squiggle(INDIC_WARNING, 4, 3);
  squiggle(INDIC_ERROR, 8, 3);
  squiggle(INDIC_MATCH, 11, 3); }
end;

function TFHIRPlugin.showOutcomes(fmt : TFHIRFormat; items : TFHIRObjectList; expr : TFHIRPathExpressionNode; types : TFslStringSet): string;
var
  comp : TFHIRExpressionNodeComposer;
begin
  comp := TFHIRExpressionNodeComposer.create(FContext.Version[FCurrentFileInfo.Version].Worker.link, OutputStylePretty, 'en');
  try
    result := comp.Compose(expr, fmt, items, types);
  finally
    comp.Free;
  end;
end;

procedure TFHIRPlugin.squiggle(level, line, start, length: integer; message : String);
begin
  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_SETINDICATORCURRENT, level, 0));
  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_INDICATORFILLRANGE, start, length));
  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_ANNOTATIONSETTEXT, line, LPARAM(PAnsiChar(message))));
end;


procedure TFHIRPlugin.validate(r: TFHIRResource);
begin
  // todo
end;

function TFHIRPlugin.waitForValidator(version: TFHIRVersion; manualOp : boolean): boolean;
var
  status : TFHIRVersionLoadingStatus;
begin
  result := true;
  status := FContext.VersionLoading[version];
  while status <> vlsLoaded do
  begin
    if status = vlsLoadingFailed then
      raise Exception.Create('Unable to load definitions for release '+CODES_TFHIRVersion[Version]);
    if status in [vlsNotSupported, vlsNotLoaded] then
      raise Exception.Create('Release '+CODES_TFHIRVersion[Version]+' not supported or Loaded');
    if manualop then
      sleep(1000)
    else
      exit(false);
    status := FContext.VersionLoading[version];
  end;
end;

procedure TFHIRPlugin.AnalyseFile;
var
  info : TFHIRPluginFileInformation;
  src : String;
begin
  info := TFHIRPluginFileInformation.Create;
  try
    src := CurrentText;
    info.Format := determineFormat(src);
    info.Version := fhirVersionUnknown;
    info.VersionStatus := vsUnknown;
    FFileInfo.AddOrSetValue(currentFileName, info.Link);
    FCurrentFileInfo := info;
  finally
    info.free;
  end;
end;

procedure TFHIRPlugin.CheckUpgrade;
var
  s : String;
begin
  if FUpgradeReference <> '' then
  begin
    s := FUpgradeReference;
    FUpgradeReference := '';
    ShowUpgradeprompt(self, s, FUpgradeNotes);
  end;
end;

procedure TFHIRPlugin.clearSquiggle(level, line, start, length: integer);
begin
  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_SETINDICATORCURRENT, level, 0));
  mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_INDICATORCLEARRANGE, start, length));
end;

destructor TFHIRPlugin.Destroy;
begin
  FCache.Free;
  FCurrentServer.Free;
  FLastRes.free;
  FFileInfo.Free;
  inherited;
end;

procedure TFHIRPlugin.DoNppnReady;
begin
  Settings := TFHIRPluginSettings.create(IncludeTrailingPathDelimiter(GetPluginsConfigDir)+'fhirplugin.json',
    [fhirVersionRelease2, fhirVersionRelease3, fhirVersionRelease4]);
  if (Settings.TerminologyServer = '') then
    Settings.TerminologyServer := 'http://tx.fhir.org/r3';
  if Settings.loadR2 then
    FContext.VersionLoading[fhirVersionRelease2] := vlsLoading;
  if Settings.loadR3 then
    FContext.VersionLoading[fhirVersionRelease3] := vlsLoading;
  if Settings.loadR4 then
    FContext.VersionLoading[fhirVersionRelease4] := vlsLoading;
  reset;
  if Settings.loadR2 and FCache.packageExists('hl7.fhir.core', '1.0.2') then
    TContextLoadingThread.create(self, TFHIRFactoryR2.create)
  else
    FContext.VersionLoading[fhirVersionRelease2] := vlsNotLoaded;
  if Settings.loadR3 and FCache.packageExists('hl7.fhir.core', '3.0.1') then
    TContextLoadingThread.create(self, TFHIRFactoryR3.create)
  else
    FContext.VersionLoading[fhirVersionRelease3] := vlsNotLoaded;
  if Settings.loadR4 and FCache.packageExists('hl7.fhir.core', FHIR.R4.Constants.FHIR_GENERATED_VERSION) then
    TContextLoadingThread.create(self, TFHIRFactoryR4.create)
  else
    FContext.VersionLoading[fhirVersionRelease4] := vlsNotLoaded;
  launchUpgradeCheck;
  if not Settings.NoWelcomeScreen then
    ShowWelcomeScreen(self);

  if Settings.VisualiserVisible then
    FuncVisualiser;
  if Settings.ToolboxVisible then
    FuncToolbox;
  DoNppnBufferChange;
  init := true;
end;

procedure TFHIRPlugin.DoNppnShutdown;
begin
  inherited;
  try
    Settings.ShuttingDown := true;
    errors.Free;
    matches.Free;
    errorSorter.Free;
    FClient.Free;
    FCapabilityStatement.Free;
    FreeAndNil(FetchResourceFrm);
    FreeAndNil(FHIRToolbox);
    FreeAndNil(FHIRVisualizer);
    FContext.Free;
    Settings.Free;
  except
    // just hide it
  end;
end;

procedure TFHIRPlugin.DoNppnBufferChange;
begin
  if not FFileInfo.TryGetValue(currentFileName, FCurrentFileInfo) then
    AnalyseFile;
  OpMessage(FCurrentFileInfo.summary, '');

  FuncValidateClear;
  FuncMatchesClear;
  DoNppnTextModified;
end;

procedure TFHIRPlugin.DoNppnDwellEnd;
begin
  if tipShowing then
    mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_CALLTIPCANCEL, 0, 0));
  tipText := '';
end;

procedure TFHIRPlugin.DoNppnDwellStart(offset: integer);
var
  msg : TStringBuilder;
  annot : TFHIRAnnotation;
  first : boolean;
begin
  CheckUpgrade;
  first := true;
  msg := TStringBuilder.Create;
  try
    for annot in errors do
    begin
      if (annot.start <= offset) and (annot.stop >= offset) then
      begin
        if first then
          first := false
        else
          msg.AppendLine;
        msg.Append(annot.message);
      end;
      if annot.start > offset then
        break;
    end;
    for annot in matches do
    begin
      if (annot.start <= offset) and (annot.stop >= offset) then
      begin
        if first then
          first := false
        else
          msg.AppendLine;
        msg.Append(annot.message);
      end;
      if annot.start > offset then
        break;
    end;
    if not first then
    begin
      tipText := msg.ToString;
      mcheck(SendMessage(NppData.ScintillaMainHandle, SCI_CALLTIPSHOW, offset, LPARAM(PAnsiChar(tipText))));
    end;
  finally
    msg.Free;
  end;
end;

procedure TFHIRPlugin.DoNppnFileClosed;
begin
end;

procedure TFHIRPlugin.DoNppnFileOpened;
begin
end;

procedure TFHIRPlugin.evaluatePath(r : TFHIRResource; out items : TFHIRSelectionList; out expr : TFHIRPathExpressionNodeV; out types : TFHIRTypeDetailsV);
var
  engine : TFHIRPathEngineV;
begin
  if not waitForValidator(FCurrentFileInfo.Version, true) then
    exit;
  engine := FContext.Version[FCurrentFileInfo.Version].makePathEngine;
  try
    expr := engine.parseV(FHIRToolbox.mPath.Text);
    try
      types := engine.check(nil, CODES_TFHIRResourceType[r.ResourceType], CODES_TFHIRResourceType[r.ResourceType], FHIRToolbox.mPath.Text, expr, false);
      try
        items := engine.evaluate(nil, r, expr);
        types.Link;
      finally
        types.Free;
      end;
      expr.Link;
    finally
      expr.Free;
    end;
  finally
    engine.Free;
  end;
end;

function prepNarrative(s : String): String; overload;
begin
  result := '<html><body>'+s+'</body></html>';
end;

function prepNarrative(r : TFHIRResource): String; overload;
var
  dr : TFHIRDomainResource;
begin
  if (r = nil) or not (r is TFhirDomainResource) then
    result := prepNarrative('')
  else
  begin
    dr := r as TFhirDomainResource;
    if (dr.text = nil) or (dr.text.div_ = nil) then
      result := prepNarrative('')
    else
      result := prepNarrative(TFHIRXhtmlParser.compose(dr.text.div_));
  end;
end;


procedure TFHIRPlugin.DoNppnTextModified;
var
  src, path, fn : String;
  fmt : TFHIRFormat;
  s : TStringStream;
  res : TFHIRResource;
  items : TFHIRSelectionList;
  expr : TFHIRPathExpressionNodeV;
  types : TFHIRTypeDetailsV;
  item : TFHIRSelection;
  focus : TArray<TFHIRObject>;
  sp, ep : integer;
  annot : TFHIRAnnotation;
  i : integer;
begin
  CheckUpgrade;
  if not init then
    exit;

  if FCurrentFileInfo.Format = ffUnspecified then
    exit;

  if not waitForValidator(FCurrentFileInfo.Version, false) then
    exit;

  src := CurrentText;
  if src = FLastSrc then
    exit;
  FLastSrc := src;
  FLastRes.free;
  FLastRes := nil;
//    // we need to parse if:
//    //  - we are doing background validation
//    //  - there's a path defined
//    //  - we're viewing narrative
//  else if (Settings.BackgroundValidation or
//          (assigned(FHIRToolbox) and (FHIRToolbox.hasValidPath)) or
//          (VisualiserMode in [vmNarrative, vmFocus])) then
  try
    if not (parse(500, fmt, res)) then
    begin
      if (FHIRVisualizer <> nil) then
        case VisualiserMode of
          vmNarrative: FHIRVisualizer.setNarrative(prepNarrative(''));
          vmPath: FHIRVisualizer.setPathOutcomes(nil, nil);
          vmFocus: FHIRVisualizer.setFocusInfo('', []);
        end;
      FCurrentFileInfo.Format := ffUnspecified;
    end
    else
    try
      FLastRes := res.Link;
      if res = nil then
        case VisualiserMode of
          vmNarrative: FHIRVisualizer.setNarrative(prepNarrative(''));
          vmPath: FHIRVisualizer.setPathOutcomes(nil, nil);
          vmFocus: FHIRVisualizer.setFocusInfo('', []);
        end
      else
      begin
        if (Settings.BackgroundValidation) then
          validate(res);
        if (FHIRVisualizer <> nil) and (VisualiserMode = vmNarrative) then
          FHIRVisualizer.setNarrative(prepNarrative(res));
        if (FHIRVisualizer <> nil) and (VisualiserMode = vmFocus) then
        begin
          if locate(res, path, focus) then
            FHIRVisualizer.setFocusInfo(path, focus)
          else
            FHIRVisualizer.setFocusInfo('', []);
        end;
        if (VisualiserMode = vmPath) then
        begin
          if assigned(FHIRToolbox) and (FHIRToolbox.hasValidPath) and (VisualiserMode = vmPath) then
          begin
            evaluatePath(res, items, expr, types);
            try
              for item in items do
              begin
                sp := SendMessage(NppData.ScintillaMainHandle, SCI_FINDCOLUMN, item.value.LocationStart.line - 1, item.value.LocationStart.col-1);
                ep := SendMessage(NppData.ScintillaMainHandle, SCI_FINDCOLUMN, item.value.LocationEnd.line - 1, item.value.LocationEnd.col-1);
                if (ep = sp) then
                  ep := sp + 1;
                matches.Add(TFHIRAnnotation.create(alMatch, item.value.LocationStart.line - 1, sp, ep, 'This element is a match to path "'+FHIRToolbox.mPath.Text+'"', item.value.describe));
              end;
              if VisualiserMode = vmPath then
                FHIRVisualizer.setPathOutcomes(matches, expr);
              setUpSquiggles;
              for annot in matches do
                squiggle(LEVEL_INDICATORS[annot.level], annot.line, annot.start, annot.stop - annot.start, annot.message);
            finally
              items.Free;
              expr.Free;
              types.Free;
            end;
          end
          else
            FHIRVisualizer.setPathOutcomes(nil, nil);
        end;
      end;
    finally
      res.Free;
    end;
  except
//      on e: exception do
//        showmessage(e.message);
  end;
end;



function TFHIRPlugin.DoSmartOnFHIR(server : TRegisteredFHIRServer) : boolean;
var
  mr : integer;
begin
  result := false;
  SmartOnFhirLoginForm := TSmartOnFhirLoginForm.Create(self);
  try
    SmartOnFhirLoginForm.logoPath := IncludeTrailingBackslash(ExtractFilePath(GetModuleName(HInstance)))+'npp.png';
    SmartOnFhirLoginForm.Server := server.Link;
    SmartOnFhirLoginForm.scopes := 'openid profile user/*.*';
    SmartOnFhirLoginForm.handleError := true;
    mr := SmartOnFhirLoginForm.ShowModal;
    if mr = mrOK then
    begin
      FClient.SmartToken := SmartOnFhirLoginForm.Token.Link;
      result := true;
    end
    else if (mr = mrAbort) and (SmartOnFhirLoginForm.ErrorMessage <> '') then
      MessageDlg(SmartOnFhirLoginForm.ErrorMessage, mtError, [mbok], 0);
  finally
    SmartOnFhirLoginForm.Free;
  end;
end;

procedure TFHIRPlugin.DoStateChanged;
var
  src, path : String;
  focus : TArray<TFHIRObject>;
begin
  src := CurrentText;
  if src <> FLastSrc then
    DoNppnTextModified;
  // k. all up to date with FLastRes
  if (VisualiserMode  = vmFocus) and (FLastRes <> nil) then
  begin
    if locate(FLastRes, path, focus) then
      FHIRVisualizer.setFocusInfo(path, focus)
    else
      FHIRVisualizer.setFocusInfo('', []);
  end;
end;

{ TUpgradeCheckThread }

constructor TUpgradeCheckThread.Create(plugin: TFHIRPlugin);
begin
  Fplugin := plugin;
  inherited create(false);
end;

function TUpgradeCheckThread.loadXml(b : TFslBuffer): IXMLDOMDocument2;
var
  v, vAdapter : Variant;
  s : TBytesStream;
begin
  v := LoadMsXMLDom;
  Result := IUnknown(TVarData(v).VDispatch) as IXMLDomDocument2;
  result.validateOnParse := False;
  result.preserveWhiteSpace := True;
  result.resolveExternals := False;
  result.setProperty('NewParser', True);
  s := TBytesStream.Create(b.AsBytes);
  try
    vAdapter := TStreamAdapter.Create(s) As IStream;
    result.load(vAdapter);
  finally
    s.Free;
  end;
end;

function TUpgradeCheckThread.getServerLink(doc : IXMLDOMDocument2) : string;
var
  e1, e2, e3 : IXMLDOMElement;
begin
  e1 := TMsXmlParser.FirstChild(doc.documentElement);
  e2 := TMsXmlParser.FirstChild(e1);
  while (e2.nodeName <> 'item') do
    e2 := TMsXmlParser.NextSibling(e2);
  e3 := TMsXmlParser.FirstChild(e2);
  while (e3 <> nil) and (e3.nodeName <> 'link') do
    e3 := TMsXmlParser.NextSibling(e3);
  if (e3 = nil) then
    result := ''
  else
    result := e3.text;
end;

function TUpgradeCheckThread.getUpgradeNotes(doc : IXMLDOMDocument2; current : String) : string;
var
  e1, e2, e3 : IXMLDOMElement;
begin
  e1 := TMsXmlParser.FirstChild(doc.documentElement);
  e2 := TMsXmlParser.FirstChild(e1);
  while (e2.nodeName <> 'item') do
    e2 := TMsXmlParser.NextSibling(e2);
  result := '';
  while (e2 <> nil) and (e2.nodeName = 'item') do
  begin
    e3 := TMsXmlParser.FirstChild(e2);
    while (e3.nodeName <> 'link') do
      e3 := TMsXmlParser.NextSibling(e3);
    if e3.text = current then
      exit;
    e3 := TMsXmlParser.FirstChild(e2);
    while (e3.nodeName <> 'description') do
      e3 := TMsXmlParser.NextSibling(e3);
    result := result + e3.text + #13#10;
    e2 := TMsXmlParser.NextSibling(e2);
  end;
  result := e3.text;
end;

procedure TUpgradeCheckThread.Execute;
var
  web : TFslWinInetClient;
  doc : IXMLDOMDocument2;
  bc : string;
begin
  try
    web := TFslWinInetClient.Create;
    try
      web.UseWindowsProxySettings := true;
      web.Server := 'www.healthintersections.com.au';
      web.Resource := 'FhirServer/fhirnpp.rss';
      web.Response := TFslBuffer.Create;
      web.Execute;
      doc := loadXml(web.Response);
      bc := getServerLink(doc);
      if (bc > 'http://www.healthintersections.com.au/FhirServer/npp-install-1.0.'+inttostr(BuildCount)+'.exe') and (bc <> Settings.BuildPrompt) then
      begin
        FPlugin.FUpgradeNotes  := getUpgradeNotes(doc, 'http://www.healthintersections.com.au/FhirServer/npp-install-1.0.'+inttostr(BuildCount)+'.exe');
        FPlugin.FUpgradeReference := bc;
      end;
    finally
      web.free;
    end;
  except
    // never complain
  end;
end;

{ TFHIRPluginFileInformation }

function TFHIRPluginFileInformation.link: TFHIRPluginFileInformation;
begin
  result := TFHIRPluginFileInformation(inherited link);
end;

function TFHIRPluginFileInformation.summary: String;
begin
  if Format = ffUnspecified then
    exit('Not a FHIR resource');

  result := CODES_TFHIRFormat[Format];
  case FVersionStatus of
    vsUnknown: result := result+ ', version unknown';
    vsGuessed: result := result+ ', version might be '+CODES_TFHIRVersion[Version];
    vsSpecified: result := result+ ', version = R'+CODES_TFHIRVersion[Version];
  end;
end;

{ TContextLoadingThread }

constructor TContextLoadingThread.Create(plugin : TFHIRPlugin; factory : TFHIRFactory);
begin
  FPlugin := plugin;
  FFactory := factory;
  FreeOnTerminate := true;
  inherited Create;
end;

destructor TContextLoadingThread.Destroy;
begin
  FFactory.free;
  inherited;
end;

procedure TContextLoadingThread.Execute;
var
  vf : TFHIRNppVersionFactory;
  ctxt : TFHIRPluginValidatorContext;
  rset : TFslStringSet;
begin
  vf := TFHIRNppVersionFactory.Create(FFactory.link);
  try
    try
      FPlugin.FContext.Version[COMPILED_FHIR_VERSION] := vf.Link;
      ctxt := TFHIRPluginValidatorContext.Create(FFactory.link, Settings.TerminologyServer);
      try
        // limit the amount of resource types loaded for convenience...
        rset := TFslStringSet.Create(['StructureDefinition', 'CodeSystem', 'ValueSet']);
        try
          FPlugin.FCache.loadPackage('hl7.fhir.core', FFactory.versionString, rset, ctxt.loadResourceJson);
        finally
          rset.Free;
        end;
        vf.Worker := ctxt.Link;
      finally
        ctxt.Free;
      end;
      FPlugin.FContext.VersionLoading[FFactory.version] := vlsLoaded;
    except
      on e : Exception do
      begin
        FPlugin.FContext.VersionLoading[FFactory.version] := vlsLoadingFailed;
        vf.error := e.Message;
      end;
    end;
  finally
    vf.Free;
  end;
end;

initialization
  FNpp := TFHIRPlugin.Create;
end.
