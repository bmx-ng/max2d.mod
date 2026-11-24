' Scene components contain no input polling or camera controller.
Type TChartGrid Extends TCustomDrawNode
 Method OnDraw(context:TSceneDrawContext) Override
  context.SetColor(17,34,48); SetLineWidth(1)
  For Local x:Int=-1200 To 1200 Step 100
   DrawLine(x,-900,x,900)
  Next
  For Local y:Int=-900 To 900 Step 100
   DrawLine(-1200,y,1200,y)
  Next
  context.SetColor(65,95,115)
  For Local i:Int=0 Until 180
   Local x:Int=(i*379 Mod 2400)-1200, y:Int=(i*241 Mod 1800)-900
   DrawRect(x,y,2,2)
  Next
 End Method
End Type

Type TStationArt Extends TCustomDrawNode
 Field draws:Long
 Method OnDraw(context:TSceneDrawContext) Override
  draws:+1
  context.SetColor(15,40,58); DrawOval(-35,-35,70,70)
  context.SetColor(80,185,210); SetLineWidth(3)
  For Local i:Int=0 Until 6
   Local a:Float=i*60
   DrawLine(Float(Cos(a)*19),Float(Sin(a)*19),Float(Cos(a)*42),Float(Sin(a)*42))
  Next
  context.SetColor(110,225,240); DrawOval(-17,-17,34,34)
  context.SetColor(225,250,255); DrawOval(-7,-7,14,14)
 End Method
End Type

Type TChartStation Extends TCompositeNode
 Field requested:Int, art:TStationArt
 Field worldX:Float,worldY:Float, label:String
 Function Create:TChartStation(label:String,x:Float,y:Float,font:TImageFont)
  Local station:TChartStation=New TChartStation
  station.label=label; station.worldX=x; station.worldY=y
  station.SetName(label); station.SetPosition(x,y)
  station.SetCacheMode(ESceneCacheMode.Automatic)
  station.SetCaptureRect(TSceneRect.Create(-60,-45,120,115))
  station.SetInteractive(True); station.SetHitRect(TSceneRect.Create(-45,-45,90,90))
  station.art=New TStationArt
  station.art.SetSelfBounds(TSceneRect.Create(-44,-44,88,88)); station.AddChild(station.art)
  Local text:TTextNode=TTextNode.Create(label,font)
  text.SetPosition(-48,48); station.AddChild(text)
  Return station
 End Function
 Method OnPointer(event:TScenePointerEvent) Override
  If event.Kind()=EScenePointerKind.Down Then requested=True; event.Handle()
 End Method
End Type

Type TSurveyShip Extends TCustomDrawNode
 Field points:Float[]=[0.0,-20.0,13.0,17.0,0.0,10.0,-13.0,17.0]
 Method OnDraw(context:TSceneDrawContext) Override
  context.SetColor(255,190,90)
  DrawPoly(points)
  context.SetColor(240,250,255); DrawOval(-4,-5,8,8)
 End Method
End Type

Type TChartButton Extends TCustomDrawNode
 Field requested:Int
 Function Create:TChartButton(label:String,font:TImageFont,x:Float,y:Float)
  Local button:TChartButton=New TChartButton
  button.SetName(label); button.SetPosition(x,y)
  button.SetSelfBounds(TSceneRect.Create(0,0,220,38)); button.SetInteractive(True)
  Local text:TTextNode=TTextNode.Create(label,font)
  text.SetPosition(12,10); button.AddChild(text)
  Return button
 End Function
 Method OnPointer(event:TScenePointerEvent) Override
  If event.Kind()=EScenePointerKind.Down Then requested=True; event.Handle()
 End Method
 Method TakeRequest:Int()
  Local result:Int=requested; requested=False; Return result
 End Method
 Method OnDraw(context:TSceneDrawContext) Override
  context.SetColor(29,55,72); DrawRect(0,0,220,38)
  context.SetColor(85,165,190); DrawRect(0,0,3,38)
 End Method
End Type
