SuperStrict
Framework BRL.StandardIO
Import Text.JSON
Import BRL.FileSystem
Import BRL.BankStream
Include "tool_common.bmx"

ChangeDir(LaunchDir)

Try
	If AppArgs.Length<>3 Then Throw "Usage: embed manifest.json asset-directory"
	EmbedPackage(AppArgs[1],AppArgs[2])
Catch error:Object
	Print "embed: "+error.ToString()
	EndWithCode(1)
End Try
