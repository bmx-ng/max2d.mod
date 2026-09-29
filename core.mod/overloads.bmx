' Numeric overloads preserve the familiar API; renderer geometry remains Float.

Rem
bbdoc: Draws a point using the current colour, blend mode and transform.
param: Horizontal drawing position before the active transforms.
param: Vertical drawing position before the active transforms.
End Rem
Function Plot(x:Double,y:Double)
	Plot(Float(x),Float(y))
End Function

Rem
bbdoc: Draws a filled rectangle using the current drawing state.
param: Horizontal drawing position before the active transforms.
param: Vertical drawing position before the active transforms.
param: Destination width in local drawing units.
param: Destination height in local drawing units.
End Rem
Function DrawRect(x:Double,y:Double,width:Double,height:Double)
	DrawRect(Float(x),Float(y),Float(width),Float(height))
End Function

Rem
bbdoc: Draws a line using the current colour, line width and transform.
param: Horizontal drawing position before the active transforms.
param: Vertical drawing position before the active transforms.
param: Horizontal coordinate of the second endpoint.
param: Vertical coordinate of the second endpoint.
param: Whether to include the line's final pixel.
End Rem
Function DrawLine(x:Double,y:Double,x2:Double,y2:Double,draw_last_pixel:Int = True)
	DrawLine(Float(x),Float(y),Float(x2),Float(y2),draw_last_pixel)
End Function

Rem
bbdoc: Draws a filled ellipse inside the supplied rectangle.
param: Horizontal drawing position before the active transforms.
param: Vertical drawing position before the active transforms.
param: Destination width in local drawing units.
param: Destination height in local drawing units.
End Rem
Function DrawOval(x:Double,y:Double,width:Double,height:Double)
	DrawOval(Float(x),Float(y),Float(width),Float(height))
End Function

Rem
bbdoc: Draws one image frame using its handle and the current drawing state.
param: Image to operate on.
param: Horizontal drawing position before the active transforms.
param: Vertical drawing position before the active transforms.
param: Zero-based image frame index.
End Rem
Function DrawImage(image:TImage,x:Double,y:Double,frame:Int=0)
	DrawImage(image,Float(x),Float(y),frame)
End Function

Rem
bbdoc: Draws an image frame scaled to the supplied destination size.
param: Image to operate on.
param: Horizontal drawing position before the active transforms.
param: Vertical drawing position before the active transforms.
param: Destination width in local drawing units.
param: Destination height in local drawing units.
param: Zero-based image frame index.
End Rem
Function DrawImageRect(image:TImage,x:Double,y:Double,width:Double,height:Double,frame:Int=0)
	DrawImageRect(image,Float(x),Float(y),Float(width),Float(height),frame)
End Function

Rem
bbdoc: Draws a rectangular part of an image into a destination rectangle.
param: Image to operate on.
param: Horizontal drawing position before the active transforms.
param: Vertical drawing position before the active transforms.
param: Destination width in local drawing units.
param: Destination height in local drawing units.
param: Left edge of the source rectangle in image pixels.
param: Top edge of the source rectangle in image pixels.
param: Width of the source rectangle in image pixels.
param: Height of the source rectangle in image pixels.
param: Horizontal handle offset within the source rectangle.
param: Vertical handle offset within the source rectangle.
param: Zero-based image frame index.
End Rem
Function DrawSubImageRect(image:TImage,x:Double,y:Double,width:Double,height:Double,sx:Double,sy:Double,swidth:Double,sheight:Double,hx:Double=0,hy:Double=0,frame:Int=0)
	DrawSubImageRect(image,Float(x),Float(y),Float(width),Float(height),Float(sx),Float(sy),Float(swidth),Float(sheight),Float(hx),Float(hy),frame)
End Function

Rem
bbdoc: Sets the opacity multiplier used for subsequent drawing.
param: Opacity multiplier, from 0.0 to 1.0.
End Rem
Function SetAlpha(alpha:Double)
	SetAlpha(Float(alpha))
End Function

Rem
bbdoc: Sets the width used to draw lines.
param: Positive line width in logical drawing units.
End Rem
Function SetLineWidth(width:Double)
	SetLineWidth(Float(width))
End Function

Rem
bbdoc: Sets the drawing origin offset.
param: Horizontal drawing-origin offset.
param: Vertical drawing-origin offset.
End Rem
Function SetOrigin(x:Double,y:Double)
	SetOrigin(Float(x),Float(y))
End Function

Rem
bbdoc: Sets the local handle used for drawing primitives.
param: Horizontal local handle offset.
param: Vertical local handle offset.
End Rem
Function SetHandle(x:Double,y:Double)
	SetHandle(Float(x),Float(y))
End Function

Rem
bbdoc: Sets the object rotation in degrees.
param: Rotation in degrees.
End Rem
Function SetRotation(rotation:Double)
	SetRotation(Float(rotation))
End Function

Rem
bbdoc: Sets the horizontal and vertical object scale factors.
param: Horizontal object scale factor.
param: Vertical object scale factor.
End Rem
Function SetScale(x:Double,y:Double)
	SetScale(Float(x),Float(y))
End Function

Rem
bbdoc: Sets object rotation and scale together.
param: Rotation in degrees.
param: Horizontal scale factor.
param: Vertical scale factor.
End Rem
Function SetTransform(rotation:Double,scale_x:Double=1,scale_y:Double=1)
	SetTransform(Float(rotation),Float(scale_x),Float(scale_y))
End Function

Rem
bbdoc: Sets an image's drawing handle in logical image coordinates.
param: Image to operate on.
param: Horizontal local handle offset.
param: Vertical local handle offset.
End Rem
Function SetImageHandle(image:TImage,x:Double,y:Double)
	SetImageHandle(image,Float(x),Float(y))
End Function

Rem
bbdoc: Draws text with the current image font and drawing state.
param: Text to lay out, measure or draw.
param: Horizontal drawing position before the active transforms.
param: Vertical drawing position before the active transforms.
End Rem
Function DrawText(text:String,x:Double,y:Double)
	DrawText(text,Float(x),Float(y))
End Function

Rem
bbdoc: Sets logical drawing dimensions and how they fit the current destination.
param: Positive virtual drawing width.
param: Positive virtual drawing height.
param: VIRTUAL_STRETCH, VIRTUAL_LETTERBOX, VIRTUAL_INTEGER or VIRTUAL_NATIVE.
End Rem
Function SetVirtualResolution(width:Double,height:Double,presentation:Int=VIRTUAL_STRETCH)
	SetVirtualResolution(Float(width),Float(height),presentation)
End Function

Rem
bbdoc: Moves the system pointer to the supplied virtual position.
param: Horizontal virtual screen coordinate.
param: Vertical virtual screen coordinate.
End Rem
Function MoveVirtualMouse(x:Double,y:Double)
	MoveVirtualMouse(Float(x),Float(y))
End Function

Rem
bbdoc: Repeats an image frame across the viewport with object rotation and scale reset.
param: Image to operate on.
param: Horizontal coordinate.
param: Vertical coordinate.
param: Zero-based image frame index.
End Rem
Function TileImage(image:TImage,x:Double,y:Double=0,frame:Int=0)
	TileImage(image,Float(x),Float(y),frame)
End Function
