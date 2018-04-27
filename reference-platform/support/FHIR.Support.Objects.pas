Unit FHIR.Support.Objects;

{
Copyright (c) 2001-2013, Kestral Computing Pty Ltd (http://www.kestral.com.au)
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

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
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

Interface


Uses
  {$IFDEF MACOS} FHIR.Support.Osx, {$ELSE} Windows, {$ENDIF}    // Interlocked* API and HResult
  FHIR.Support.Exceptions;


Type
  TAdvObjectClass = Class Of TAdvObject;
  TAdvClass = TAdvObjectClass;

  TAdvReferenceCount = Integer;

  TAdvObject = Class(TObject)
    Private
      // Reference counted using Interlocked* Windows API functions.
      FAdvObjectReferenceCount : TAdvReferenceCount;

    Protected
      // Declared here for ease of implementing interfaces.
      Function _AddRef : Integer; Stdcall;
      Function _Release : Integer; Stdcall;
      Function QueryInterface(Const IID : TGUID; Out Obj): HResult; Virtual; Stdcall;

      Procedure FreezeChildren; Overload; Virtual;
      Procedure AllowDestructionChildren; Overload; Virtual;
      Procedure PreventDestructionChildren; Overload; Virtual;

      Procedure FreeReference; Overload; Virtual;

      // May be called from Nil or invalid references (so can't be virtual).
      Function Invariant(Const sMethod, sMessage : String) : Boolean; Overload;
      Function Invariants(Const sLocation : String; oObject : TObject; aClass : TClass; Const sObject : String) : Boolean; Overload;
      Function Invariants(Const sLocation : String; oObject : TAdvObject; aClass : TClass; Const sObject : String) : Boolean; Overload;
      Function Invariants(Const sLocation : String; aReference, aClass : TClass; Const sReference : String) : Boolean; Overload;

      Function CheckCondition(bCorrect : Boolean; aException : EAdvExceptionClass; Const sMethod, sMessage : String) : Boolean; Overload;
      Function CheckCondition(bCorrect : Boolean; Const sMethod, sMessage : String) : Boolean; Overload;

      // Override to introduce additional or alternate behaviour.
      Function Assignable(Const sLocation : String; oObject : TAdvObject; Const sObject : String) : Boolean; Overload; Virtual;
      Function Alterable(Const sMethod : String) : Boolean; Overload; Virtual;
      Procedure RaiseError(aException : EAdvExceptionClass; Const sMethod, sMessage : String); Overload; Virtual;
      Procedure RaiseError(Const sMethod, sMessage : String); Overload; Virtual;

      Class Procedure ClassError(Const sMethod, sMessage : String); Overload;

      Function ErrorClass : EAdvExceptionClass; Overload; Virtual;

    Public
      Constructor Create; Overload; Virtual;
      Destructor Destroy; Override;

      Procedure AfterConstruction; Override;
      Procedure BeforeDestruction; Override;

      // Cannot be virtual as they are allowed to be called from Nil or invalid objects (but will assert).
      Procedure Free; Overload;
      Function Link : TAdvObject; Overload;
      Function Unlink : TAdvObject; Overload;
      Function Clone : TAdvObject; Overload;
      Function ClassType : TAdvObjectClass; Overload;

      // Assignment.
      Function Assignable : Boolean; Overload; Virtual;
      Function Duplicate : TAdvObject; Overload; Virtual;
      Procedure Assign(oObject : TAdvObject); Overload; Virtual;

      // Determine if self is a valid reference of the specified class.
      Function Invariants(Const sLocation : String; aClass : TClass) : Boolean; Overload;

      Property AdvObjectReferenceCount : TAdvReferenceCount Read FAdvObjectReferenceCount;
  End;

  PAdvObject = ^TAdvObject;

  EAdvInvariant = Class(EAdvException)
    Public
      Constructor Create(Const sSender, sMethod, sReason : String); Overload; Override;
  End;

  EAdvExceptionClass = FHIR.Support.Exceptions.EAdvExceptionClass;
  EAdvException = FHIR.Support.Exceptions.EAdvException;


Implementation


Constructor TAdvObject.Create;
Begin 
  Inherited;
End;


Destructor TAdvObject.Destroy;
Begin
  Inherited;
End;  


Procedure TAdvObject.AfterConstruction;
Begin 
  Inherited;

End;  


Procedure TAdvObject.BeforeDestruction;
Begin 
  // TODO: really should always be -1, but SysUtils.FreeAndNil may bypass the correct Free method.
  Assert(CheckCondition(FAdvObjectReferenceCount <= 0, 'BeforeDestruction', 'Attempted to destroy object before all references are released (possibly freed while cast as a TObject).'));

  Inherited;
End;  


Procedure TAdvObject.AllowDestructionChildren;
Begin
End;


Procedure TAdvObject.PreventDestructionChildren;
Begin
End;


Procedure TAdvObject.FreezeChildren;
Begin
End;

Procedure TAdvObject.FreeReference;
Begin
  If (InterlockedDecrement(FAdvObjectReferenceCount) < 0) Then
    Destroy;
End;


Procedure TAdvObject.Free;
Begin
  If Assigned(Self) Then
  Begin
    Assert(Invariants('Free', TAdvObject));

    FreeReference;
  End;
End;  


Function TAdvObject.ClassType : TAdvObjectClass;
Begin 
  Result := TAdvObjectClass(Inherited ClassType);
End;  


Function TAdvObject.Unlink : TAdvObject;
Begin 
  Result := Self;

  If Assigned(Self) Then
  Begin 
    Assert(Invariants('Unlink', TAdvObject));

    If (InterlockedDecrement(FAdvObjectReferenceCount) < 0) Then
    Begin 
      Destroy;
      Result := Nil;
    End;  
  End;  
End;  


Function TAdvObject.Link : TAdvObject;
Begin 
  Result := Self;

  If Assigned(Self) Then
  Begin 
    Assert(Invariants('Link', TAdvObject));

    InterlockedIncrement(FAdvObjectReferenceCount);
  End;  
End;  


Function TAdvObject.Duplicate : TAdvObject;
Begin 
  Result := ClassType.Create;
End;  


Function TAdvObject.Clone : TAdvObject;
Begin 
  If Assigned(Self) Then
  Begin
    Assert(Invariants('Clone', TAdvObject));

    Result := Duplicate;
    Result.Assign(Self);

    Assert(Invariants('Clone', Result, ClassType, 'Result'));
  End
  Else
  Begin
    Result := Nil;
  End;
End;  


Function TAdvObject._AddRef : Integer;
Begin 
  If Assigned(Self) Then
  Begin 
    Assert(Invariants('_AddRef', TAdvObject));

    Result := InterlockedIncrement(FAdvObjectReferenceCount);
  End   
  Else
  Begin 
    Result := 0;
  End;
End;


Function TAdvObject._Release: Integer;
Begin
  If Assigned(Self) Then
  Begin
    Assert(Invariants('_Release', TAdvObject));

    Result := InterlockedDecrement(FAdvObjectReferenceCount);

    If Result < 0 Then
      Destroy;
  End
  Else
  Begin 
    Result := 0;
  End;  
End;  


Function TAdvObject.QueryInterface(Const IID: TGUID; Out Obj): HResult;
//Const
//  // Extra typecast to longint prevents a warning about subrange bounds
//  SUPPORT_INTERFACE : Array[Boolean] Of HResult = (Longint($80004002), 0);
Begin
//  Result := SUPPORT_INTERFACE[GetInterface(IID, Obj)];
  If GetInterface(IID, Obj) Then
    Result := S_OK
  Else
    Result := E_NOINTERFACE;
End;


Function TAdvObject.Assignable : Boolean;
Begin 
  Result := True;
End;  


Function TAdvObject.ErrorClass : EAdvExceptionClass;
Begin
  Result := EAdvException;
End;  


Procedure TAdvObject.RaiseError(aException : EAdvExceptionClass; Const sMethod, sMessage : String);
Begin
  Raise aException.Create(Self, sMethod, sMessage);
End;


Procedure TAdvObject.RaiseError(Const sMethod, sMessage : String);
Begin
  RaiseError(ErrorClass, sMethod, sMessage);
End;  


Function TAdvObject.Assignable(Const sLocation : String; oObject : TAdvObject; Const sObject : String) : Boolean;
Begin 
  Invariants(sLocation, oObject, ClassType, sObject);

  If (Self = oObject) Then
    Invariant(sLocation, 'Cannot assign an object to itself.');

  Result := Alterable(sLocation);
End;


Procedure TAdvObject.Assign(oObject : TAdvObject);
Begin 
  Assert(CheckCondition(Assignable, 'Assign', 'Object is not marked as assignable.'));
  Assert(Assignable('Assign', oObject, 'oObject'));

  // Override and inherit to assign the properties of your class.
End;  


Function TAdvObject.Invariants(Const sLocation: String; aReference, aClass: TClass; Const sReference : String): Boolean;
Begin 
  // Ensure class is assigned.
  If Not Assigned(aReference) Then
    Invariant(sLocation, sReference + ' was not assigned and was expected to have been of class type ' + aClass.ClassName);

  // Ensure class is of the expected class.
  If Not aReference.InheritsFrom(aClass) Then
    Invariant(sLocation, sReference + ' was of class type ' + aReference.ClassName + ' and should have been of class type ' + aClass.ClassName);

  Result := True;
End;  


Function TAdvObject.Invariants(Const sLocation : String; oObject : TObject; aClass: TClass; Const sObject : String) : Boolean;
Begin 
  If Not Assigned(aClass) Then
    Invariant('Invariants', 'aClass was not assigned.');

  // Ensure object is assigned.
  If Not Assigned(oObject) Then
    Invariant(sLocation, sObject + ' was not assigned and was expected to have been of class ' + aClass.ClassName);

  Result := True;
End;


Function TAdvObject.Invariants(Const sLocation : String; oObject: TAdvObject; aClass: TClass; Const sObject : String) : Boolean;
Begin
  Invariants(sLocation, TObject(oObject), aClass, sObject);

  Result := True;
End;


Function TAdvObject.Invariants(Const sLocation: String; aClass: TClass) : Boolean;
Begin
  Invariants(sLocation, TObject(Self), aClass, 'Self');

  Result := True;
End;


Function TAdvObject.CheckCondition(bCorrect: Boolean; Const sMethod, sMessage: String): Boolean;
Begin
  // Call this method as you would the Assert procedure to raise an exception if bCorrect is False.

  If Not bCorrect Then
    Invariant(sMethod, sMessage);

  Result := True;
End;


Function TAdvObject.CheckCondition(bCorrect : Boolean; aException : EAdvExceptionClass; Const sMethod, sMessage : String) : Boolean;
Begin 
  // Call this method as you would the Assert procedure to raise an exception if bCorrect is False.

  If Not bCorrect Then
    RaiseError(aException, sMethod, sMessage);

  Result := True;
End;  


Function TAdvObject.Invariant(Const sMethod, sMessage: String): Boolean;
Begin 
  // Call this method as you would the Error method to raise an exception.
  // Use this when you are not sure if self is valid as it is a non-virtual method.

  Raise EAdvInvariant.Create(Self, sMethod, sMessage); // Can't use Error method here as it is virtual.

  Result := True;
End;  


Function TAdvObject.Alterable(Const sMethod: String): Boolean;
Begin
  Result := True;
End;  

Class Procedure TAdvObject.ClassError(Const sMethod, sMessage: String);
Begin
  Raise EAdvException.Create(Nil, sMethod, sMessage);
End;


Constructor EAdvInvariant.Create(Const sSender, sMethod, sReason : String);
Begin
  Inherited;

  Message := Description;
End;  


End. // FHIR.Support.Objects //