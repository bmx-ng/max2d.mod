SuperStrict
Framework Max2D.Core
Import BRL.StandardIO
Import "dds_fixture.bmx"
Try
	If HasTextureDataLoaders() Then Throw "DDS must remain optional"
	If LoadImage(DDSTestStream(DDSTestBytes()),0) Then Throw "DDS unexpectedly loaded without provider"
	Print "Optional DDS loader tests passed"
Catch error:Object
	Print "FAILED: "+error.ToString()
	EndWithCode(1)
End Try
