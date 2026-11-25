Rem
bbdoc: Read-only cumulative lighting work counters and a current shadow-storage estimate.
about: Use TMax2DLighting or TSceneLighting ResetStats to begin a measurement interval. CopyStats reuses caller-owned storage; CaptureStats allocates a snapshot. Counters include partial work on failures; successful passes and rebuilds count only on completion. These are CPU-side work counts, not GPU timings or backend draw calls.
End Rem
Type TMax2DLightingStats
	Internal
	Field wholeMeshDraws:Long
	Field sectionMeshDraws:Long
	Field triangleMeshDraws:Long
	Field mapUploads:Long, mapHits:Long, mapBytes:Long
	Field groupedLightContributions:Long, groupSupportChecks:Long, groupSupportRejections:Long
	Field maximumGroupSize:Int
	Field groupedPasses:Long
	Field lightContributions:Long
	Field pairedPasses:Long
	Field ambientPasses:Long, combinedAmbientPasses:Long
	Field receiverDraws:Long
	Field selectionNodeTests:Long, selectionRebuilds:Long, spatialRejects:Long
	Field lightTests:Long
	Field excludedLights:Long
	Field boundsRejects:Long
	Field lightPasses:Long
	Field shadowRequests:Long
	Field shadowCacheHits:Long
	Field shadowRebuilds:Long
	Field occluderTests:Long
	Field casters:Long
	Field filterPasses:Long
	Field shadowBytes:Long
	Method Reset()
		wholeMeshDraws = 0
		sectionMeshDraws = 0
		triangleMeshDraws = 0
		mapUploads = 0
		mapHits = 0
		mapBytes = 0
		groupedLightContributions = 0
		groupSupportChecks = 0
		groupSupportRejections = 0
		maximumGroupSize = 0
		groupedPasses = 0
		lightContributions = 0
		pairedPasses = 0
		ambientPasses = 0
		combinedAmbientPasses = 0
		receiverDraws = 0
		selectionNodeTests = 0
		selectionRebuilds = 0
		spatialRejects = 0
		lightTests = 0
		excludedLights = 0
		boundsRejects = 0
		lightPasses = 0
		shadowRequests = 0
		shadowCacheHits = 0
		shadowRebuilds = 0
		occluderTests = 0
		casters = 0
		filterPasses = 0
		shadowBytes = 0
	End Method

	Method CopyTo(output:TMax2DLightingStats)
		output.wholeMeshDraws = wholeMeshDraws
		output.sectionMeshDraws = sectionMeshDraws
		output.triangleMeshDraws = triangleMeshDraws
		output.mapUploads = mapUploads
		output.mapHits = mapHits
		output.mapBytes = mapBytes
		output.groupedLightContributions = groupedLightContributions
		output.maximumGroupSize = maximumGroupSize
		output.groupSupportChecks = groupSupportChecks
		output.groupSupportRejections = groupSupportRejections
		output.groupedPasses = groupedPasses
		output.lightContributions = lightContributions
		output.pairedPasses = pairedPasses
		output.ambientPasses = ambientPasses
		output.combinedAmbientPasses = combinedAmbientPasses
		output.receiverDraws = receiverDraws
		output.selectionNodeTests = selectionNodeTests
		output.selectionRebuilds = selectionRebuilds
		output.spatialRejects = spatialRejects
		output.lightTests = lightTests
		output.excludedLights = excludedLights
		output.boundsRejects = boundsRejects
		output.lightPasses = lightPasses
		output.shadowRequests = shadowRequests
		output.shadowCacheHits = shadowCacheHits
		output.shadowRebuilds = shadowRebuilds
		output.occluderTests = occluderTests
		output.casters = casters
		output.filterPasses = filterPasses
		output.shadowBytes = shadowBytes
	End Method

	Public
	Rem
	bbdoc: Counts lit meshes split into individual triangle receivers.
	returns: Total input meshes using this path since the last reset.
	End Rem
	Method TriangleMeshDraws:Long()
		Return triangleMeshDraws
	End Method
	Rem
	bbdoc: Counts lit meshes split into affine receiver sections.
	returns: Total input meshes using this path since the last reset.
	End Rem
	Method SectionMeshDraws:Long()
		Return sectionMeshDraws
	End Method
	Rem
	bbdoc: Counts lit meshes drawn as one receiver.
	returns: Total input meshes using this path since the last reset.
	End Rem
	Method WholeMeshDraws:Long()
		Return wholeMeshDraws
	End Method
	Rem
	bbdoc: Returns completed ambient compositions, including those combined with direct lighting.
	returns: Completed ambient compositions, including those combined with direct lighting.
	End Rem
	Method AmbientPasses:Long()
		Return ambientPasses
	End Method
	Rem
	bbdoc: Returns ambient compositions included in the first direct-light group.
	returns: Ambient compositions included in the first direct-light group.
	about: Total lighting submissions equal AmbientPasses plus LightPasses minus CombinedAmbientPasses. Flattened Update never combines ambient.
	End Rem
	Method CombinedAmbientPasses:Long()
		Return combinedAmbientPasses
	End Method
	Rem
	bbdoc: Returns completed copies into retained renderer map storage, including partial work before a failed draw.
	returns: Completed copies into retained renderer map storage, including partial work before a failed draw.
	End Rem
	Method MapUploads:Long()
		Return mapUploads
	End Method
	Rem
	bbdoc: Returns unchanged map lookups served by retained renderer storage.
	returns: Unchanged map lookups served by retained renderer storage.
	End Rem
	Method MapCacheHits:Long()
		Return mapHits
	End Method
	Rem
	bbdoc: Returns estimated retained renderer map texture bytes, separate from shadow masks.
	returns: Estimated retained renderer map texture bytes, separate from shadow masks.
	End Rem
	Method RetainedMapBytes:Long()
		Return mapBytes
	End Method
	Rem
	bbdoc: Returns completed direct-light submissions through a grouped renderer, included in LightPasses.
	returns: Completed direct-light submissions through a grouped renderer, included in LightPasses.
	End Rem
	Method GroupedPasses:Long()
		Return groupedPasses
	End Method
	Rem
	bbdoc: Returns completed direct-light contributions submitted through grouped renderers.
	returns: Completed direct-light contributions submitted through grouped renderers.
	about: Includes native and paired compatibility groups, including single-light groups. Divide by GroupedPasses, when nonzero, to obtain the average lights per completed group.
	End Rem
	Method GroupedLightContributions:Long()
		Return groupedLightContributions
	End Method
	Rem
	bbdoc: Returns completed ordinary direct-light passes, excluding grouped renderers.
	returns: Completed ordinary direct-light passes, excluding grouped renderers.
	about: Equals LightPasses minus GroupedPasses. Includes disabled batching, unsupported groups and flattened Update
	 this is not solely a fallback counter.
	End Rem
	Method OrdinaryLightPasses:Long()
		Return lightPasses - groupedPasses
	End Method
	Rem
	bbdoc: Returns the largest successfully submitted group since ResetStats, or zero when none completed.
	returns: The largest successfully submitted group since ResetStats, or zero when none completed.
	about: This is observed use, not the renderer's supported capacity or the requested batch limit.
	End Rem
	Method MaximumGroupSize:Int()
		Return maximumGroupSize
	End Method
	Rem
	bbdoc: Returns calls to grouped renderers' Supports methods, including prefix retries and paired compatibility.
	returns: Calls to grouped renderers' Supports methods, including prefix retries and paired compatibility.
	about: Capability exclusions before Supports are not counted. A call that throws counts as a check, but not as a rejection.
	End Rem
	Method GroupSupportChecks:Long()
		Return groupSupportChecks
	End Method
	Rem
	bbdoc: Returns Supports calls that returned False, included in GroupSupportChecks.
	returns: Supports calls that returned False, included in GroupSupportChecks.
	about: Rejected prefixes may be followed by a successful smaller group. These are negotiation costs, not failed receiver draws or missing light contributions.
	End Rem
	Method GroupSupportRejections:Long()
		Return groupSupportRejections
	End Method
	Rem
	bbdoc: Returns the number of direct-light contributions drawn, independently of group size.
	returns: The number of direct-light contributions drawn, independently of group size.
	about: Ambient is excluded. An ordinary pass adds one; a grouped pass adds its light count. Includes flattened updates.
	End Rem
	Method LightContributions:Long()
		Return lightContributions
	End Method
	Rem
	bbdoc: Returns completed two-light passes, included in LightPasses.
	returns: Completed two-light passes, included in LightPasses.
	End Rem
	Method PairedPasses:Long()
		Return pairedPasses
	End Method
	Rem
	bbdoc: Returns lit receiver draw attempts, including flattened updates; unlit bypasses are excluded.
	returns: Lit receiver draw attempts, including flattened updates; unlit bypasses are excluded.
	End Rem
	Method ReceiverDraws:Long()
		Return receiverDraws
	End Method
	Rem
	bbdoc: Returns hierarchy bounds tested during spatial receiver selection, including internal nodes.
	returns: Hierarchy bounds tested during spatial receiver selection, including internal nodes.
	End Rem
	Method SelectionNodeTests:Long()
		Return selectionNodeTests
	End Method
	Rem
	bbdoc: Returns completed lazy hierarchy rebuilds after light geometry, kind or count edits.
	returns: Completed lazy hierarchy rebuilds after light geometry, kind or count edits.
	End Rem
	Method SelectionRebuilds:Long()
		Return selectionRebuilds
	End Method
	Rem
	bbdoc: Returns slots skipped by spatial bounds before intensity and receiver-mask tests.
	returns: Slots skipped by spatial bounds before intensity and receiver-mask tests.
	about: Separate from BoundsRejects. Includes any disabled or masked slots removed by the hierarchy; those slots do not increment LightTests or ExcludedLights.
	End Rem
	Method SpatialRejects:Long()
		Return spatialRejects
	End Method
	Rem
	bbdoc: Returns light slots examined across receiver draws.
	returns: Light slots examined across receiver draws.
	End Rem
	Method LightTests:Long()
		Return lightTests
	End Method
	Rem
	bbdoc: Returns slots skipped because intensity is zero or receiver masks do not match.
	returns: Slots skipped because intensity is zero or receiver masks do not match.
	End Rem
	Method ExcludedLights:Long()
		Return excludedLights
	End Method
	Rem
	bbdoc: Returns point lights skipped because their bounds do not intersect the receiver.
	returns: Point lights skipped because their bounds do not intersect the receiver.
	End Rem
	Method BoundsRejects:Long()
		Return boundsRejects
	End Method
	Rem
	bbdoc: Returns completed direct-light image passes; excludes ambient and shadow construction.
	returns: Completed direct-light image passes; excludes ambient and shadow construction.
	End Rem
	Method LightPasses:Long()
		Return lightPasses
	End Method
	Rem
	bbdoc: Returns shadow mask requests for selected lights.
	returns: Shadow mask requests for selected lights.
	End Rem
	Method ShadowRequests:Long()
		Return shadowRequests
	End Method
	Rem
	bbdoc: Returns requests served by an unchanged retained mask.
	returns: Requests served by an unchanged retained mask.
	End Rem
	Method ShadowCacheHits:Long()
		Return shadowCacheHits
	End Method
	Rem
	bbdoc: Returns successfully rebuilt shadow masks.
	returns: Successfully rebuilt shadow masks.
	End Rem
	Method ShadowRebuilds:Long()
		Return shadowRebuilds
	End Method
	Rem
	bbdoc: Returns registered polygons examined during mask rebuilds, including disabled and masked polygons.
	returns: Registered polygons examined during mask rebuilds, including disabled and masked polygons.
	End Rem
	Method OccluderTests:Long()
		Return occluderTests
	End Method
	Rem
	bbdoc: Returns enabled matching nondegenerate polygons processed during mask rebuilds.
	returns: Enabled matching nondegenerate polygons processed during mask rebuilds.
	End Rem
	Method Casters:Long()
		Return casters
	End Method
	Rem
	bbdoc: Returns completed blur passes; two per filtered mask rebuild, excluding pattern composition.
	returns: Completed blur passes; two per filtered mask rebuild, excluding pattern composition.
	End Rem
	Method FilterPasses:Long()
		Return filterPasses
	End Method
	Rem
	bbdoc: Returns estimated retained shadow texture bytes when copied; excludes driver overhead, source textures and flattened output.
	returns: Estimated retained shadow texture bytes when copied; excludes driver overhead, source textures and flattened output.
	End Rem
	Method RetainedShadowBytes:Long()
		Return shadowBytes
	End Method
End Type
