SuperStrict
Framework Max2D.Core
Import Max2D.ScalableFont
Import Text.Unibreak
Import BRL.StandardIO
Import BRL.System
If AppArgs.Length<2 Then Throw "Supply NotoSans-Regular.ttf"
Local font:TScalableImageFont=LoadScalableImageFont(AppArgs[1],18)
If Not font Then Throw "Could not load benchmark font"
Local text:String
For Local i:Int=0 Until 100
	text:+"An office AV test with words and spaces. "
Next
Local start:Int=MilliSecs()
Local prepared:TPreparedText=PrepareText(text,font,ETextBreakMode.Auto,"",True)
Local layout:TParagraphLayout=prepared.Layout(500)
Local prepareTime:Int=MilliSecs()-start
Local beforeStats:SGCStats,afterStats:SGCStats
GCGetStats(beforeStats)
start=MilliSecs()
layout.PrepareInteraction()
Local buildTime:Int=MilliSecs()-start
GCGetStats(afterStats)
Local buildBytes:Long=Long(afterStats.allocedBytesBeforeGC+afterStats.bytesAllocedSinceGC-beforeStats.allocedBytesBeforeGC-beforeStats.bytesAllocedSinceGC)
GCGetStats(beforeStats)
start=MilliSecs()
Local checksum:Long
For Local i:Int=0 Until 100000
	checksum:+layout.HitTest(i Mod 500,i Mod Int(layout.height)).sourceOffset
	checksum:+layout.CaretAt(i Mod text.Length).sourceOffset
Next
Local queryTime:Int=MilliSecs()-start
GCGetStats(afterStats)
Local queryBytes:Long=Long(afterStats.allocedBytesBeforeGC+afterStats.bytesAllocedSinceGC-beforeStats.allocedBytesBeforeGC-beforeStats.bytesAllocedSinceGC)
Print "units="+text.Length+" lines="+layout.lines.Length+" prepare/layout ms="+prepareTime
Print "caret build ms="+buildTime+" managed allocation bytes="+buildBytes
Print "200000 queries ms="+queryTime+" managed allocation bytes="+queryBytes+" checksum="+checksum
If queryBytes Then Throw "Warm interaction unexpectedly allocated"

Local selection:TTextSelectionRect[]=layout.SelectionRectsVisible(2,2000,200,400)
GCGetStats(beforeStats)
start=MilliSecs()
For Local i:Int=0 Until 100000
	If layout.SelectionRectsVisible(2,2000,200,400)<>selection Then Throw "Selection cache missed"
Next
queryTime=MilliSecs()-start
GCGetStats(afterStats)
queryBytes=Long(afterStats.allocedBytesBeforeGC+afterStats.bytesAllocedSinceGC-beforeStats.allocedBytesBeforeGC-beforeStats.bytesAllocedSinceGC)
Print "100000 warm selection queries ms="+queryTime+" managed allocation bytes="+queryBytes
If queryBytes Then Throw "Warm selection unexpectedly allocated"

Local controller:TTextSelectionController=New TTextSelectionController
controller.SetLayout(layout)
controller.PointerDown(20,0,1000,2)
' Warm the second target line as well before measuring repeated word drags.
controller.PointerMove(100,30)
GCGetStats(beforeStats)
start=MilliSecs()
For Local i:Int=0 Until 100000
	controller.PointerMove(20+(i Mod 2)*80,(i Mod 2)*30)
Next
queryTime=MilliSecs()-start
GCGetStats(afterStats)
queryBytes=Long(afterStats.allocedBytesBeforeGC+afterStats.bytesAllocedSinceGC-beforeStats.allocedBytesBeforeGC-beforeStats.bytesAllocedSinceGC)
Print "100000 warm word-drag updates ms="+queryTime+" managed allocation bytes="+queryBytes
If queryBytes Then Throw "Warm word dragging unexpectedly allocated"

Local foreground:TTextColorSpan=TTextColorSpan.Create(0,text.Length)
foreground.SetForeground(255,100,50)
foreground.SetBackground(20,30,50)
prepared.SetColorSpans([foreground])
Local paint:TTextPaint=layout.PrepareLinePaint(0)
GCGetStats(beforeStats)
start=MilliSecs()
For Local i:Int=0 Until 100000
	If layout.PrepareLinePaint(0)<>paint Then Throw "Paint cache missed"
Next
queryTime=MilliSecs()-start
GCGetStats(afterStats)
queryBytes=Long(afterStats.allocedBytesBeforeGC+afterStats.bytesAllocedSinceGC-beforeStats.allocedBytesBeforeGC-beforeStats.bytesAllocedSinceGC)
Print "100000 warm paint queries ms="+queryTime+" managed allocation bytes="+queryBytes
If queryBytes Then Throw "Warm paint unexpectedly allocated"
