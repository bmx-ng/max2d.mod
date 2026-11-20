SuperStrict
Framework BRL.StandardIO
Import BRL.LinkedList
Import BRL.Map
Include "model.bmx"
Function Check(value:Int,message:String)
 If Not value Then Throw message
End Function
' Breadth-first search exercises the actual movement/rotation rules, including
' pushing and collision, rather than setting a solved board directly.
For Local room:Int=0 To 2
 Local game:TAfterlight=New TAfterlight
 game.LoadRoom(room)
 Local queue:TList=New TList, seen:TMap=New TMap
 queue.AddLast(""); seen.Insert(game.Snapshot(),"")
 Local solution:String, found:Int
 While Not queue.IsEmpty()
  Local path:String=String(queue.RemoveFirst())
  game.LoadRoom(room); game.moves=0
  For Local c:Int=0 Until path.Length
   Select path[c]
    Case 85; game.Move(0,-1)
    Case 68; game.Move(0,1)
    Case 76; game.Move(-1,0)
    Case 82; game.Move(1,0)
    Case 65; game.Act()
   End Select
  Next
  If game.room<>room Or game.won Then solution=path; found=True; Exit
  For Local a:Int=0 Until 5
   Local before:String=game.Snapshot(), changed:Int
   Select a
    Case 0; changed=game.Move(0,-1)
    Case 1; changed=game.Move(0,1)
    Case 2; changed=game.Move(-1,0)
    Case 3; changed=game.Move(1,0)
    Case 4; changed=game.Act()
   End Select
   If changed Then
    If game.room<>room Or game.won Then solution=path+"UDLRA"[a..a+1]; found=True; Exit
    Local key:String=game.px+","+game.py+","+game.bx+","+game.by+","+game.mirror[0]+","+game.mirror[1]
    If Not seen.Contains(key) Then seen.Insert(key,""); queue.AddLast(path+"UDLRA"[a..a+1])
    game.Undo()
    Check(game.Snapshot()=before,"Undo failed")
   End If
  Next
  If found Then Exit
 Wend
 Check(found,"Unsolvable room "+room)
 Print "Room "+(room+1)+" solved: "+solution+" ("+solution.Length+" actions); undo verified"
Next
Local g:TAfterlight=New TAfterlight
g.LoadRoom(0)
Check(Not g.Move(2,0),"Invalid movement accepted")
g.px=11; g.py=4
Check(Not g.Move(1,0),"Unpowered door opened")
g.LoadRoom(2); Check(g.history.Length=0 And Not g.lit,"Reset failed")
Print "PASS: all three rooms solvable, undo, reset, movement and locked exit"
