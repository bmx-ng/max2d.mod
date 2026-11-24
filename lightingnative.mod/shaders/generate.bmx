SuperStrict
Framework BRL.StandardIO
Import BRL.FileSystem
Import BRL.BankStream

Include "tool_common.bmx"

Try
 ChangeDir(LaunchDir)
 If AppArgs.Length=4 And AppArgs[1]="generate" Then
  Generate(AppArgs[2],AppArgs[3])
 Else If AppArgs.Length=3 And AppArgs[1]="embed" Then
  Embed(AppArgs[2])
 Else
  Throw "Usage: generate generate max2d-module-directory output-directory | generate embed output-directory"
 End If
Catch error:Object
 Print error.ToString()
 EndWithCode(1)
End Try
