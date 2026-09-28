' Example policy: map editor families to a platform sans-serif face. Games should
' supply their own resolver with bundled font files for consistent appearance.
Type TTiledExampleFonts Extends TTiledFontResolver
	Field fonts:TTreeMap<String,TImageFont>=New TTreeMap<String,TImageFont>
	Method Resolve:TImageFont(family:String,pixelSize:Int,bold:Int,italic:Int,kerning:Int) Override
		Local key:String=pixelSize+":"+bold+":"+italic+":"+kerning
		Local font:TImageFont
		If fonts.TryGetValue(key,font) Then Return font
		Local path:String
		?osx
		Local name:String="Arial"
		If bold Then name:+" Bold"
		If italic Then name:+" Italic"
		path="/System/Library/Fonts/Supplemental/"+name+".ttf"
		?win32
		Local name:String="segoeui"
		If bold And italic Then
			name:+"z"
		Else If bold Then
			name:+"b"
		Else If italic Then
			name:+"i"
		End If
		path=getenv_("WINDIR")+"/Fonts/"+name+".ttf"
		?linux
		Local name:String="DejaVuSans"
		If bold And italic Then
			name:+"-BoldOblique"
		Else If bold Then
			name:+"-Bold"
		Else If italic Then
			name:+"-Oblique"
		End If
		path="/usr/share/fonts/truetype/dejavu/"+name+".ttf"
		?
		If FileType(path)=FILETYPE_FILE Then
			Local style:Int=SMOOTHFONT|LIGATURESFONT
			If kerning Then style:|KERNFONT
			font=LoadScalableImageFont(path,Float(pixelSize),style)
		End If
		fonts.Put(key,font)
		Return font
	End Method
End Type
