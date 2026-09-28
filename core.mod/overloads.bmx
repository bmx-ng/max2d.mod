' Numeric overloads preserve the familiar API; renderer geometry remains Float.
Function Plot(x:Double,y:Double)
	Plot(Float(x),Float(y))
End Function
Function DrawRect(x:Double,y:Double,width:Double,height:Double)
	DrawRect(Float(x),Float(y),Float(width),Float(height))
End Function
Function DrawLine(x:Double,y:Double,x2:Double,y2:Double,draw_last_pixel:Int = True)
	DrawLine(Float(x),Float(y),Float(x2),Float(y2),draw_last_pixel)
End Function
Function DrawOval(x:Double,y:Double,width:Double,height:Double)
	DrawOval(Float(x),Float(y),Float(width),Float(height))
End Function
Function DrawImage(image:TImage,x:Double,y:Double,frame:Int=0)
	DrawImage(image,Float(x),Float(y),frame)
End Function
Function DrawImageRect(image:TImage,x:Double,y:Double,width:Double,height:Double,frame:Int=0)
	DrawImageRect(image,Float(x),Float(y),Float(width),Float(height),frame)
End Function
Function DrawSubImageRect(image:TImage,x:Double,y:Double,width:Double,height:Double,sx:Double,sy:Double,swidth:Double,sheight:Double,hx:Double=0,hy:Double=0,frame:Int=0)
	DrawSubImageRect(image,Float(x),Float(y),Float(width),Float(height),Float(sx),Float(sy),Float(swidth),Float(sheight),Float(hx),Float(hy),frame)
End Function
Function SetAlpha(alpha:Double)
	SetAlpha(Float(alpha))
End Function
Function SetLineWidth(width:Double)
	SetLineWidth(Float(width))
End Function
Function SetOrigin(x:Double,y:Double)
	SetOrigin(Float(x),Float(y))
End Function
Function SetHandle(x:Double,y:Double)
	SetHandle(Float(x),Float(y))
End Function
Function SetRotation(rotation:Double)
	SetRotation(Float(rotation))
End Function
Function SetScale(x:Double,y:Double)
	SetScale(Float(x),Float(y))
End Function
Function SetTransform(rotation:Double,scale_x:Double=1,scale_y:Double=1)
	SetTransform(Float(rotation),Float(scale_x),Float(scale_y))
End Function
Function SetImageHandle(image:TImage,x:Double,y:Double)
	SetImageHandle(image,Float(x),Float(y))
End Function
Function DrawText(text:String,x:Double,y:Double)
	DrawText(text,Float(x),Float(y))
End Function
Function SetVirtualResolution(width:Double,height:Double,presentation:Int=VIRTUAL_STRETCH)
	SetVirtualResolution(Float(width),Float(height),presentation)
End Function
Function MoveVirtualMouse(x:Double,y:Double)
	MoveVirtualMouse(Float(x),Float(y))
End Function
Function TileImage(image:TImage,x:Double,y:Double=0,frame:Int=0)
	TileImage(image,Float(x),Float(y),frame)
End Function
