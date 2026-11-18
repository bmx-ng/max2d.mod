SuperStrict
Framework BRL.StandardIO
Import Text.JSON
Import BRL.FileSystem
Import BRL.BankStream
Include "tool_common.bmx"

ChangeDir(LaunchDir)

Try
	If AppArgs.Length<>3 And AppArgs.Length<>5 Then Throw "Usage: generate manifest.json output-directory [--prefix asset-prefix]"
	Local prefix:String
	If AppArgs.Length=5 Then
		If AppArgs[3]<>"--prefix" Then Throw "Expected --prefix"
		prefix=AppArgs[4]
	End If
	GeneratePackage(AppArgs[1],AppArgs[2],prefix)
Catch error:Object
	Print "generate: "+error.ToString()
	EndWithCode(1)
End Try
