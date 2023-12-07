package hrt.prefab;

class ShaderGraph extends DynamicShader {

	public function new(?parent) {
		super(parent);
		type = "shgraph";
	}

	override public function loadShaderDef(ctx: Context) {
		if (shaderDef == null) {
			shaderDef = @:privateAccess ctx.shared.shaderCache.get(this.source);
			if (shaderDef != null) {
				trace('[shgraph] Cache hit for $source');
			}
		}

		if(shaderDef == null) {
			trace('[shgraph] Cache miss for $source, recompiling');
			var shaderGraph = new hrt.shgraph.ShaderGraph(source);
			shaderDef = shaderGraph.compile2(false);
			@:privateAccess ctx.shared.shaderCache.set(this.source, shaderDef);
		}
		if(shaderDef == null)
			return;

		#if editor
		for( v in shaderDef.inits ) {
			if(!Reflect.hasField(props, v.variable.name)) {
				Reflect.setField(props, v.variable.name, v.value);
			}
		}
		#end
	}

	#if editor
	override function getHideProps() : HideProps {
		return { icon : "scribd", name : "Shader Graph", fileSource : ["shgraph"], allowParent : function(p) return p.to(Object2D) != null || p.to(Object3D) != null };
	}

	override function edit( ctx : EditContext ) {
		super.edit(ctx);

		var btn = new hide.Element("<input type='submit' style='width: 100%; margin-top: 10px;' value='Open Shader Graph' />");
		btn.on("click", function() {
 			ctx.ide.openFile(source);
		});
		ctx.properties.add(btn,this.props, function(pname) {
			ctx.onChange(this, pname);
		});
	}
	#end

	static var _ = Library.register("shgraph", ShaderGraph);
}