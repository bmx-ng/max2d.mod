SuperStrict
Framework BRL.StandardIO
Import BRL.BankStream
Import BRL.FileSystem
?win32
Import Pub.Win32

Extern "win32"
Function FreeLibrary:Int(library:Byte Ptr) = "WINBOOL __stdcall FreeLibrary(HMODULE)!"
Interface ID3DCompilerBlob Extends IUnknown_
	Method GetBufferPointer:Byte Ptr()
	Method GetBufferSize:Size_T()
End Interface
End Extern

Function CompileDXBC(sourcePath:String, outputPath:String)
	Local library:Byte Ptr=LoadLibraryA("d3dcompiler_47.dll")
	If Not library Then Throw "Cannot load d3dcompiler_47.dll"
	Local code:ID3DCompilerBlob, errors:ID3DCompilerBlob
	Local output:TStream
	Try
		Local compile:Int(source:Byte Ptr, size:Size_T, name:Byte Ptr, defines:Byte Ptr, includes:Byte Ptr, entry:Byte Ptr, target:Byte Ptr, flags:UInt, flags2:UInt, code:ID3DCompilerBlob Var, errors:ID3DCompilerBlob Var) "win32" = GetProcAddress(library,"D3DCompile")
		If Not compile Then Throw "D3DCompile is unavailable"
		Local source:TBank=LoadBank(sourcePath)
		If Not source Then Throw "Cannot read: "+sourcePath
		Local name:Byte Ptr=sourcePath.ToUTF8String(), entry:Byte Ptr="m2dEffectMain".ToCString(), target:Byte Ptr="ps_5_1".ToCString()
		Local result:Int
		Try
			result=compile(source.Buf(),Size_T(source.Size()),name,Null,Null,entry,target,$8000,0,code,errors)
		Finally
			MemFree(name); MemFree(entry); MemFree(target)
		End Try
		If errors Then Print String.FromUTF8String(errors.GetBufferPointer())
		If result<0 Or Not code Then Throw "D3DCompile failed: "+result
		output=WriteFile(outputPath)
		If Not output Then Throw "Cannot write: "+outputPath
		Local size:Size_T=code.GetBufferSize()
		If output.Write(code.GetBufferPointer(),size)<>size Then Throw "Incomplete shader output"
	Finally
		If output Then output.Close()
		If errors Then errors.Release_()
		If code Then code.Release_()
		FreeLibrary(library)
	End Try
End Function
?

ChangeDir(LaunchDir)

Try
	If AppArgs.Length<>3 Then Throw "Usage: compile_dxbc input.hlsl output.dxbc"
?win32
	CompileDXBC(AppArgs[1],AppArgs[2])
?Not win32
	Throw "DXBC compilation requires Windows and d3dcompiler_47.dll"
?
Catch error:Object
	Print "compile_dxbc: "+error.ToString()
	EndWithCode(1)
End Try
