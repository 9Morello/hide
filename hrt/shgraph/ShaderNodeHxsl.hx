package hrt.shgraph;

@:autoBuild(hrt.shgraph.Macros.buildNode())
class ShaderNodeHxsl extends ShaderNode {

	static var nodeCache : Map<String, ShaderGraph.ShaderNodeDef> = [];

	override public function getShaderDef(domain: ShaderGraph.Domain) : ShaderGraph.ShaderNodeDef {
		var cl = Type.getClass(this);
		var className = Type.getClassName(cl);
		var def = nodeCache.get(className);
		if (def == null) {

			var unser = new hxsl.Serializer();
			var toUnser = (cl:Dynamic).SRC;
			if (toUnser == null) throw "Node " + className + " has no SRC";
			var data = @:privateAccess unser.unserialize(toUnser);
			var expr = data.funs[0].expr;
			var inVars = [];
			var outVars = [];
			var externVars = [];

			for (tvar in data.vars) {
					var input = false;
					var output = false;
					var classInVars : Array<String> = cast (cl:Dynamic)._inVars;
					var classDefVal : Array<String> = cast (cl:Dynamic)._defValues;

					var indexOf = classInVars.indexOf(tvar.name);
					if (indexOf > -1) {
						var defStr = classDefVal[indexOf];
						var def : hrt.shgraph.ShaderGraph.ShaderDefInput = null;
						if (defStr != null) {
							var float = Std.parseFloat(defStr);
							if (!Math.isNaN(float)) {
								def = Const(float);
							} else {
								def = Var(defStr);
							}
							trace(def);
						}
						inVars.push({v:tvar, internal: false, defVal: def});
						// TODO : handle default values
						input = true;
					}
					var classOutVars : Array<String> = cast (cl:Dynamic)._outVars;
					if (classOutVars.contains(tvar.name)) {
						outVars.push({v: tvar, internal: false});
						output = true;
					}
					if (input && output) {
						throw "Variable is both sginput and sgoutput";
					}
					if (!input && !output) {
						externVars.push(tvar);
					}
			}

			def = {expr: expr, inVars: inVars, outVars: outVars, externVars: externVars, inits: []};
			nodeCache.set(className, def);
		}

		return def;
	}
}