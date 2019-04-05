package hrt.shgraph;

import hrt.shgraph.ShaderType;
import haxe.macro.Context;
import haxe.macro.Expr;
using haxe.macro.Tools;

typedef SField = { name : String, value : ShaderType.SType };

class ParseFieldsMacro {

#if macro

	public static function build() : Array<Field> {
		var fields = Context.getBuildFields();

		var mapInputs = new Array<Expr>();
		var hasInputs = false;
		var mapOutputs = new Array<Expr>();
		var hasOutputs = false;

		for ( f in fields ) {
			if( f.meta == null ) continue;
			switch (f.kind) {
				case FVar(t, e):
					var saveMeta = f.meta;
					for (m in saveMeta) {
						if (m.name == "input") {
							hasInputs = true;
							var sel = f.name;
							var get_sel = "get_" + sel;
							var sfields = macro class {
								inline function $get_sel() : NodeVar return getInput($v{sel});
							};
							for( field in sfields.fields )
								fields.push(field);
							if (e == null)
								Context.error('Input ${sel} has not affectation', f.pos);
							var enumValue = ["ShaderType", "SType", e.toString().split(".").pop()];
							mapInputs.push(macro $v{sel} => ${enumValue.toFieldExpr()});
							f.kind = FProp("get", "null", TPath({ pack: ["hrt", "shgraph"], name: "NodeVar" }));
							f.meta = saveMeta;
							break;
						}
						if (m.name == "output") {
							hasOutputs = true;
							var sel = f.name;
							var get_sel = "get_" + sel;
							var sfields = macro class {
								inline function $get_sel() : TVar return getOutput($v{sel});
							};
							for( field in sfields.fields )
								fields.push(field);
							if (e == null)
								Context.error('Output ${sel} has not affectation', f.pos);
							var enumValue = ["ShaderType", "SType", e.toString().split(".").pop()];
							mapOutputs.push(macro $v{sel} => ${enumValue.toFieldExpr()});
							f.kind = FProp("get", "null", TPath({ pack: [], name: "TVar" }));
							f.meta = saveMeta;
							break;
						}
					}
				default:
			}
		}
		if (hasInputs) {
			fields.push({
				name: "inputsInfo",
				access: [Access.APrivate],
				kind: FieldType.FVar(macro:Map<String, ShaderType.SType>, macro $a{mapInputs}),
				pos: Context.currentPos(),
			});
			var sfields = macro class {
				override public function getInputInfo(key : String) : ShaderType.SType return inputsInfo.get(key);
			};
			for( field in sfields.fields )
				fields.push(field);
		}
		if (hasOutputs) {
			fields.push({
				name: "outputsInfo",
				access: [Access.APrivate],
				kind: FieldType.FVar(macro:Map<String, ShaderType.SType>, macro $a{mapOutputs}),
				pos: Context.currentPos(),
			});
			var sfields = macro class {
				override public function getOutputInfo(key : String) : ShaderType.SType return outputsInfo.get(key);
			};
			for( field in sfields.fields )
				fields.push(field);
		}

		var thisClass = Context.getLocalClass();
		var cl = thisClass.get();
		var clPath = cl.pack.copy();
		clPath.push(cl.name);

		fields.push({
			name: "_",
			access: [Access.AStatic],
			kind: FieldType.FVar(macro:Bool, macro ShaderNode.register($v{cl.name}, ${clPath.toFieldExpr()})),
			pos: Context.currentPos(),
		});

		return fields;
	}

#end
}
