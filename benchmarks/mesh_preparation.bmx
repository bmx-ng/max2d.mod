SuperStrict
Framework BRL.StandardIO
Import Max2D.Core
Import SDL3.SDL3
Include "../lighting.mod/meshcache.bmx"
Extern "C"
 Function SDL_GetTicksNS:ULong()
End Extern

' Isolates retained geometry analysis, without graphics or GPU work.
Function Grid:TMesh2D(cells:Int)
 Local xy:Float[(cells+1)*(cells+1)*2],uv:Float[xy.Length],indices:Int[cells*cells*6]
 For Local col:Int=0 To cells
  For Local row:Int=0 To cells
   Local p:Int=(col*(cells+1)+row)*2
   xy[p]=col*16;xy[p+1]=row*16
   uv[p]=Float(col)/cells;uv[p+1]=Float(row)/cells
  Next
 Next
 For Local col:Int=0 Until cells
  For Local row:Int=0 Until cells
   Local a:Int=col*(cells+1)+row,b:Int=a+cells+1,k:Int=(col*cells+row)*6
   indices[k]=a;indices[k+1]=b;indices[k+2]=b+1
   indices[k+3]=a;indices[k+4]=b+1;indices[k+5]=a+1
  Next
 Next
 Return TMesh2D.Create(xy,indices,uv)
End Function
Function Edit(mesh:TMesh2D,cells:Int,kind:Int,tick:Int)
 If kind=0 Then Return
 For Local col:Int=0 To cells
  For Local row:Int=0 To cells
   Local p:Int=(col*(cells+1)+row)*2
   If kind=1 Then
    mesh.xy[p+1]=row*16+(tick Mod 2)
   Else
    mesh.xy[p+1]=row*16+(col Mod 2)*(2+(tick Mod 2))
   End If
  Next
 Next
End Function
Try
 Print "triangles,case,trial,iterations,analysis_us,managed_bytes_per_iteration,sections"
 Local names:String[]=["warm","translation","bend"]
 For Local cells:Int=EachIn [8,16]
  For Local kind:Int=0 Until 3
   For Local trial:Int=1 To 3
    Local mesh:TMesh2D=Grid(cells),cache:TMax2DLightingMeshCache=New TMax2DLightingMeshCache
    For Local tick:Int=0 Until 20
     Edit(mesh,cells,kind,tick);cache.Accepts(mesh)
    Next
    GCCollect()
    Local before:SGCStats,after:SGCStats
    GCGetStats(before)
    Local start:ULong=SDL_GetTicksNS(),iterations:Int=1000
    For Local tick:Int=0 Until iterations
     Edit(mesh,cells,kind,tick)
     If Not cache.Accepts(mesh) Then Throw "expected affine sections"
    Next
    Local elapsed:ULong=SDL_GetTicksNS()-start
    GCGetStats(after)
    Local allocated:Long=Long(after.allocedBytesBeforeGC)+Long(after.bytesAllocedSinceGC)-Long(before.allocedBytesBeforeGC)-Long(before.bytesAllocedSinceGC)
    Local expected:Int=1
    If kind=2 Then expected=cells
    If cache.runCount<>expected Then Throw "unexpected section count"
    Print (cells*cells*2)+","+names[kind]+","+trial+","+iterations+","+(Double(elapsed)/iterations/1000)+","+(Double(allocated)/iterations)+","+cache.runCount
   Next
  Next
 Next
Catch error:Object
 Print "FAIL: "+error.ToString();EndWithCode(1)
End Try
