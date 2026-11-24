SuperStrict
Framework BRL.StandardIO
Import Max2D.Lighting
Global checks:Int
Function Check(value:Int,message:String)
 If Not value Then Throw message
 checks:+1
End Function
Try
 Local points:Float[]=[0.0,0.0,12.0,0.0,12.0,4.0,4.0,4.0,4.0,12.0,0.0,12.0]
 Local shape:TMax2DLightOccluder=TMax2DLightOccluder.Create(points)
 Local revision:Long=shape.Revision()
 shape.SetPolygon(points)
 Check(shape.Revision()=revision,"unchanged concave geometry preserves revision")
 Local invalid:Float[][]=[ [0.0,0.0,12.0,12.0,0.0,12.0,12.0,0.0], [0.0,0.0,12.0,0.0,12.0,12.0,0.0,0.0], [0.0,0.0,6.0,0.0,12.0,0.0,0.0,12.0], [0.0,0.0,12.0,0.0,12.0,12.0,6.0,0.0,0.0,12.0] ]
 For Local polygon:Float[]=EachIn invalid
  Local rejected:Int
  Try
   shape.SetPolygon(polygon)
  Catch error:Object
   rejected=True
  End Try
  Check(rejected And shape.Revision()=revision,"invalid outline rejects atomically")
 Next
 Local transformed:TMax2DLightOccluder=TMax2DLightOccluder.Create(points)
 transformed.SetTransformFrom(shape,-2,0.5,0,3,10,20)
 revision=transformed.Revision()
 transformed.SetTransformFrom(shape,-2,0.5,0,3,10,20)
 Check(transformed.Revision()=revision,"unchanged mirrored concave transform retains storage")
 transformed.SetTransformFrom(shape,0,0,0,0,10,20)
 transformed.SetTransformFrom(shape,1,0,0,1,0,0)
 Check(transformed.Revision()>revision,"collapsed geometry can recover")
 Print "PASS: "+checks+" occluder geometry checks"
Catch error:Object
 Print "FAILED: "+error.ToString()
 EndWithCode(1)
End Try
