package hrt.prefab;

class BlendShape extends hrt.prefab.Model {

	@:s var shape : String;
	@:s var amount : Float = 1.0;
	@:s var index : Int = 0;

	public function new(parent, shared: ContextShared) {
		super(parent, shared);
	}

	override function makeObject(parent3d:h3d.scene.Object):h3d.scene.Object {
		var obj = super.makeObject(parent3d);

		var mesh = Std.downcast(obj, h3d.scene.Mesh);
		var hmdModel = Std.downcast(mesh.primitive, h3d.prim.HMDModel);
		hmdModel.setBlendshapeAmount(index, amount);

		return obj;
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
			var mesh = Std.downcast(local3d, h3d.scene.Mesh);
			var hmdModel = Std.downcast(mesh.primitive, h3d.prim.HMDModel);

			ectx.onChange(this, pname);
			hmdModel.setBlendshapeAmount(index, amount);
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