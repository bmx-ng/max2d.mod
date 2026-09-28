SuperStrict
Framework Max2D.D3D7Max2D
Import BRL.StandardIO

' Call the driver directly: BRL.Graphics catches creation errors in release builds.
Try
 Local context:TMax2DContext=D3D7Max2DDriver().CreateContext(128,96,0,0,0,-1,-1)
 If Not context Then Throw "No context returned"
 For Local blend:Int=MASKBLEND To SHADEBLEND
  Print "Blend "+blend+": "+context.SupportsBlend(blend)
 Next
 Print "Linear filtering: "+context.SupportsImageFlags(FILTEREDIMAGE)
 context.Close()
 Print "D3D7 context probe passed"
Catch error:Object
 Print "D3D7 unavailable: "+error.ToString()
 EndWithCode(1)
End Try
