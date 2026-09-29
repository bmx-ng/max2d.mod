SuperStrict

Framework Max2D.RichText
Import BRL.StandardIO

Function Check(ok:Int,message:String)
	If Not ok Then Throw message
End Function

Function Reject(markup:String)
	Local failed:Int
	Try
		ParseStyledText(markup,True)
	Catch error:Object
		failed=True
	End Try
	Check(failed,"Strict parsing must reject: "+markup)
End Function

Local document:TStyledTextDocument=ParseStyledText("A [B]bold [i]italic[/I][/b] [color=#12AbEF]colour[/color].",True)
Check(document.PlainText()="A bold italic colour.","Nested and mixed-case tags")
Check(document.Diagnostics().Length=0,"Valid input has no diagnostics")
Check(ParseStyledText("[[b]hello[[/b] ]",True).PlainText()="[b]hello[/b] ]","Escaped opening brackets and ordinary closing brackets")
Local literal:String="[b]someone[/b] [[ ]]"
Check(ParseStyledText(EscapeStyledText(literal),True).PlainText()=literal,"Escaping arbitrary literal content round-trips")
Check(ParseStyledText("[b]oops").PlainText()="[b]oops","Unclosed tag remains literal")
Check(ParseStyledText("[unknown]oops[/unknown]").PlainText()="[unknown]oops[/unknown]","Unknown tags remain literal")
Check(ParseStyledText("[color=red]oops[/color]").PlainText()="[color=red]oops[/color]","Invalid values remain literal")
Check(ParseStyledText("[b][i]x[/b][/i]").PlainText()="[b]x[/b]","Only correctly paired tags are removed")
Local bad:TStyledTextDocument=ParseStyledText("xx[/b]")
Check(bad.Diagnostics()[0].offset=2,"Diagnostic offsets refer to markup")
Local diagnostics:TStyledTextDiagnostic[]=bad.Diagnostics()
diagnostics[0].offset=99
Check(bad.Diagnostics()[0].offset=2,"Diagnostics cannot mutate document")
For Local input:String=EachIn ["[b]","[/i]","[b][i]x[/b][/i]","[color=#123]x[/color]","[alpha=nan]x[/alpha]","[alpha=1.5]x[/alpha]","[size=0]x[/size]","[size=9999999999999999]x[/size]","[b=x]x[/b]","[style=]x[/style]","[font= x]x[/font]","["]
	Reject(input)
Next

Local styles:TStyledTextStyles=TStyledTextStyles.Create()
Local prepared:TPreparedText=PrepareStyledText("[color=#FF0000]A[color=#00FF00]B[/color]C[/color]D",styles,True)
Local layout:TParagraphLayout=prepared.Layout(500)
Local paint:TTextPaint=layout.PrepareLinePaint(0)
Check(paint.glyphColors[0].red=255 And paint.glyphColors[1].green=255 And paint.glyphColors[2].red=255,"Closing tags restore outer colour")
Check(paint.glyphColors[3]=Null,"Closing outer colour restores drawing colour")
Check(prepared.Layout(500)=layout,"Ordinary retained layout cache is reused")

Local heading:TStyledTextStyle=New TStyledTextStyle
heading.foreground=$123456
heading.background=$203040
styles.RegisterStyle("heading",heading)
heading.foreground=0
Local named:TStyledTextDocument=ParseStyledText("[style=heading]AB[/style]",True)
Local old:TPreparedText=named.Prepare(styles)
paint=old.Layout(500).PrepareLinePaint(0)
Check(paint.glyphColors[0].red=$12 And paint.backgrounds[0].color.backgroundBlue=$40,"Named styles copy foreground and background")
heading.foreground=$ABCDEF
styles.RegisterStyle("heading",heading)
Check(named.Prepare(styles).Layout(500).PrepareLinePaint(0).glyphColors[0].red=$AB,"Document can be re-themed without parsing")
Check(old.Layout(500).PrepareLinePaint(0).glyphColors[0].red=$12,"Existing preparations retain old styles")

paint=PrepareStyledText("[alpha=0.25]A[/alpha]B",styles,True).Layout(500).PrepareLinePaint(0)
Local state:TMax2DState=New TMax2DState
TTextPaint.Apply(state,paint.glyphColors[0],10,20,30,0.5)
Check(state.red=10 And state.green=20 And state.blue=30 And state.alpha=0.125,"Opacity inherits drawing RGB and multiplies alpha")
Local opacity:TTextColorSpan=paint.glyphColors[0].Copy()
opacity.SetForeground(1,2,3)
Check(Not opacity.inheritForegroundColor,"Explicit colour resets opacity-only inheritance")

Local unicode:String="A"+Chr($D83D)+Chr($DE03)
Local unicodeDoc:TStyledTextDocument=ParseStyledText(unicode+"[bg=#112233]B[/bg]",True)
Check(unicodeDoc.PlainText().Length=4,"UTF-16 plain text retains surrogate units")
paint=unicodeDoc.Prepare().Layout(500).PrepareLinePaint(0)
Check(paint.backgrounds[0].color.sourceStart=3 And paint.backgrounds[0].color.sourceEnd=4,"Spans use visible UTF-16 offsets")

Local regular:TImageFont=TImageFont.DefaultFont()
Local bold:TImageFont=New TImageFont
Local italic:TImageFont=New TImageFont
Local both:TImageFont=New TImageFont
styles.RegisterFont("face",regular)
styles.RegisterFont("face",bold,0,True)
styles.RegisterFont("face",italic,0,False,True)
styles.RegisterFont("face",both,0,True,True)
Check(styles.ResolveFont("face",0,True)=bold,"Bold uses registered face")
Check(styles.ResolveFont("face",0,False,True)=italic,"Italic uses registered face")
Check(styles.ResolveFont("face",0,True,True)=both,"Bold italic uses registered face")
Local variants:TPreparedText=PrepareStyledText("[font=face][b]A[i]B[/i]C[/b]D[/font]",styles,True)
Check(variants.fontSpans.Length=3,"Font markup emits expected runs")
Check(variants.fontSpans[0].font=bold And variants.fontSpans[1].font=both And variants.fontSpans[2].font=bold,"Nested font variants restore their parents")
variants=PrepareStyledText("[font=face][b]A[/b][b]B[/b][/font]",styles,True)
Check(variants.fontSpans.Length=1 And variants.fontSpans[0].sourceEnd=2,"Adjacent equivalent font spans merge")
Check(styles.ResolveFont("default",0,True,True)<>Null,"Missing variant falls back to regular")
styles.RegisterFont("face",regular,24)
Check(styles.ResolveFont("face",24,True)=regular,"Fallback keeps requested size")
Local missing:Int
Try
	PrepareStyledText("[size=25]A[/size]",styles,True)
Catch error:Object
	missing=True
End Try
Check(missing,"Unavailable sizes produce an error")
missing=False
Try
	PrepareStyledText("[style=Heading]A[/style]",styles,True)
Catch error:Object
	missing=True
End Try
Check(missing,"Registered style names are case-sensitive")

Type TCountingResolver Extends TStyledTextFontResolver
	Field calls:Int
	Method ResolveFont:TImageFont(name:String,size:Int,bold:Int,italic:Int) Override
		calls:+1
		Return TImageFont.DefaultFont()
	End Method
End Type
Local resolver:TCountingResolver=New TCountingResolver
styles.resolver=resolver
prepared=PrepareStyledText("[font=other]A[color=#FF0000]B[/color]C[/font]",styles,True)
Check(resolver.calls=1,"Font resolution is cached across colour runs")
layout=prepared.Layout(500)
Check(layout.CaretAt(2).sourceOffset=2,"Interaction uses visible text positions")

Local manual:TPreparedText=PrepareText("AB CD EF",regular,ETextBreakMode.Auto,"",True)
Local manualColor:TTextColorSpan=TTextColorSpan.Create(0,5)
manualColor.SetForeground($12,$34,$56)
manualColor.SetBackground($20,$30,$40)
manual.SetColorSpans([manualColor])
Local automatic:TPreparedText=PrepareStyledText("[bg=#203040][color=#123456]AB[/color][color=#123456] CD[/color][/bg] EF",TStyledTextStyles.Create(regular),True)
Check(automatic.fontSpans.Length=0,"Colour-only tags introduce no font spans")
Local automaticPaint:TTextPaint=automatic.Layout(500).PrepareLinePaint(0)
Check(automaticPaint.glyphColors[0]=automaticPaint.glyphColors[3],"Adjacent equivalent paint spans merge")
For Local width:Int=EachIn [16,24,500]
	Local expected:TParagraphLayout=manual.Layout(width)
	Local actual:TParagraphLayout=automatic.Layout(width)
	Check(actual.lines.Length=expected.lines.Length And actual.height=expected.height And actual.width=expected.width,"Markup and manual spans produce equal paragraph geometry")
	For Local line:Int=0 Until actual.lines.Length
		Check(actual.lines[line].text=expected.lines[line].text And actual.lines[line].layout.glyphs.Length=expected.lines[line].layout.glyphs.Length,"Markup and manual spans submit the same glyph counts")
	Next
	For Local offset:Int=0 To 8
		Check(actual.CaretAt(offset).x=expected.CaretAt(offset).x And actual.CaretAt(offset).y=expected.CaretAt(offset).y,"Markup and manual spans produce equal interaction geometry")
	Next
	Check(automatic.Layout(width)=actual,"Repeated draw preparation reuses retained layout")
Next
Check(ParseStyledText("",True).Prepare().Layout(500).lines.Length=0,"Empty document is usable")
Check(ParseStyledText("[b][/b]",True).PlainText()="","Empty style scopes are harmless")

Local longText:TStringBuilder=New TStringBuilder
For Local i:Int=0 Until 1000
	longText.Append("[b]")
Next
longText.Append("x")
For Local i:Int=0 Until 1000
	longText.Append("[/b]")
Next
Check(ParseStyledText(longText.ToString(),True).Prepare().Layout(500).lines[0].text="x","Deep nesting uses an iterative stack")
Print "Max2D rich text tests passed"
