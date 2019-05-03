package hrt.shgraph;

using hxsl.Ast;

class ShaderFunction extends ShaderNode {

	@output("") var output = SType.Variant;

	var func : TGlobal;

	public function new(func : TGlobal) {
		this.func = func;
	}

	override public function build(key : String) : TExpr {
		var args = [];
		var varArgs = [];

		for (k in getInputInfoKeys()) {
			args.push({ name: k, type: getInput(k).getType() });
			var wantedType = ShaderType.getType(getInputInfo(k).type);
			varArgs.push(getInput(k).getVar((wantedType != null) ? wantedType : null));
		}

		return {
					p : null,
					t : output.type,
					e : TBinop(OpAssign, {
						e: TVar(output),
						p: null,
						t: output.type
					}, {
						e: TCall({
							e: TGlobal(func),
							p: null,
							t: TFun([
								{
									ret: output.type,
									args: args
								}
							])
						}, varArgs),
						p: null,
						t: output.type
					})
				};
	}

}