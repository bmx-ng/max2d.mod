<?xml version="1.0" encoding="UTF-8"?>
<tileset name="Demo terrain" tilewidth="32" tileheight="32" columns="5" tilecount="5">
	<image source="terrain.png" />
	<tile id="0">
		<properties>
			<property name="terrain" value="grass" />
		</properties>
	</tile>
	<tile id="1">
		<properties>
			<property name="terrain" value="path" />
		</properties>
	</tile>
	<tile id="2">
		<properties>
			<property name="terrain" value="water" />
			<property name="swimmable" type="bool" value="true" />
		</properties>
		<animation>
			<frame tileid="2" duration="500" />
			<frame tileid="3" duration="500" />
		</animation>
	</tile>
	<tile id="4">
		<properties>
			<property name="terrain" value="wall" />
			<property name="solid" type="bool" value="true" />
		</properties>
	</tile>
</tileset>
