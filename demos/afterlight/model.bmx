' Pure puzzle rules: no graphics or input dependencies.
Const COLS:Int=13, ROWS:Int=9
Type TAfterlight
 Field room:Int, px:Int, py:Int, bx:Int, by:Int, turns:Int, moves:Int
 Field mirror:Int[2], mx:Int[2], my:Int[2], mirrorCount:Int
 Field rx:Int, ry:Int, lit:Int, won:Int, revision:Int
 Field beamX:Int[128], beamY:Int[128], beamCount:Int
 Field history:String[]
 Method LoadRoom(index:Int)
  room=index; px=2; py=7; bx=3; by=6; mirrorCount=index; lit=False; won=False
  mirror[0]=0; mirror[1]=0; mx[0]=7; my[0]=4; mx[1]=6; my[1]=2
  rx=10; ry=4
  If room=1 Then rx=7; ry=1
  If room=2 Then mx[0]=6; rx=10; ry=2
  history=New String[0]
  Trace(); revision:+1
 End Method
 Method Wall:Int(x:Int,y:Int)
  If x=12 And y=4 Then Return Not lit
  If x<1 Or x>11 Or y<1 Or y>7 Then Return True
  If y=6 And x>=6 And x<=9 Then Return True
  If room<2 And y=2 And x>=3 And x<=5 Then Return True
  Return False
 End Method
 Method MirrorAt:Int(x:Int,y:Int)
  For Local i:Int=0 Until mirrorCount
   If mx[i]=x And my[i]=y Then Return i
  Next
  Return -1
 End Method
 Method Blocked:Int(x:Int,y:Int)
  Return Wall(x,y) Or MirrorAt(x,y)>=0 Or (x=rx And y=ry)
 End Method
 Method Snapshot:String()
  Return px+","+py+","+bx+","+by+","+mirror[0]+","+mirror[1]+","+moves
 End Method
 Method Remember()
  history=history[..history.Length+1]; history[history.Length-1]=Snapshot()
 End Method
 Method Undo()
  If Not history.Length Then Return
  Local values:String[]=history[history.Length-1].Split(",")
  history=history[..history.Length-1]
  px=Int(values[0]); py=Int(values[1]); bx=Int(values[2]); by=Int(values[3])
  mirror[0]=Int(values[4]); mirror[1]=Int(values[5]); moves=Int(values[6])
  Trace(); revision:+1
 End Method
 Method Move:Int(dx:Int,dy:Int)
  If Abs(dx)+Abs(dy)<>1 Or won Then Return False
  Local x:Int=px+dx,y:Int=py+dy
  If Blocked(x,y) Then Return False
  If x=bx And y=by Then
   If Blocked(bx+dx,by+dy) Or bx+dx=12 Then Return False
  End If
  Remember()
  If x=bx And y=by Then bx:+dx; by:+dy
  px=x; py=y; moves:+1
  If px=12 Then
   If room=2 Then won=True Else LoadRoom(room+1)
  End If
  Trace(); revision:+1
  Return True
 End Method
 Method Act:Int()
  For Local i:Int=0 Until mirrorCount
   If Abs(px-mx[i])+Abs(py-my[i])=1 Then
    Remember(); mirror[i]=1-mirror[i]; moves:+1; turns:+1
    Trace(); revision:+1; Return True
   End If
  Next
  Return False
 End Method
 Method Trace()
  lit=False; beamCount=0
  If bx<>3 Or by<>4 Then Return
  Local x:Int=3,y:Int=4,dx:Int=1,dy:Int=0
  For Local rayStep:Int=0 Until 127
   beamX[beamCount]=x; beamY[beamCount]=y; beamCount:+1
   If x=rx And y=ry Then lit=True; Exit
   Local m:Int=MirrorAt(x,y)
   If m>=0 Then
    Local oldDX:Int=dx
    If mirror[m] Then dx=-dy; dy=-oldDX Else dx=dy; dy=oldDX
   End If
   x:+dx; y:+dy
   If x<1 Or x>11 Or y<1 Or y>7 Or Wall(x,y) Then Exit
  Next
 End Method
 Method Hint:String()
  If lit Then Return "Circuit restored. Follow the light to the east airlock."
  If bx<>3 Or by<>4 Then Return "Push the amber cell onto the ringed socket."
  If room=1 Then Return "Stand beside the mirror. ACT rotates it towards the receiver."
  Return "Turn both mirrors to carry the beam north, then east."
 End Method
End Type
