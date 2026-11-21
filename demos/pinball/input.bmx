' Rectangular menu/launcher hit areas reuse the joystick module's independent
' finger capture; flippers retain circular hit areas matching their artwork.
Type TPinRectButton Extends TVirtualButton
    Field halfWidth:Float, halfHeight:Float
    Method Contains:Int(x:Float, y:Float) Override
        Return Abs(x - centerX) <= halfWidth And Abs(y - centerY) <= halfHeight
    End Method
End Type

Type TPinControls Extends TVirtualJoystick
    Field suspended:Int
    Method New()
        For Local i:Int = 0 Until 5
            AddButton()
        Next

        buttons[2] = New TPinRectButton
        buttons[3] = New TPinRectButton
        buttons[4] = New TPinRectButton
        SetStickEnabled(False)
    End Method

    Method OnEvent(event:TEvent) Override
        Super.OnEvent(event)
        If event.id = EVENT_APPSUSPEND Then
            suspended = True
        End If
    End Method

    Method Layout(w:Int, h:Int)
        Local scale:Float = Min(Float(w) / 1000, Float(h) / 820), ox:Float = (w - 1000 * scale) / 2, oy:Float = (h - 820 * scale) / 2
        SetButton(0, ox + 180 * scale, oy + 776 * scale, 34 * scale)
        SetButton(1, ox + 405 * scale, oy + 776 * scale, 34 * scale)
        SetButton(2, ox + 745 * scale, oy + 640 * scale, 48 * scale)
        SetButton(3, ox + 745 * scale, oy + 747 * scale, 25 * scale)
        SetButton(4, ox + 884 * scale, oy + 313 * scale, 15 * scale)
        Local button:TPinRectButton = TPinRectButton(buttons[2])
        button.halfWidth = 175 * scale
        button.halfHeight = 50 * scale
        button = TPinRectButton(buttons[3])
        button.halfWidth = 175 * scale
        button.halfHeight = 25 * scale
        button = TPinRectButton(buttons[4])
        button.halfWidth = 41 * scale
        button.halfHeight = 13 * scale
    End Method
End Type
