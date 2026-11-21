' Cardinal grid input shared by the game and its touch regression test.
Function ResolveDirection(keyX:Int,keyY:Int,stickX:Float,stickY:Float,dx:Int Var,dy:Int Var)
 dx=Sgn(keyX); dy=Sgn(keyY)
 If Abs(stickX)>0.38 Or Abs(stickY)>0.38 Then
  If Abs(stickX)>Abs(stickY) Then dx=Sgn(stickX); dy=0 Else dy=Sgn(stickY); dx=0
 End If
 If dx<>0 Then dy=0
End Function
