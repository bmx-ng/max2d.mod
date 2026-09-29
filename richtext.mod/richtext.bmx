SuperStrict

Rem
bbdoc: Optional, reusable BBCode-style markup for Max2D text layouts.
about: Parse once, prepare with registered styles and fonts, then retain the resulting paragraph layouts for drawing and interaction.
End Rem
Module Max2D.RichText

ModuleInfo "Version: 0.01"
ModuleInfo "License: zlib/libpng"

Import Max2D.Core
Import BRL.Map
Import BRL.StringBuilder

Rem
bbdoc: A partial text style whose unspecified properties inherit from the enclosing style.
about: Font names are case-sensitive. Font sizes identify registered logical sizes; zero selects the family's default registration. Colours are packed RGB values, or -1 to inherit. Configure before registering; registration takes a copy.
End Rem
Type TStyledTextStyle

	Rem
	bbdoc: Bold selection: -1 inherits, 0 disables, 1 enables.
	End Rem
	Field bold:Int=-1

	Rem
	bbdoc: Italic selection: -1 inherits, 0 disables, 1 enables.
	End Rem
	Field italic:Int=-1

	Rem
	bbdoc: Registered font family name, or an empty string to inherit.
	End Rem
	Field fontName:String

	Rem
	bbdoc: Registered logical font size, or zero to inherit.
	End Rem
	Field size:Int

	Rem
	bbdoc: Glyph colour as $RRGGBB, or -1 to inherit the enclosing colour.
	End Rem
	Field foreground:Int=-1

	Rem
	bbdoc: Background colour as $RRGGBB, or -1 to inherit the enclosing background.
	End Rem
	Field background:Int=-1

	Rem
	bbdoc: Opacity from 0 to 1, or -1 to inherit; multiplies drawing alpha for glyphs and backgrounds.
	End Rem
	Field opacity:Float=-1

	Rem
	bbdoc: Returns an independent copy of these style settings.
	End Rem
	Method Copy:TStyledTextStyle()
		Local result:TStyledTextStyle=New TStyledTextStyle
		result.bold=bold
		result.italic=italic
		result.fontName=fontName
		result.size=size
		result.foreground=foreground
		result.background=background
		result.opacity=opacity
		Return result
	End Method
End Type

Rem
bbdoc: Optional application font resolver for families and sizes not registered explicitly.
about: Implementations should cache loaded fonts. The parser never opens font files. Font objects must remain valid and unchanged while prepared layouts are retained.
End Rem
Type TStyledTextFontResolver Abstract

	Rem
	bbdoc: Returns a font for this exact request, or Null if unavailable.
	param: Case-sensitive font family name.
	param: Logical font size; zero requests the family's default size.
	param: Whether bold is requested.
	param: Whether italic is requested.
	End Rem
	Method ResolveFont:TImageFont(name:String,size:Int,bold:Int,italic:Int) Abstract
End Type

Rem
bbdoc: Registered fonts, named styles and defaults used when preparing parsed markup.
about: Preparation snapshots style values and retains font references. Later changes affect subsequent preparations only. A missing bold or italic face falls back to the regular face of the same family and size. Missing families or sizes raise an error.
End Rem
Type TStyledTextStyles

	Rem
	bbdoc: Base style applied before markup; initially uses the default font and current drawing colour.
	End Rem
	Field defaultStyle:TStyledTextStyle=New TStyledTextStyle

	Rem
	bbdoc: Optional resolver queried after explicit registrations, with results cached for each preparation.
	End Rem
	Field resolver:TStyledTextFontResolver

	Private
	Field fonts:TMap=New TMap
	Field styles:TMap=New TMap

	Public
	Rem
	bbdoc: Creates a style collection with a regular font registered as default.
	param: Base font, or Null for Max2D's built-in font.
	End Rem
	Function Create:TStyledTextStyles(font:TImageFont=Null)
		Local result:TStyledTextStyles=New TStyledTextStyles
		If Not font Then font=TImageFont.DefaultFont()
		result.RegisterFont("default",font)
		Return result
	End Function

	Rem
	bbdoc: Registers an actual font face for one family, size and variant.
	param: Nonempty, case-sensitive family name.
	param: Font to retain; must not be Null.
	param: Logical size identifier, or zero for the family's default face.
	param: Whether this face is bold.
	param: Whether this face is italic.
	End Rem
	Method RegisterFont(name:String,font:TImageFont,size:Int=0,bold:Int=False,italic:Int=False)
		If Not name Or Not font Or size<0 Then Throw "Max2D.RichText: invalid font registration"
		fonts.Insert(FontKey(name,size,bold<>0,italic<>0),font)
	End Method

	Rem
	bbdoc: Registers a snapshot of a named partial style.
	param: Nonempty, case-sensitive style name.
	param: Style settings to copy; must not be Null.
	End Rem
	Method RegisterStyle(name:String,style:TStyledTextStyle)
		If Not name Or Not style Then Throw "Max2D.RichText: invalid style registration"
		ValidateStyle(style)
		styles.Insert(name,style.Copy())
	End Method

	Rem
	bbdoc: Returns an independent copy of a named style, or Null if it is not registered.
	param: Case-sensitive style name.
	End Rem
	Method GetStyle:TStyledTextStyle(name:String)
		Local style:TStyledTextStyle=TStyledTextStyle(styles.ValueForKey(name))
		If style Then Return style.Copy()
		Return Null
	End Method

	Rem
	bbdoc: Resolves a registered font or resolver result, falling back to the regular variant.
	param: Case-sensitive font family name.
	param: Logical size identifier, or zero for the family's default face.
	param: Whether bold is requested.
	param: Whether italic is requested.
	returns: A retained font reference; throws if the family or size cannot be resolved.
	End Rem
	Method ResolveFont:TImageFont(name:String,size:Int=0,bold:Int=False,italic:Int=False)
		Local font:TImageFont=TImageFont(fonts.ValueForKey(FontKey(name,size,bold<>0,italic<>0)))
		If Not font And resolver Then font=resolver.ResolveFont(name,size,bold<>0,italic<>0)
		If Not font And (bold Or italic) Then font=ResolveFont(name,size)
		If Not font Then Throw "Max2D.RichText: no font registered for '"+name+"' at size "+size
		Return font
	End Method
End Type

Rem
bbdoc: A recoverable markup error reported by the parser.
End Rem
Type TStyledTextDiagnostic

	Rem
	bbdoc: UTF-16 offset in the original markup at which the error occurred.
	End Rem
	Field offset:Int

	Rem
	bbdoc: Human-readable explanation of the malformed or unsupported tag.
	End Rem
	Field message:String
End Type

Rem
bbdoc: Retained plain text and unresolved style runs parsed from markup.
about: Prepare this document with different themes without reparsing. Selection and caret offsets in prepared layouts refer to PlainText(), not the original markup. No markup-to-text offset map is allocated.
End Rem
Type TStyledTextDocument
	Private
	Field text:String
	Field runs:TRichRun[]=New TRichRun[16]
	Field runCount:Int
	Field nodes:TRichNode[]=New TRichNode[16]
	Field nodeCount:Int
	Field errors:TStyledTextDiagnostic[]=New TStyledTextDiagnostic[8]
	Field errorCount:Int

	Public
	Rem
	bbdoc: Returns the visible text after valid tags have been removed and escapes decoded.
	End Rem
	Method PlainText:String()
		Return text
	End Method

	Rem
	bbdoc: Returns independent diagnostic records for malformed, unknown or unbalanced tags.
	End Rem
	Method Diagnostics:TStyledTextDiagnostic[]()
		Local result:TStyledTextDiagnostic[]=New TStyledTextDiagnostic[errorCount]
		For Local i:Int=0 Until errorCount
			result[i]=New TStyledTextDiagnostic
			result[i].offset=errors[i].offset
			result[i].message=errors[i].message
		Next
		Return result
	End Method

	Rem
	bbdoc: Resolves fonts and colours into a reusable Max2D prepared paragraph.
	param: Font and style collection, or Null for built-in defaults.
	param: Line and word boundary policy.
	param: Optional language hint for boundary providers.
	param: Paragraph direction policy.
	returns: Prepared text whose layouts support drawing, selection and hit testing.
	about: Resolution happens here, never during drawing. Source mapping is enabled for spans; caret geometry remains lazy. Changing fonts or theme settings requires a new preparation. Unregistered named styles raise an error.
	End Rem
	Method Prepare:TPreparedText(styles:TStyledTextStyles=Null,breakMode:ETextBreakMode=ETextBreakMode.Auto,language:String="",direction:ETextDirection=ETextDirection.Auto)
		If Not styles Then styles=TStyledTextStyles.Create()
		Local base:TStyledTextStyle=New TStyledTextStyle
		base.bold=False
		base.italic=False
		base.fontName="default"
		base.opacity=1
		If styles.defaultStyle Then ApplyStyle(base,styles.defaultStyle)
		Local cache:TMap=New TMap
		Local baseFont:TImageFont=FindFont(styles,base,cache)
		Local result:TPreparedText=PrepareText(text,baseFont,breakMode,language,True,direction)
		Local resolved:TStyledTextStyle[]=New TStyledTextStyle[nodeCount]
		For Local i:Int=0 Until nodeCount
			Local node:TRichNode=nodes[i]
			Local parent:TStyledTextStyle=base
			If node.parent>=0 Then parent=resolved[node.parent]
			Local state:TStyledTextStyle=parent.Copy()
			If node.named
				Local named:TStyledTextStyle=styles.GetStyle(node.named)
				If Not named Then Throw "Max2D.RichText: unknown style '"+node.named+"'"
				ApplyStyle(state,named)
			Else
				ApplyStyle(state,node.style)
			End If
			resolved[i]=state
		Next
		Local colors:TTextColorSpan[]=New TTextColorSpan[runCount]
		Local fonts:TTextFontSpan[]=New TTextFontSpan[runCount]
		Local colorCount:Int
		Local fontCount:Int
		For Local i:Int=0 Until runCount
			Local run:TRichRun=runs[i]
			Local state:TStyledTextStyle=base
			If run.node>=0 Then state=resolved[run.node]
			Local font:TImageFont=FindFont(styles,state,cache)
			If font<>baseFont
				If fontCount And fonts[fontCount-1].sourceEnd=run.first And fonts[fontCount-1].font=font
					fonts[fontCount-1].sourceEnd=run.last
				Else
					fonts[fontCount]=TTextFontSpan.Create(run.first,run.last,font)
					fontCount:+1
				End If
			End If
			Local color:TTextColorSpan=TTextColorSpan.Create(run.first,run.last)
			Local rgb:Int=state.foreground
			If rgb<0 And state.opacity<>1 Then color.SetForegroundOpacity(state.opacity)
			If rgb>=0 Then color.SetForeground((rgb Shr 16)&255,(rgb Shr 8)&255,rgb&255,state.opacity)
			If state.background>=0
				rgb=state.background
				color.SetBackground((rgb Shr 16)&255,(rgb Shr 8)&255,rgb&255,state.opacity)
			End If
			If color.hasForeground Or color.hasBackground
				If colorCount And colors[colorCount-1].sourceEnd=run.first And SameColor(colors[colorCount-1],color)
					colors[colorCount-1].sourceEnd=run.last
				Else
					colors[colorCount]=color
					colorCount:+1
				End If
			End If
		Next
		If fontCount Then result.SetFontSpans(fonts[..fontCount])
		If colorCount Then result.SetColorSpans(colors[..colorCount])
		Return result
	End Method

	Rem
	bbdoc: Parses markup into a retained document; equivalent to ParseStyledText.
	param: Markup text using the supported inline tags.
	param: Whether invalid markup should throw instead of remaining literal.
	End Rem
	Function Parse:TStyledTextDocument(markup:String,strict:Int=False)
		Local result:TStyledTextDocument=New TStyledTextDocument
		Local tokens:TRichToken[]=New TRichToken[32]
		Local count:Int
		Local stack:TRichToken[]=New TRichToken[16]
		Local depth:Int
		Local pos:Int
		While pos<markup.Length
			If markup[pos]<>91
				pos:+1
				Continue
			End If
			If pos+1<markup.Length And markup[pos+1]=91
				pos:+2
				Continue
			End If
			Local finish:Int=pos+1
			While finish<markup.Length And markup[finish]<>93 And markup[finish]<>91
				finish:+1
			Wend
			If finish=markup.Length Or markup[finish]<>93
				result.AddError(pos,"Unterminated tag",strict)
				pos=finish
				Continue
			End If
			Local token:TRichToken=ParseTag(markup[pos+1..finish])
			If Not token
				result.AddError(pos,"Unknown tag or invalid value",strict)
				pos=finish+1
				Continue
			End If
			token.first=pos
			token.last=finish+1
			If count=tokens.Length Then tokens=tokens[..tokens.Length*2]
			tokens[count]=token
			count:+1
			If token.closing
				If depth And stack[depth-1].name=token.name
					depth:-1
					token.valid=True
					stack[depth].valid=True
				Else
					result.AddError(pos,"Closing tag does not match the open tag",strict)
				End If
			Else
				If depth=stack.Length Then stack=stack[..stack.Length*2]
				stack[depth]=token
				depth:+1
			End If
			pos=finish+1
		Wend
		For Local i:Int=0 Until depth
			result.AddError(stack[i].first,"Unclosed tag",strict)
		Next
		Local output:TStringBuilder=New TStringBuilder
		Local current:Int=-1
		Local previous:Int
		For Local i:Int=0 Until count
			Local token:TRichToken=tokens[i]
			If Not token.valid Then Continue
			result.AppendLiteral(output,markup[previous..token.first],current)
			If token.closing
				current=result.nodes[current].parent
			Else
				Local node:TRichNode=New TRichNode
				node.parent=current
				node.style=token.style
				node.named=token.named
				If result.nodeCount=result.nodes.Length Then result.nodes=result.nodes[..result.nodes.Length*2]
				current=result.nodeCount
				result.nodes[current]=node
				result.nodeCount:+1
			End If
			previous=token.last
		Next
		result.AppendLiteral(output,markup[previous..],current)
		result.text=output.ToString()
		Return result
	End Function

	Private
	Method FindFont:TImageFont(styles:TStyledTextStyles,style:TStyledTextStyle,cache:TMap)
		Local key:String=FontKey(style.fontName,style.size,style.bold,style.italic)
		Local font:TImageFont=TImageFont(cache.ValueForKey(key))
		If Not font
			font=styles.ResolveFont(style.fontName,style.size,style.bold,style.italic)
			cache.Insert(key,font)
		End If
		Return font
	End Method

	Method AppendLiteral(output:TStringBuilder,value:String,node:Int)
		Local first:Int=output.Length()
		output.Append(value.Replace("[[","["))
		AddRun(first,output.Length(),node)
	End Method

	Method AddError(offset:Int,message:String,strict:Int)
		If strict Then Throw "Max2D.RichText at "+offset+": "+message
		If errorCount=errors.Length Then errors=errors[..errors.Length*2]
		Local error:TStyledTextDiagnostic=New TStyledTextDiagnostic
		error.offset=offset
		error.message=message
		errors[errorCount]=error
		errorCount:+1
	End Method

	Method AddRun(first:Int,last:Int,node:Int)
		If last=first Then Return
		If runCount And runs[runCount-1].node=node
			runs[runCount-1].last=last
			Return
		End If
		If runCount=runs.Length Then runs=runs[..runs.Length*2]
		Local run:TRichRun=New TRichRun
		run.first=first
		run.last=last
		run.node=node
		runs[runCount]=run
		runCount:+1
	End Method
End Type

Rem
bbdoc: Parses optional inline markup into reusable plain text and style runs.
param: Markup with b, i, color, bg, alpha, font, size and style tags.
param: Whether malformed, unsupported or unbalanced tags should throw instead of remaining literal.
returns: A document that can be prepared with different font and style collections.
about: Tags must nest properly. Tag names are case-insensitive; registered names are case-sensitive. Double an opening bracket to display it literally. Parsing does not load fonts or shape text.
End Rem
Function ParseStyledText:TStyledTextDocument(markup:String,strict:Int=False)
	Return TStyledTextDocument.Parse(markup,strict)
End Function

Rem
bbdoc: Parses markup and prepares it with a font and style collection.
param: Markup text; ordinary DrawText and PrepareText do not interpret tags.
param: Font and style collection, or Null for built-in defaults.
param: Whether invalid markup should throw.
param: Line and word boundary policy.
param: Optional language hint for boundary providers.
param: Paragraph direction policy.
about: Call when content changes, retain the result, and reuse its Layout or LayoutBox output when drawing. Use ParseStyledText to retain a document independently of its theme.
End Rem
Function PrepareStyledText:TPreparedText(markup:String,styles:TStyledTextStyles=Null,strict:Int=False,breakMode:ETextBreakMode=ETextBreakMode.Auto,language:String="",direction:ETextDirection=ETextDirection.Auto)
	Return ParseStyledText(markup,strict).Prepare(styles,breakMode,language,direction)
End Function

Rem
bbdoc: Escapes literal text so it can safely be inserted into rich-text markup.
param: Literal text, such as a player's name or chat message.
returns: Text with each opening bracket doubled; closing brackets need no escaping.
End Rem
Function EscapeStyledText:String(text:String)
	Return text.Replace("[","[[")
End Function

Private

Type TRichRun
	Field first:Int
	Field last:Int
	Field node:Int
End Type

Type TRichNode
	Field parent:Int
	Field style:TStyledTextStyle
	Field named:String
End Type

Type TRichToken
	Field first:Int
	Field last:Int
	Field name:String
	Field closing:Int
	Field valid:Int
	Field style:TStyledTextStyle
	Field named:String
End Type

Function FontKey:String(name:String,size:Int,bold:Int,italic:Int)
	Return name.Length+":"+name+":"+size+":"+bold+":"+italic
End Function

Function ValidateStyle(style:TStyledTextStyle)
	If style.bold< -1 Or style.bold>1 Or style.italic< -1 Or style.italic>1 Or style.size<0 Then Throw "Max2D.RichText: invalid font style"
	If style.foreground< -1 Or style.foreground>$FFFFFF Or style.background< -1 Or style.background>$FFFFFF Then Throw "Max2D.RichText: invalid RGB colour"
	If IsNan(style.opacity) Or IsInf(style.opacity) Or (style.opacity<>-1 And (style.opacity<0 Or style.opacity>1)) Then Throw "Max2D.RichText: invalid opacity"
End Function

Function ApplyStyle(target:TStyledTextStyle,source:TStyledTextStyle)
	ValidateStyle(source)
	If source.bold>=0 Then target.bold=source.bold
	If source.italic>=0 Then target.italic=source.italic
	If source.fontName Then target.fontName=source.fontName
	If source.size Then target.size=source.size
	If source.foreground>=0 Then target.foreground=source.foreground
	If source.background>=0 Then target.background=source.background
	If source.opacity>=0 Then target.opacity=source.opacity
End Function

Function SameColor:Int(a:TTextColorSpan,b:TTextColorSpan)
	Return a.inheritForegroundColor=b.inheritForegroundColor And a.hasForeground=b.hasForeground And a.hasBackground=b.hasBackground And a.red=b.red And a.green=b.green And a.blue=b.blue And a.opacity=b.opacity And a.backgroundRed=b.backgroundRed And a.backgroundGreen=b.backgroundGreen And a.backgroundBlue=b.backgroundBlue And a.backgroundOpacity=b.backgroundOpacity
End Function



Function ParseTag:TRichToken(body:String)
	Local token:TRichToken=New TRichToken
	If body.StartsWith("/")
		token.closing=True
		body=body[1..]
	End If
	Local equal:Int=body.Find("=")
	Local value:String
	If equal>=0
		value=body[equal+1..]
		body=body[..equal]
	End If
	token.name=body.ToLower()
	Select token.name
		Case "b","i","color","bg","alpha","font","size","style"
		Default
			Return Null
	End Select
	If token.closing
		If equal>=0 Then Return Null
		Return token
	End If
	token.style=New TStyledTextStyle
	Select token.name
		Case "b","i"
			If equal>=0 Then Return Null
			If token.name="b" Then token.style.bold=True Else token.style.italic=True
		Case "color","bg"
			If value.Length<>7 Or Not value.StartsWith("#") Then Return Null
			Local rgb:Int
			For Local i:Int=1 Until 7
				Local digit:Int="0123456789abcdef".Find(Chr(value[i]).ToLower())
				If digit<0 Then Return Null
				rgb=(rgb Shl 4)|digit
			Next
			If token.name="color" Then token.style.foreground=rgb Else token.style.background=rgb
		Case "font","style"
			If Not value Or value.Trim()<>value Then Return Null
			If token.name="font" Then token.style.fontName=value Else token.named=value
		Case "size"
			If Not value Then Return Null
			Local size:Int
			For Local i:Int=0 Until value.Length
				If value[i]<48 Or value[i]>57 Or size>100000 Then Return Null
				size=size*10+value[i]-48
			Next
			If size<1 Or size>100000 Then Return Null
			token.style.size=size
		Case "alpha"
			If Not value Then Return Null
			Local dots:Int
			Local digits:Int
			For Local i:Int=0 Until value.Length
				If value[i]=46
					dots:+1
				Else If value[i]>=48 And value[i]<=57
					digits:+1
				Else
					Return Null
				End If
			Next
			If dots>1 Or Not digits Then Return Null
			token.style.opacity=Float(value)
			If IsNan(token.style.opacity) Or IsInf(token.style.opacity) Or token.style.opacity<0 Or token.style.opacity>1 Then Return Null
	End Select
	Return token
End Function
