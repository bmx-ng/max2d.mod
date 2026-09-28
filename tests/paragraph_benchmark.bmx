SuperStrict
Framework Max2D.ScalableFont
Import BRL.StandardIO
' Diagnostic timings, deliberately not pass/fail performance thresholds.
If AppArgs.Length<2 Then Throw "Supply an outline font path"
Local font:TImageFont=LoadScalableImageFont(AppArgs[1],18)
If Not font Then Throw "Could not load font"
Local text:String="Prepare once and draw repeatedly. This paragraph has ordinary words, office ligatures and AV kerning. Resize the panel to rearrange lines while retaining the text and font. "
text:+text+text
Local started:Int=MilliSecs()
Local prepared:TPreparedText
For Local i:Int=0 Until 100
 prepared=PrepareText(text,font)
 prepared.Layout(420)
Next
Print "Prepare plus initial layout, warmed font, milliseconds per call: "+Float(MilliSecs()-started)/100
Local builds:Long=font.layoutBuilds
started=MilliSecs()
For Local i:Int=0 Until 10000
 prepared.Layout(420)
Next
Print "Cached layout requests, 10000 calls, milliseconds: "+(MilliSecs()-started)
Print "Additional font layout builds: "+(font.layoutBuilds-builds)
started=MilliSecs()
For Local i:Int=0 Until 200
 prepared.Layout(240+i)
Next
Print "Uncached width changes, milliseconds per call: "+Float(MilliSecs()-started)/200
