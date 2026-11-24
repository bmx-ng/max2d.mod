SuperStrict
Framework BRL.StandardIO
Import Max2D.Core
Include "../lighting.mod/meshcache.bmx"

Global checks:Int
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
 checks:+1
End Function
Try
 Local mesh:TMesh2D=TMesh2D.Create([0.0,0.0,12.0,0.0,24.0,0.0,0.0,24.0,12.0,24.0,24.0,24.0],[0,1,4,0,4,3,1,2,5,1,5,4],[0.0,0.0,0.5,0.0,1.0,0.0,0.0,1.0,0.5,1.0,1.0,1.0])
 Local retained:TMax2DLightingMeshCache=New TMax2DLightingMeshCache
 For Local iteration:Int=0 Until 400
  ' Split, merge and overlap sections while preserving the UV/index topology.
  Local bend:Int=(iteration Mod 5)-2
  mesh.xy[5]=bend;mesh.xy[11]=24+bend
  mesh.xy[4]=24;mesh.xy[10]=24
  If iteration Mod 7=0 Then mesh.xy[4]=0;mesh.xy[10]=0
  If iteration Mod 11=0 Then mesh.xy[2]=13 Else mesh.xy[2]=12
  ' Change UV values and triangle order separately from the geometry edits.
  If iteration Mod 13=0 Then mesh.uv[2]=0.25;mesh.uv[8]=0.25
  If iteration Mod 13=1 Then mesh.uv[2]=0.5;mesh.uv[8]=0.5
  If iteration Mod 17=0 Then mesh.indices=[0,1,4,1,2,5,0,4,3,1,5,4]
  If iteration Mod 17=1 Then mesh.indices=[0,1,4,0,4,3,1,2,5,1,5,4]
  If iteration Mod 19=0 Then mesh.indices=[0,1,4,0,1,4,1,2,5,1,5,4]
  Local fresh:TMax2DLightingMeshCache=New TMax2DLightingMeshCache
  Local eligible:Int=retained.Accepts(mesh)
  Check(eligible=fresh.Accepts(mesh),"warm/cold eligibility "+iteration)
  Check(retained.DisjointGeometry()=fresh.DisjointGeometry(),"warm/cold geometry overlap "+iteration)
  Check(retained.runCount=fresh.runCount,"warm/cold section count "+iteration)
  For Local i:Int=0 To fresh.runCount
   Check(retained.starts[i]=fresh.starts[i],"warm/cold boundaries "+iteration)
  Next
  For Local i:Int=0 Until mesh.indices.Length*2
   Check(retained.mappings[i]=fresh.mappings[i],"warm/cold mapping "+iteration)
  Next
  Check(retained.Accepts(mesh)=eligible,"unchanged repeat "+iteration)
 Next
 ' Repeated failures must never turn a partial analysis into a cache hit.
 mesh.uv[10]=mesh.uv[4];mesh.uv[11]=mesh.uv[5]
 For Local attempt:Int=0 To 1
  Local rejected:Int
  Try
   retained.Accepts(mesh)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And Not retained.valid,"failed analysis invalidates snapshot")
 Next
 mesh.uv[11]=1
 retained.Accepts(mesh)
 Check(retained.valid,"repaired snapshot is valid")
 Print "PASS: "+checks+" mesh preparation checks"
Catch error:Object
 Print "FAIL: "+error.ToString();EndWithCode(1)
End Try
