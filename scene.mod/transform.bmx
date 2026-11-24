Rem
bbdoc: Detached affine-transform snapshot with double-precision coefficients.
about: x maps to xx*x+xy*y+tx; y maps to yx*x+yy*y+ty. Editing a snapshot does not change its source node. Use CopyLocalTransform or CopyWorldTransform to reuse an existing snapshot without allocating.
End Rem
Type TSceneTransform
	Rem
	bbdoc: Horizontal contribution of local x.
	End Rem
	Field xx:Double = 1
	Rem
	bbdoc: Horizontal contribution of local y.
	End Rem
	Field xy:Double
	Rem
	bbdoc: Vertical contribution of local x.
	End Rem
	Field yx:Double
	Rem
	bbdoc: Vertical contribution of local y.
	End Rem
	Field yy:Double = 1
	Rem
	bbdoc: Horizontal translation.
	End Rem
	Field tx:Double
	Rem
	bbdoc: Vertical translation.
	End Rem
	Field ty:Double

	Rem
	bbdoc: Creates a finite detached matrix; the defaults are identity.
	param: Coefficient of X in the transformed X coordinate.
	param: Coefficient of Y in the transformed X coordinate.
	param: Coefficient of X in the transformed Y coordinate.
	param: Coefficient of Y in the transformed Y coordinate.
	param: Horizontal affine translation.
	param: Vertical affine translation.
	returns: A new #TSceneTransform instance configured with the supplied settings.
	End Rem
	Function Create:TSceneTransform(xx:Double = 1, xy:Double = 0, yx:Double = 0, yy:Double = 1, tx:Double = 0, ty:Double = 0)
		SceneCheckFinite(xx)
		SceneCheckFinite(xy)
		SceneCheckFinite(yx)
		SceneCheckFinite(yy)
		SceneCheckFinite(tx)
		SceneCheckFinite(ty)
		Local result:TSceneTransform = New TSceneTransform
		result.xx = xx
		result.xy = xy
		result.yx = yx
		result.yy = yy
		result.tx = tx
		result.ty = ty
		Return result
	End Function
End Type

Private

Function SceneCheckFinite(value:Double)
	If IsNan(value) Or IsInf(value) Then
		Throw "Max2D Scene: transform values must be finite"
	End If
End Function

' Inline numeric storage; no matrix object is created when a node moves.
Struct SSceneMatrix
	Field xx:Double, xy:Double, yx:Double, yy:Double, tx:Double, ty:Double

	Method Validate()
		SceneCheckFinite(xx)
		SceneCheckFinite(xy)
		SceneCheckFinite(yx)
		SceneCheckFinite(yy)
		SceneCheckFinite(tx)
		SceneCheckFinite(ty)
	End Method

	Method CopyTo(output:TSceneTransform)
		If Not output Then
			Throw "Max2D Scene: transform destination is null"
		End If

		output.xx = xx
		output.xy = xy
		output.yx = yx
		output.yy = yy
		output.tx = tx
		output.ty = ty
	End Method

	Method Product(a:SSceneMatrix, b:SSceneMatrix)
		xx = a.xx * b.xx + a.xy * b.yx
		xy = a.xx * b.xy + a.xy * b.yy
		yx = a.yx * b.xx + a.yy * b.yx
		yy = a.yx * b.xy + a.yy * b.yy
		tx = a.xx * b.tx + a.xy * b.ty + a.tx
		ty = a.yx * b.tx + a.yy * b.ty + a.ty
		Validate()
	End Method

	Method Inverse:Int(value:SSceneMatrix)
		Local determinant:Double = value.xx * value.yy - value.xy * value.yx
		If determinant = 0 Or IsNan(determinant) Or IsInf(determinant) Then
			Return False
		End If

		xx = value.yy / determinant
		xy = -value.xy / determinant
		yx = -value.yx / determinant
		yy = value.xx / determinant
		tx = -(xx * value.tx + xy * value.ty)
		ty = -(yx * value.tx + yy * value.ty)
		If IsNan(xx) Or IsInf(xx) Or IsNan(xy) Or IsInf(xy) Or IsNan(yx) Or IsInf(yx) Or IsNan(yy) Or IsInf(yy) Or IsNan(tx) Or IsInf(tx) Or IsNan(ty) Or IsInf(ty) Then
			Return False
		End If

		Return True
	End Method
End Struct

Public
