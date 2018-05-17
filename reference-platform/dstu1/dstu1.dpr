{
Copyright (c) 2017+, Health Intersections Pty Ltd (http://www.healthintersections.com.au)
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
program dstu1;

{$APPTYPE CONSOLE}

uses
  FHIR.Tools.Constants,
  FHIR.Tools.Parser,
  SysUtils,
  Classes,
  ActiveX,
  FHIR.Support.Strings in '..\support\FHIR.Support.Strings.pas',
  FHIR.Support.Math in '..\support\FHIR.Support.Math.pas',
  FHIR.Support.Decimal in '..\support\FHIR.Support.Decimal.pas',
  GUIDSupport in '..\support\GUIDSupport.pas',
  FHIR.Support.Factory in '..\support\FHIR.Support.Factory.pas',
  FHIR.Support.System in '..\support\FHIR.Support.System.pas',
  MemorySupport in '..\support\MemorySupport.pas',
  FHIR.Support.DateTime in '..\support\FHIR.Support.DateTime.pas',
  ErrorSupport in '..\support\ErrorSupport.pas',
  SystemSupport in '..\support\SystemSupport.pas',
  ThreadSupport in '..\support\ThreadSupport.pas',
  EncodeSupport in '..\support\EncodeSupport.pas',
  AdvControllers in '..\support\AdvControllers.pas',
  AdvPersistents in '..\support\AdvPersistents.pas',
  FHIR.Support.Objects in '..\support\FHIR.Support.Objects.pas',
  FHIR.Support.Exceptions in '..\support\FHIR.Support.Exceptions.pas',
  FHIR.Support.Filers in '..\support\FHIR.Support.Filers.pas',
  ColourSupport in '..\support\ColourSupport.pas',
  CurrencySupport in '..\support\CurrencySupport.pas',
  AdvPersistentLists in '..\support\AdvPersistentLists.pas',
  AdvObjectLists in '..\support\AdvObjectLists.pas',
  AdvItems in '..\support\AdvItems.pas',
  FHIR.Support.Collections in '..\support\FHIR.Support.Collections.pas',
  AdvIterators in '..\support\AdvIterators.pas',
  AdvClassHashes in '..\support\AdvClassHashes.pas',
  AdvHashes in '..\support\AdvHashes.pas',
  HashSupport in '..\support\HashSupport.pas',
  AdvStringHashes in '..\support\AdvStringHashes.pas',
  AdvProfilers in '..\support\AdvProfilers.pas',
  AdvStringIntegerMatches in '..\support\AdvStringIntegerMatches.pas',
  FHIR.Support.Stream in '..\support\FHIR.Support.Stream.pas',
  AdvParameters in '..\support\AdvParameters.pas',
  AdvExclusiveCriticalSections in '..\support\AdvExclusiveCriticalSections.pas',
  AdvThreads in '..\support\AdvThreads.pas',
  AdvSignals in '..\support\AdvSignals.pas',
  AdvSynchronizationRegistries in '..\support\AdvSynchronizationRegistries.pas',
  AdvTimeControllers in '..\support\AdvTimeControllers.pas',
  AdvIntegerMatches in '..\support\AdvIntegerMatches.pas',
  AdvBuffers in '..\support\AdvBuffers.pas',
  FHIR.Support.Binary in '..\support\FHIR.Support.Binary.pas',
  AdvStringBuilders in '..\support\AdvStringBuilders.pas',
  AdvFiles in '..\support\AdvFiles.pas',
  AdvLargeIntegerMatches in '..\support\AdvLargeIntegerMatches.pas',
  AdvStringLargeIntegerMatches in '..\support\AdvStringLargeIntegerMatches.pas',
  AdvStringLists in '..\support\AdvStringLists.pas',
  AdvCSVFormatters in '..\support\AdvCSVFormatters.pas',
  AdvTextFormatters in '..\support\AdvTextFormatters.pas',
  AdvFormatters in '..\support\AdvFormatters.pas',
  AdvCSVExtractors in '..\support\AdvCSVExtractors.pas',
  AdvTextExtractors in '..\support\AdvTextExtractors.pas',
  AdvExtractors in '..\support\AdvExtractors.pas',
  AdvCharacterSets in '..\support\AdvCharacterSets.pas',
  AdvOrdinalSets in '..\support\AdvOrdinalSets.pas',
  AdvStreamReaders in '..\support\AdvStreamReaders.pas',
  AdvStringStreams in '..\support\AdvStringStreams.pas',
  DateAndTime in '..\support\DateAndTime.pas',
  KDate in '..\support\KDate.pas',
  HL7V2DateSupport in '..\support\HL7V2DateSupport.pas',
  FHIR.Base.Objects in 'FHIR.Base.Objects.pas',
  AdvStringMatches in '..\support\AdvStringMatches.pas',
  FHIR.Tools.Resources in 'FHIR.Tools.Resources.pas',
  FHIR.Base.Parser in 'FHIR.Base.Parser.pas',
  FHIR.Tools.Session in 'FHIR.Tools.Session.pas',
  FHIR.Web.Parsers in '..\support\FHIR.Web.Parsers.pas',
  FHIRAtomFeed in 'FHIRAtomFeed.pas',
  MsXmlParser in '..\support\MsXmlParser.pas',
  AdvMemories in '..\support\AdvMemories.pas',
  FHIR.Xml.Builder in '..\support\FHIR.Xml.Builder.pas',
  FHIR.Support.WInInet in '..\support\FHIR.Support.WInInet.pas',
  MXmlBuilder in '..\support\MXmlBuilder.pas',
  TextUtilities in '..\support\TextUtilities.pas',
  AdvVCLStreams in '..\support\AdvVCLStreams.pas',
  AdvXmlBuilders in '..\support\AdvXmlBuilders.pas',
  AdvXMLFormatters in '..\support\AdvXMLFormatters.pas',
  AdvXMLEntities in '..\support\AdvXMLEntities.pas',
  FHIR.Support.Json in '..\support\FHIR.Support.Json.pas',
  FHIR.Support.Generics in '..\support\FHIR.Support.Generics.pas',
  FHIR.Base.Lang in 'FHIR.Base.Lang.pas',
  AfsResourceVolumes in '..\support\AfsResourceVolumes.pas',
  AfsVolumes in '..\support\AfsVolumes.pas',
  AfsStreamManagers in '..\support\AfsStreamManagers.pas',
  AdvObjectMatches in '..\support\AdvObjectMatches.pas',
  FHIR.Tools.Utilities in 'FHIR.Tools.Utilities.pas',
  AdvStringObjectMatches in '..\support\AdvStringObjectMatches.pas',
  JWT in '..\support\JWT.pas',
  HMAC in '..\support\HMAC.pas',
  libeay32 in '..\support\libeay32.pas',
  ParserSupport in '..\support\ParserSupport.pas',
  FHIR.Support.MXml in '..\support\FHIR.Support.MXml.pas';

procedure SaveStringToFile(s : AnsiString; fn : String);
var
  f : TFileStream;
begin  
  f := TFileStream.Create(fn, fmCreate);
  try
    f.Write(s[1], length(s));
  finally
    f.free;
  end;
end;

var
  f : TFileStream;
  m : TMemoryStream;
  p : TFHIRParser;
  c : TFHIRComposer;
  r : TFhirResource;
  a : TFHIRAtomFeed;
procedure Roundtrip(Source, Dest : String);
begin
  try
    p := TFHIRXmlParser.Create('en');
    try
      f := TFileStream.Create(source, fmopenRead,+ fmShareDenyWrite);
      try
        p.source := f;
        p.Parse;
        r := p.resource.Link;
        a := p.feed.Link;
      finally
        f.Free;
      end;
    finally
      p.free;
    end;
    m := TMemoryStream.Create;
    try
      c := TFHIRJsonComposer.Create('en');
      try
        TFHIRJsonComposer(c).Comments := true;
        if r <> nil then
          c.Compose(m, '', '', '', r, true, nil)
        else
          c.Compose(m, a, true);
      finally
        c.free;
      end;
      m.Position := 0;
      m.SaveToFile(ChangeFileExt(dest, '.json'));
      m.Position := 0;
      r.Free;
      a.Free;
      r := nil;
      a := nil;
      p := TFHIRJsonParser.Create('en');
      try
        p.source := m;
        p.Parse;
        r := p.resource.Link;
        a := p.feed.Link;
      finally
        p.Free;
      end;
    finally
      m.Free;
    end;
    f := TFileStream.Create(dest, fmCreate);
    try
      c := TFHIRXMLComposer.Create('en');
      try
        if r <> nil then
          c.Compose(f, '', '', '', r, true, nil)
        else
          c.Compose(f, a, true);
      finally
        c.free;
      end;
    finally
      f.free;
    end;
  finally
    r.Free;
    a.Free;
  end;

//  IdSoapXmlCheckDifferent(source, dest);
end;

procedure roundTripDirectory(pathSource, pathDest : String);
var
  SR: TSearchRec;
  s : String;
begin
  if FindFirst(IncludeTrailingPathDelimiter(PathSource) + '*.xml', faAnyFile, SR) = 0 then
  begin
    repeat
      s := copy(SR.Name, 1, pos('.', SR.Name)-1);
      if (SR.Attr <> faDirectory) and (copy(s, length(s)-1, 2) <> '-d') then
      begin
        Writeln(SR.name);
        Roundtrip(IncludeTrailingPathDelimiter(pathSource)+SR.Name, IncludeTrailingPathDelimiter(pathDest)+s+'-d'+ExtractFileExt((SR.Name)));
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

begin
  try
    CoInitialize(nil);
    if DirectoryExists(ParamStr(2)) and DirectoryExists(Paramstr(1)) then
      roundTripDirectory(Paramstr(1), ParamStr(2))
    else
    begin
      if (ParamStr(1) = '') or (ParamStr(2) = '') or not FileExists(paramstr(1)) then
        raise Exception.Create('Provide input and output file names');
      roundTrip(paramStr(1), paramStr(2));
    end;
  except
    on e:exception do
      SaveStringToFile(AnsiString(e.Message), ParamStr(2)+'.err');
  end;
end.
