# Hover, keyboard focus and key routing

These features build on [pointer routing](pointer.md). Applications still own
native input, key-repeat policy, text composition and the main loop. No default
click-to-focus or Tab behaviour is installed by the scene itself.

## Opt a pointer into hover

```blitzmax
scene.SetPointerHover(0, 0) ' The application's mouse device/pointer pair.
scene.DispatchPointer(EScenePointerKind.Move, 0, 0, virtualX, virtualY)
```

Hover is disabled by default. A touch pointer therefore produces no Enter/Leave
unless its adapter explicitly opts it in. Each enabled pair remembers its latest
position, supplied through DispatchPointer. Enabling hover waits for a new input
position rather than assuming the pointer starts at the origin.

The topmost picked node receives `OnPointer` with Enter or Leave. These are
target-only notifications: they do not visit ancestor capture/bubble hooks, and
an ancestor does not automatically become hovered when its child does. Use the
normal Move path when an ancestor needs pointer tracking. Hover uses the same
input clip, layer clips, hit shapes and stable drawing order as picking.

Update reconciles stationary pointers after scene changes. Moving a node beneath
a stationary pointer, hiding a node or changing sibling order can send Leave and
Enter without a new native movement event. Reconciliation also runs at input and
structural-operation boundaries. A hover callback's own visual changes are
observed at a subsequent boundary; avoid changing hit geometry on Enter/Leave
in ways that continually move the target away from and back under the pointer.

Hover is suspended while that pair has pointer capture. The existing hovered
node remains recorded during the drag; after capture ends, the current position
is picked again. Detachment or destruction sends Leave before exit. Disabling
hover with `SetPointerHover(device, pointer, False)` sends Leave and forgets its
position. `CancelInput` also sends Leave and forgets positions, while preserving
which pairs are configured for hover. New input can resume hover after focus loss.

A native Cancel forgets that pair's position. Leave uses the last available
virtual position; unlike Cancel, it can be converted with PositionIn while the
node is still attached. Throwing from a hover notification propagates the error
after cleanup; the transition is recorded so the same Enter is not repeatedly
sent just because its callback threw.

## Disable an input branch

```blitzmax
panel.SetInputEnabled(False)
```

`SetInputEnabled` is inherited through both spatial and non-spatial parents.
It prevents picking and keyboard focus within the branch, without changing
rendering or update callbacks. Existing captures, hover and focus are reconciled
at the next update/input boundary. Remaining normal event visits skip disabled
branches; cancellation, capture-loss and leave notifications still clean up
interaction state.

This differs from `SetInteractive(False)`, which disables only that node as a
pointer hit target, leaving descendants interactive. Keyboard focus is also
independent of SetInteractive: a control can be keyboard-only.

## Focus a control

```blitzmax
button.SetFocusable(True)
button.SetFocusOrder(10)
scene.SetFocus(button)
```

Nodes must opt into focus, be attached beneath a layer, have enabled input and
be visible with nonzero inherited opacity and an invertible screen mapping.
SetFocus rejects ineligible or foreign-scene targets. Input clipping and pointer
hit rectangles do not constrain keyboard focus.

`scene.FocusedNode()` returns the current node or Null. SetFocus(Null) clears it.
Focus changes invoke OnFocusLost on the former node, then OnFocusGained on the new
node. The new target is rechecked after the lost callback, since that callback
may have hidden or scheduled destruction of it. Nested focus changes inside
these two notifications are rejected. Use them for visual and interaction state;
request further navigation outside the notification.

SetFocus may be called from a pointer or key handler. For click-to-focus, call
`Scene().SetFocus(Self)` in the control's Down callback. The scene does not assume
that all pointer presses should move keyboard focus.

Hidden, zero-opacity, disabled or singular branches lose focus at the next
update/input boundary. Disabling SetFocusable also clears focus at that boundary.
Detachment and destruction send OnFocusLost before OnExitScene. A same-scene
reparent preserves focus if the node remains eligible. CancelInput clears focus
alongside pointer state. Notification failures do not prevent structural cleanup;
the first error is rethrown after cleanup.

## Navigate in a predictable order

```blitzmax
scene.FocusNext()       ' Forward, wrapping after the final candidate.
scene.FocusNext(True)   ' Backward, wrapping before the first candidate.
```

FocusNext requires an idle scene. Candidates are ordered by ascending
SetFocusOrder, with tree pre-order insertion as the tie-breaker. Drawing z-indices
and sortable-children settings do not change keyboard navigation. With no current
focus, forward starts at the first eligible node and reverse at the last. With
no eligible candidate, focus is cleared.

Applications can implement Tab as a fallback after DispatchKey:

```blitzmax
Local handled:Int = scene.DispatchKey(ESceneKeyKind.Down, key, modifiers, repeated)
If Not handled And key = KEY_TAB And Not repeated Then
    scene.FocusNext((modifiers & SCENE_MOD_SHIFT) <> 0)
End If
```

Use this outside a key callback; public traversal methods reject nested traversal.
Widgets can consume Tab when they need it themselves. Navigation groups, modal
focus scopes and composed text are separate application concerns.

## Deliver physical keys

```blitzmax
scene.DispatchKey(ESceneKeyKind.Down, key, modifiers, repeated)
scene.DispatchKey(ESceneKeyKind.Up, key, modifiers)
```

The adapter supplies the physical key code, whether Down is a repeat, and a mask
of `SCENE_MOD_SHIFT`, `SCENE_MOD_CONTROL`, `SCENE_MOD_ALT` and `SCENE_MOD_META`.
The scene forwards these values unchanged and does not poll, repeat or compose
keys. Each event goes to the focus that exists at dispatch start; Up is not tied
to an earlier Down target, so controls must clear held-key state on OnFocusLost.

Key delivery uses `OnKeyCapture` on ancestors from root to parent, `OnKey` on the
focused target, then `OnKeyBubble` from parent to root. Handle stops propagation
and returns True from DispatchKey. StopPropagation stops visits without marking
the key handled. No focus returns False.

The path remains fixed for that event even if a handler calls SetFocus.
Pending-destruction or input-disabled nodes are skipped. Structural changes queue
until dispatch completes. Handler errors abort that key path, commit queued
cleanup and then rethrow; a later dispatch can proceed normally.

TSceneKeyEvent is borrowed for one callback. Copy creates an allocated,
read-only TSceneKeySnapshot with Key, Kind, Modifiers, Repeated, Target and
CurrentTarget accessors. Snapshots retain node references but have no handling
methods. Store scalar values when retaining nodes is unnecessary.

## Allocation and examples

The scene retains key paths, navigation candidates and hover records. Reserve
prepares traversal capacity; enabling hover may allocate records initially.
TrimStorage releases unused records while preserving enabled hover pairs and
active focus. Warm key routing, unchanged hover reconciliation and focus
navigation allocate no framework objects. Application callbacks and Copy may
allocate.

[scene_controls.bmx](../../examples/scene_controls.bmx) combines hover, dragging,
click-to-focus, Tab/Shift+Tab navigation, arrow-key movement and Space/Enter
activation. Its small polling adapter sends press/release transitions rather than
implementing native key repeat. The example keeps polling and fallback controls
outside scene callbacks.

[scene_interaction.bmx](../../tests/scene_interaction.bmx) covers stationary hover,
capture suspension, focus eligibility/navigation, key phases, borrowed data,
callback failures, structural cleanup and allocation after warmup.
