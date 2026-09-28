SuperStrict
Framework Max2D.Core
Import BRL.StandardIO
Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function
Function Near(a:Float,b:Float)
 Check(Abs(a-b)<0.0001,"Coordinate mismatch: "+a+" versus "+b)
End Function

Local view:TMax2DView=New TMax2DView
view.Reset(320,180)
view.presentation=VIRTUAL_INTEGER
' 800x600 window points, 1600x1200 drawable pixels: 5x scale, 150px bars.
Local mapping:TMax2DInputMapping=TMax2DInputMapping.Create(view,800,600,1600,1200)
Local x:Float,y:Float,wx:Float,wy:Float
Check(mapping.WindowToVirtual(25,100,x,y),"Scene point")
Near(x,10); Near(y,10)
Check(Not mapping.WindowToVirtual(25,74,x,y),"Top bar rejected")
Check(y<0,"Outside point is not clamped")
Check(mapping.WindowToVirtual(0,75,x,y),"Inclusive top-left edge")
Check(Not mapping.WindowToVirtual(800,75,x,y),"Exclusive right edge")
Check(Not mapping.WindowToVirtual(0,525,x,y),"Exclusive bottom edge")
mapping.VirtualToWindow(10,10,wx,wy)
Near(wx,25); Near(wy,100)
mapping.WindowDeltaToVirtual(25,-10,x,y)
Near(x,10); Near(y,-4)
view.x=10; view.y=20; view.w=30; view.h=40; view.fullClip=False
Local clipped:TMax2DInputMapping=TMax2DInputMapping.Create(view,800,600,1600,1200)
Check(clipped.WindowToVirtual(0,75,x,y),"Clip does not redefine scene bounds")
Check(Not clipped.WindowToVirtual(0,75,x,y,True),"Optional viewport rejection")
clipped.VirtualToWindow(10,20,wx,wy)
Check(clipped.WindowToVirtual(wx,wy,x,y,True),"Viewport top-left included")
Near(x,10); Near(y,20)
clipped.VirtualToWindow(40,20,wx,wy)
Check(Not clipped.WindowToVirtual(wx,wy,x,y,True),"Viewport right excluded")
view.presentation=VIRTUAL_NATIVE
view.Reset(1600,1200)
Local overlay:TMax2DInputMapping=TMax2DInputMapping.Create(view,800,600,1600,1200)
overlay.WindowToVirtual(25,100,x,y)
Near(x,50); Near(y,200)
mapping.WindowToVirtual(25,100,x,y)
Near(x,10); Near(y,10)
Local invalid:TMax2DInputMapping=TMax2DInputMapping.Create(view,0,0,0,0)
Check(Not invalid.WindowToVirtual(20,20,x,y),"Unavailable window dimensions")
Near(x,0); Near(y,0)

Local state:TMax2DState=New TMax2DState
state.originX=5; state.originY=7
state.rotation=90; state.scaleX=2; state.scaleY=-3; state.Transform()
Local transform:TMax2DDrawTransform=TMax2DDrawTransform.Create(state,100,50,4,6)
transform.LocalToVirtual(4,6,x,y)
Near(x,105); Near(y,57)
transform.LocalToVirtual(5,8,x,y)
Near(x,111); Near(y,59)
Check(transform.VirtualToLocal(x,y,wx,wy),"Reflected rotated transform invertible")
Near(wx,5); Near(wy,8)
state.ix=2; state.iy=1; state.jx=0.5; state.jy=3
transform=TMax2DDrawTransform.Create(state,0,0,0,0)
transform.LocalToVirtual(12,8,x,y)
Check(transform.VirtualToLocal(x,y,wx,wy),"Sheared transform invertible")
Near(wx,12); Near(wy,8)
state.ix=0; state.jx=0
transform=TMax2DDrawTransform.Create(state,0,0,0,0)
Check(Not transform.VirtualToLocal(1,1,x,y),"Collapsed transform rejected")
Near(x,0); Near(y,0)
Print "Max2D input mapping tests passed"
