Rem
bbdoc: Read-only scene render statistics; use CaptureStats or reuse an instance with CopyStats.
about: Counters describe the most recent Render attempt, including partial work on failure. Skipped subtrees count their root once, not all descendants. DrawVisits includes spatial groups with no drawing and is not a backend draw-call count.
End Rem
Type TSceneStats
	Internal
	Field visited:Long, drawVisits:Long, culled:Long, hidden:Long, clipped:Long
	Field boundsTests:Long, unknownBounds:Long, boundsRebuilds:Long, worldRebuilds:Long
	Field captures:Long, cacheHits:Long, stagePasses:Long
	Field storageRetained:Long, storagePeak:Long
	Field completed:Int
	Method Reset()
		storageRetained = 0
		storagePeak = 0
		captures = 0
		cacheHits = 0
		stagePasses = 0
		visited = 0
		drawVisits = 0
		culled = 0
		hidden = 0
		clipped = 0
		boundsTests = 0
		unknownBounds = 0
		boundsRebuilds = 0
		worldRebuilds = 0
		completed = False
	End Method

	Method CopyTo(output:TSceneStats)
		output.storageRetained = storageRetained
		output.storagePeak = storagePeak
		output.visited = visited
		output.drawVisits = drawVisits
		output.culled = culled
		output.hidden = hidden
		output.clipped = clipped
		output.boundsTests = boundsTests
		output.unknownBounds = unknownBounds
		output.boundsRebuilds = boundsRebuilds
		output.worldRebuilds = worldRebuilds
		output.completed = completed
		output.captures = captures
		output.cacheHits = cacheHits
		output.stagePasses = stagePasses
	End Method

	Public
	Rem
	bbdoc: Returns estimated registered texture bytes at the end of the most recent Render attempt.
	returns: Estimated registered texture bytes at the end of the most recent Render attempt.
	about: Includes hidden and detached groups. For current usage after release or destruction, query scene.RetainedStorageBytes instead.
	End Rem
	Method RetainedStorageBytes:Long()
		Return storageRetained
	End Method
	Rem
	bbdoc: Returns the highest accepted scene texture reservation during the most recent Render attempt.
	returns: The highest accepted scene texture reservation during the most recent Render attempt.
	about: Starts at retained usage on entry and includes old plus candidate buffers during replacement. An estimate, not measured driver memory; rejected requests do not increase it.
	End Rem
	Method PeakStorageBytes:Long()
		Return storagePeak
	End Method
	Rem
	bbdoc: Returns subtree captures performed by render groups during this render.
	returns: Subtree captures performed by render groups during this render.
	End Rem
	Method Captures:Long()
		Return captures
	End Method
	Rem
	bbdoc: Returns render groups that presented reusable output without recapturing.
	returns: Render groups that presented reusable output without recapturing.
	End Rem
	Method CacheHits:Long()
		Return cacheHits
	End Method
	Rem
	bbdoc: Returns completed effect-stage updates, not their internal GPU draw calls.
	returns: Completed effect-stage updates, not their internal GPU draw calls.
	End Rem
	Method StagePasses:Long()
		Return stagePasses
	End Method
	Rem
	bbdoc: Returns whether the most recent Render finished successfully, including state restoration.
	returns: Whether the most recent Render finished successfully, including state restoration.
	End Rem
	Method Completed:Int()
		Return completed
	End Method
	Rem
	bbdoc: Returns visited tree nodes, including roots, layers and skipped branch roots.
	returns: Visited tree nodes, including roots, layers and skipped branch roots.
	End Rem
	Method NodesVisited:Long()
		Return visited
	End Method
	Rem
	bbdoc: Returns spatial drawing-hook visits, including empty groups and a hook that threw.
	returns: Spatial drawing-hook visits, including empty groups and a hook that threw.
	End Rem
	Method DrawVisits:Long()
		Return drawVisits
	End Method
	Rem
	bbdoc: Returns branch roots skipped because known bounds were outside the effective clip.
	returns: Branch roots skipped because known bounds were outside the effective clip.
	End Rem
	Method CulledSubtrees:Long()
		Return culled
	End Method
	Rem
	bbdoc: Returns branch roots skipped because their own visibility or opacity disabled rendering.
	returns: Branch roots skipped because their own visibility or opacity disabled rendering.
	End Rem
	Method HiddenSubtrees:Long()
		Return hidden
	End Method
	Rem
	bbdoc: Returns branch roots skipped by an empty effective clip when culling is enabled.
	returns: Branch roots skipped by an empty effective clip when culling is enabled.
	End Rem
	Method ClippedSubtrees:Long()
		Return clipped
	End Method
	Rem
	bbdoc: Returns aggregate bounds tests made for culling.
	returns: Aggregate bounds tests made for culling.
	End Rem
	Method BoundsTests:Long()
		Return boundsTests
	End Method
	Rem
	bbdoc: Returns tests whose unknown bounds prevented a bounds-based skip.
	returns: Tests whose unknown bounds prevented a bounds-based skip.
	End Rem
	Method UnknownBounds:Long()
		Return unknownBounds
	End Method
	Rem
	bbdoc: Returns successfully rebuilt local aggregate bounds caches during rendering.
	returns: Successfully rebuilt local aggregate bounds caches during rendering.
	End Rem
	Method BoundsRebuilds:Long()
		Return boundsRebuilds
	End Method
	Rem
	bbdoc: Returns successfully rebuilt world matrices during rendering.
	returns: Successfully rebuilt world matrices during rendering.
	End Rem
	Method WorldRebuilds:Long()
		Return worldRebuilds
	End Method
End Type

Private

Function SceneCullBranch:Int(scene:TScene, node:TSceneNode2D, matrix:SSceneMatrix, x:Int, y:Int, w:Int, h:Int)
	scene.renderStats.boundsTests :+ 1
	sceneBoundsDepth :+ 1
	Try
		node.EnsureBounds()
	Finally
		sceneBoundsDepth :- 1
	End Try

	Local bounds:SSceneBounds = node.outputBounds
	If Not bounds.known Then
		scene.renderStats.unknownBounds :+ 1
		Return False
	End If
	' Empty and collapsed bounds cannot safely describe rasterized lines or points.
	If Not bounds.hasArea Or Not bounds.cullSafe Then
		Return False
	End If

	Local screen:SSceneBounds = bounds.Transformed(matrix)
	' Rendering uses Float coefficients. Leave a conservative uncertainty band at
	' clip edges, and avoid rejecting geometry whose numerical scale is extreme.
	Local extent:Double = Max(Max(Abs(bounds.left), Abs(bounds.right)), Max(Abs(bounds.top), Abs(bounds.bottom)))
	Local magnitude:Double = Abs(matrix.tx) + Abs(matrix.ty) + (Abs(matrix.xx) + Abs(matrix.xy) + Abs(matrix.yx) + Abs(matrix.yy)) * extent
	If IsNan(magnitude) Or IsInf(magnitude) Or magnitude > 10000000 Then
		Return False
	End If

	Local margin:Double = 1 + magnitude * 0.00001
	Return screen.right < Double(x) - margin Or screen.bottom < Double(y) - margin Or screen.left > Double(x) + w + margin Or screen.top > Double(y) + h + margin
End Function

Public
