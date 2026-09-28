SuperStrict
Framework Max2D.Core
Import BRL.StandardIO
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Near(a:Float,b:Float)
 Check(Abs(a-b)<0.001,"Coordinate mismatch: "+a+" / "+b)
End Function
Local camera:TCamera2D=New TCamera2D
camera.x=100;camera.y=-20;camera.offsetX=160;camera.offsetY=90;camera.zoom=2;camera.rotation=90
Local x:Float,y:Float
Local rotatedCorners:Float[]=camera.WorldCorners(0,0,320,180)
Local rotatedExpected:Float[]=[145.0,-100.0,145.0,60.0,55.0,60.0,55.0,-100.0]
For Local i:Int=0 Until 8
 Near(rotatedCorners[i],rotatedExpected[i])
Next
camera.WorldToVirtual(100,-20,x,y);Near(x,160);Near(y,90)
camera.WorldToVirtual(110,-20,x,y);Near(x,160);Near(y,70)
camera.VirtualToWorld(x,y,x,y);Near(x,110);Near(y,-20)
For Local angle:Int=-180 To 180 Step 17
 camera.rotation=angle
 camera.WorldToVirtual(-31,67,x,y)
 camera.VirtualToWorld(x,y,x,y);Near(x,-31);Near(y,67)
Next
Local view:TMax2DView=New TMax2DView
view.Reset(320,180);view.presentation=VIRTUAL_LETTERBOX
Local input:TMax2DCameraInput=New TMax2DCameraInput
input.mapping=TMax2DInputMapping.Create(view,640,480,1280,960)
input.camera=camera.Copy()
Check(input.WorldToWindow(100,-20,x,y),"Valid world mapping")
Near(x,320);Near(y,240)
Check(input.WindowToWorld(x,y,x,y),"Centre inside scene");Near(x,100);Near(y,-20)
Check(Not input.WindowToWorld(0,0,x,y),"Letterbox bars are outside")
input.mapping=TMax2DInputMapping.Create(view,0,0,0,0)
Check(Not input.WindowToWorld(12,34,x,y),"Invalid output rejected");Near(x,0);Near(y,0)
For Local angle:Int=-180 To 180 Step 30
 camera.rotation=angle;camera.zoom=1.25;camera.x=30;camera.y=-12
 Local anchorX:Float,anchorY:Float
 camera.VirtualToWorld(47,113,anchorX,anchorY)
 camera.ZoomAt(3,47,113)
 camera.WorldToVirtual(anchorX,anchorY,x,y);Near(x,47);Near(y,113)
 camera.ZoomAt(1.25,47,113);Near(camera.x,30);Near(camera.y,-12)
 Local corners:Float[]=camera.WorldCorners(10,20,120,70)
 Check(corners.Length=8,"Four world corners")
 Local expected:Float[]=[10.0,20.0,130.0,20.0,130.0,90.0,10.0,90.0]
 For Local i:Int=0 Until 8 Step 2
  camera.WorldToVirtual(corners[i],corners[i+1],x,y)
  Near(x,expected[i]);Near(y,expected[i+1])
 Next
Next
Local original:TCamera2D=camera.Copy()
Local rejected:Int
Try
 camera.ZoomAt(-1,0,0)
Catch error:Object
 rejected=True
End Try
Check(rejected,"Invalid anchored zoom rejected")
Near(camera.x,original.x);Near(camera.y,original.y);Near(camera.zoom,original.zoom)
rejected=False
Try
 camera.WorldCorners(0,0,-1,10)
Catch error:Object
 rejected=True
End Try
Check(rejected,"Negative view rectangle rejected")
rejected=False
camera.zoom=0
Try
 camera.Validate()
Catch e:Object
 rejected=True
End Try
Check(rejected,"Zero zoom rejected")
Print "Max2D camera math tests passed"
