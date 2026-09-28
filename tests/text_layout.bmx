SuperStrict
Framework Max2D.Core
Import BRL.StandardIO

Function Check(ok:Int,message:String)
 If Not ok Then Throw message
End Function

' Synthetic shaping exposes glyph-count/positioning mistakes independently of
' the font installed on the machine or a particular shaping implementation.
Type TTestGlyph Extends TGlyph
 Field bearing:Int
 Field advanceValue:Float
 Method Pixels:Object() Override
  Local p:TPixmap=CreatePixmap(5,7,PF_RGBA8888)
  p.ClearPixels($ffffffff)
  Return p
 End Method
 Method Advance:Float() Override
  Return advanceValue
 End Method
 Method GetRect(x:Int Var,y:Int Var,width:Int Var,height:Int Var) Override
  x=bearing; y=-2; width=5; height=7
 End Method
 Method Index:Int() Override
  Return 1
 End Method
 Function Create:TTestGlyph(bearing:Int,advanceValue:Float)
  Local glyph:TTestGlyph=New TTestGlyph
  glyph.bearing=bearing; glyph.advanceValue=advanceValue
  Return glyph
 End Function
End Type
Type TTestFont Extends TFont
 Field shapeCalls:Int
 Method Style:Int() Override
  Return LIGATURESFONT
 End Method
 Method Height:Int() Override
  Return 12
 End Method
 Method CountGlyphs:Int() Override
  Return 2
 End Method
 Method CharToGlyph:Int(char:Int) Override
  Return 1
 End Method
 Method LoadGlyph:TGlyph(index:Int) Override
  Return TTestGlyph.Create(0,6)
 End Method
 Method LoadGlyphs:TGlyph[](text:String) Override
  shapeCalls:+1
  If text="fi" Then Return [TGlyph(TTestGlyph.Create(-2,8.5))]
  If text="x" Then Return [TGlyph(TTestGlyph.Create(-2,4)),TGlyph(TTestGlyph.Create(1,3))]
  If Not text Then Return New TGlyph[0]
  Return [TGlyph(TTestGlyph.Create(0,6))]
 End Method
End Type

Local source:TTestFont=New TTestFont
Local font:TImageFont=TImageFont.FromFont(source)
Local ligature:TTextLayout=font.Layout("fi")
Check(ligature.glyphs.Length=1,"Two characters must allow one glyph")
Check(ligature.width=8.5,"Fractional advance")
Check(ligature.boundsX=-2 And ligature.boundsY=-2,"Negative glyph bearings")
Check(ligature.boundsWidth=5 And ligature.boundsHeight=7,"Glyph bitmap bounds")
Local expanded:TTextLayout=font.Layout("x")
Check(expanded.glyphs.Length=2,"One character must allow multiple glyphs")
Check(expanded.glyphs[0].x=-2 And expanded.glyphs[1].x=5,"Per-occurrence glyph offsets")
Check(expanded.width=7 And expanded.boundsWidth=12,"Advance and bitmap bounds are distinct")
Check(expanded.glyphs[0].image=expanded.glyphs[1].image,"Repeated glyph shares storage")
Check(font.glyphBuilds=1,"Glyph-index cache across shaped strings")
Local multiline:TTextLayout=font.Layout("fi~nx")
Check(multiline.height=24 And multiline.width=8.5,"Multiline advances")
Check(multiline.boundsHeight=19,"Multiline bitmap bounds")
Local empty:TTextLayout=font.Layout("")
Check(empty.glyphs.Length=0 And empty.boundsWidth=0 And empty.boundsHeight=0,"Empty layout bounds")
font.ClearLayoutCache()
font.SetLayoutCacheLimit(2)
Local one:TTextLayout=font.Layout("one")
font.Layout("two")
Check(font.Layout("one")=one,"Cached identity")
font.Layout("three")
Check(font.Layout("one")=one,"Frequently used layout stays cached")
Local calls:Int=source.shapeCalls
font.Layout("two")
Check(source.shapeCalls=calls+1,"Least recently used layout was evicted")
font.SetLayoutCacheLimit(0)
Check(font.Layout("one")<>font.Layout("one"),"Disabled cache")
Check(ligature.glyphs[0].image<>Null,"Eviction must not invalidate retained layouts")
Print "Max2D text layout tests passed"
