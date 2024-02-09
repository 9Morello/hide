package hrt.prefab;

@:access(h3d.prim.HMDModel)
class BlendedPrimitive extends h3d.prim.HMDModel {
	public var weights : Array<Float> = [];
	public var index : Int;
	public var amount : Float;

	public function new(original : h3d.scene.Object) {
		var originalPrim = getPrim(original);
		super(originalPrim.data, originalPrim.dataPosition, originalPrim.lib);
		if ( originalPrim.data.vertexFormat.hasLowPrecision )
			throw "Blend shape doesn't support low precision";
	}

	public function update() {
		dispose();
	}

	function getPrim(o : h3d.scene.Object) {
		var originalMesh = Std.downcast(o, h3d.scene.Mesh);
		if ( originalMesh == null )
			throw "Should create Blend shape with mesh";
		var prim = Std.downcast(originalMesh.primitive, h3d.prim.HMDModel);
		if ( prim == null )
			throw "Can't create Blend shape if primitive is not an HMDModel";
		return prim;
	}

	override function alloc( engine : h3d.Engine ) {
		dispose();

		var is32 = data.vertexCount > 0x10000;
		var vertexFormat = data.vertexFormat;
		buffer = new h3d.Buffer(data.vertexCount, vertexFormat);

		var size = data.vertexCount * vertexFormat.strideBytes;
		var originalBytes = haxe.io.Bytes.alloc(size);
		lib.resource.entry.readBytes(originalBytes, 0, dataPosition + data.vertexPosition, size);

		var shapesBytes = [];
		var shapes = this.lib.header.shapes;
		var inputMapping : Array<Map<String, Int>> = [];
		weights = [];

		for ( s in 0...shapes.length ) {
			weights[s] = s == index ? amount : 0.0;

			var s = shapes[s];
			var size = s.vertexCount * s.vertexFormat.strideBytes;

			var vertexBytes = haxe.io.Bytes.alloc(size);
			lib.resource.entry.readBytes(vertexBytes, 0, dataPosition + s.vertexPosition, size);
			size = s.vertexCount << (is32 ? 2 : 1);

			var indexBytes = haxe.io.Bytes.alloc(size);
			lib.resource.entry.readBytes(indexBytes, 0, dataPosition + s.indexPosition, size);
			size = data.vertexCount << 2;

			var remapBytes = haxe.io.Bytes.alloc(size);
			lib.resource.entry.readBytes(remapBytes, 0, dataPosition + s.remapPosition, size);
			shapesBytes.push({ vertexBytes : vertexBytes, indexBytes : indexBytes, remapBytes : remapBytes});

			inputMapping.push(new Map());
		}

		// We want to remap inputs since we can get different inputs in blendshapes and
		// from original file
		for ( input in vertexFormat.getInputs() ) {
			for ( s in 0...shapes.length ) {
				var offset = 0;
				for ( i in shapes[s].vertexFormat.getInputs() ) {
					if ( i.name == input.name )
						inputMapping[s].set(i.name, offset);
					offset += i.type.getSize();
				}
			}
		}

		var flagOffset = 31;
		var bytes = haxe.io.Bytes.alloc(originalBytes.length);
		bytes.blit(0, originalBytes, 0, originalBytes.length);

		// Apply blendshapes offsets to original vertex
		for (sIdx in 0...shapes.length) {
			if (sIdx != index)
				continue;

			var sp = shapesBytes[sIdx];
			var offsetIdx = 0;
			var idx = 0;

			while (offsetIdx < shapes[sIdx].indexCount) {
				var affectedVId = sp.remapBytes.getInt32(idx << 2);

				var reachEnd = false;
				while (!reachEnd) {
					reachEnd = affectedVId >> flagOffset != 0;
					if (reachEnd)
						affectedVId = affectedVId ^ (1 << flagOffset);

					var inputIdx = 0;
					var offsetInput = 0;
					for (input in shapes[sIdx].vertexFormat.getInputs()) {
						for (sizeIdx in 0...input.type.getSize()) {
							var original = originalBytes.getFloat(affectedVId * vertexFormat.stride + inputMapping[sIdx][input.name] + sizeIdx << 2);
							var offset = sp.vertexBytes.getFloat(offsetIdx * shapes[sIdx].vertexFormat.stride + offsetInput + sizeIdx << 2);

							var res = hxd.Math.lerp(original, original + offset, weights[sIdx]);
							bytes.setFloat(affectedVId * vertexFormat.stride + inputMapping[sIdx][input.name] + sizeIdx << 2, res);

						}

						offsetInput += input.type.getSize();
						inputIdx++;
					}

					idx++;

					if (idx < data.vertexCount)
						affectedVId = sp.remapBytes.getInt32(idx << 2);
				}

				offsetIdx++;
			}
		}

		// Send bytes to buffer for rendering
		buffer.uploadBytes(bytes, 0, data.vertexCount);
		indexCount = 0;
		indexesTriPos = [];
		for( n in data.indexCounts ) {
			indexesTriPos.push(Std.int(indexCount/3));
			indexCount += n;
		}

		indexes = new h3d.Indexes(indexCount, is32);
		var size = (is32 ? 4 : 2) * indexCount;
		var bytes = lib.resource.entry.fetchBytes(dataPosition + data.indexPosition, size);
		indexes.uploadBytes(bytes, 0, indexCount);
	}

	override function getDataBuffers(fmt, ?defaults, ?material) {
		throw "";
		return null;
	}
}

class BlendShape extends hrt.prefab.Model {

	@:s var shape : String;
	@:s var amount : Float = 1.0;
	@:s var index : Int = 0;

	public function new(parent, shared: ContextShared) {
		super(parent, shared);
	}

	override function makeObject(parent3d:h3d.scene.Object):h3d.scene.Object {
		return super.makeObject(parent3d);
	}

	override function updateInstance(?propName : String) {
		super.updateInstance();

		local3d.removeChildren();

		var blendedPrim = new BlendedPrimitive(local3d);
		blendedPrim.amount = amount;
		blendedPrim.index = index;
		blendedPrim.update();
		//var parentMesh = cast(ctx.local3d, h3d.scene.Mesh);
		var blended = new h3d.scene.Mesh(null, null, local3d);
		blended.x += -3;
		blended.primitive = blendedPrim;
		for ( m in local3d.getMaterials() )
			for ( p in m.getPasses() )
				p.culling = None;
	}

	#if editor
	override function edit( ectx : hide.prefab.EditContext ) {
		super.edit(ectx);
		var props = ectx.properties.add(new hide.Element('
		<div class="group" name="Shapes">
			<dt>Amount</dt><dd><input type="range" min="0" max="1" field="amount"/></dd>
			<dt>Index</dt><dd><input type="range" min="0" max="3" step="1" field="index"/></dd>
		</div>
		'), this, function(pname) {
			ectx.onChange(this, pname);
		});
	}

	override function getHideProps() : hide.prefab.HideProps {
		return {
			icon : "cube", name : "BlendShape", fileSource : ["fbx","hmd"],
			onResourceRenamed : function(f) animation = f(animation),
		};
	}
	#end

	static var _ = Prefab.register("blendShape", BlendShape);
}