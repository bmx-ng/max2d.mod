Import BRL.BankStream

Function DDSTestPut(bytes:Byte[],offset:Int,value:Long)
	For Local i:Int=0 Until 4
		bytes[offset+i]=Byte(value Shr (8*i))
	Next
End Function

Function DDSTestBytes:Byte[](format:Int=PF_BC1_RGBA,mips:Int=4,dx10:Int=False)
	Local header:Int=128
	If dx10 Then header=148
	Local block:Int=8
	If format=PF_BC3_RGBA Then block=16
	Local size:Int=header
	Local width:Int=8
	For Local i:Int=0 Until mips
		size:+(((width+3)/4)*((width+3)/4))*block
		width=Max(1,width/2)
	Next
	Local bytes:Byte[]=New Byte[size]
	DDSTestPut(bytes,0,$20534444)
	DDSTestPut(bytes,4,124)
	DDSTestPut(bytes,8,$a1007)
	DDSTestPut(bytes,12,8)
	DDSTestPut(bytes,16,8)
	DDSTestPut(bytes,20,4*block)
	DDSTestPut(bytes,28,mips)
	DDSTestPut(bytes,76,32)
	DDSTestPut(bytes,80,4)
	Local fourCC:Long=$31545844
	If format=PF_BC3_RGBA Then fourCC=$35545844
	If dx10 Then fourCC=$30315844
	DDSTestPut(bytes,84,fourCC)
	DDSTestPut(bytes,108,$401008)
	If dx10 Then
		Local dxgi:Int=71
		If format=PF_BC3_RGBA Then dxgi=77
		DDSTestPut(bytes,128,dxgi)
		DDSTestPut(bytes,132,3)
		DDSTestPut(bytes,140,1)
		DDSTestPut(bytes,144,1)
	End If
	width=8
	Local offset:Int=header
	For Local i:Int=0 Until mips
		For Local j:Int=0 Until (((width+3)/4)*((width+3)/4))
			Local colour:Int=$f800
			If i Mod 3=1 Then colour=$07e0
			If i Mod 3=2 Then colour=$001f
			Local rgb:Int=offset
			If format=PF_BC3_RGBA Then
				bytes[offset]=255
				rgb:+8
			End If
			bytes[rgb]=colour & 255
			bytes[rgb+1]=colour Shr 8
			offset:+block
		Next
		width=Max(1,width/2)
	Next
	Return bytes
End Function

Function DDSTestStream:TBankStream(bytes:Byte[])
	Local stream:TBankStream=CreateBankStream(Null)
	stream.WriteBytes(bytes,bytes.Length)
	stream.Seek(0)
	Return stream
End Function
