package hrt.shgraph;

using hxsl.Ast;

typedef InputVariable = {display: String, v: TVar};

@name("Inputs")
@description("Shader inputs of Heaps, it's dynamic")
@group("Property")
@color("#0e8826")
class ShaderInput extends ShaderNode {


	@prop("Variable") public var variable : String = "position";

	// override public function getOutput(key : String) : TVar {
	// 	return variable;
	// }

	// override public function build(key : String) : TExpr {
	// 	return null;
	// }

	override function getShaderDef(domain: ShaderGraph.Domain, getNewIdFn : () -> Int ):hrt.shgraph.ShaderGraph.ShaderNodeDef {
		var pos : Position = {file: "", min: 0, max: 0};

		var variable : InputVariable = availableInputs.get(this.variable);
		if (variable == null)
			throw "Unknown input variable " + this.variable;

		var inVar : TVar = Reflect.copy(variable.v);
		inVar.id = getNewIdFn();
		var output : TVar = {name: "output", id: getNewIdFn(), type: variable.v.type, kind: Local, qualifiers: []};
		var finalExpr : TExpr = {e: TBinop(OpAssign, {e:TVar(output), p:pos, t:output.type}, {e: TVar(inVar), p: pos, t: output.type}), p: pos, t: output.type};


		return {expr: finalExpr, inVars: [{v:inVar, internal: true}], outVars:[{v:output, internal: false}], externVars: [], inits: []};
	}

	public static var availableInputs : Map<String, InputVariable> = [
		"pixelColor" => {display: "Pixel Color", v: { parent: null, id: 0, kind: Local, name: "pixelColor", type: TVec(4, VFloat) }},
		"calculatedUV" => {display: "UV", v: { parent: null, id: 0, kind: Local, name: "calculatedUV", type: TVec(2, VFloat) }},
		"relativePosition" => {display: "Object Space Position", v: { parent: null, id: 0, kind: Local, name: "relativePosition", type: TVec(3, VFloat) }},
		"transformedPosition" => {display: "World Space Position", v: { parent: null, id: 0, kind: Local, name: "transformedPosition", type: TVec(3, VFloat) }},
		"projectedPosition" => {display: "Projected Position", v: { parent: null, id: 0, kind: Local, name: "projectedPosition", type: TVec(4, VFloat) }},
		"transformedNormal" => {display: "Normal", v: { parent: null, id: 0, kind: Local, name: "transformedNormal", type: TVec(3, VFloat) }},

		"position" => {display: "Source Position", v: { parent: null, id: 0, kind: Input, name: "input.position", type: TVec(3, VFloat) }},
		"color" => 	{display: "Source Vertex Color", v: { parent: null, id: 0, kind: Input, name: "input.color", type: TVec(3, VFloat) }},
		"uv" => {display: "Source UV", v: { parent: null, id: 0, kind: Input, name: "input.uv", type: TVec(2, VFloat) }},
		"normal" => {display: "Source Normal", v: { parent: null, id: 0, kind: Input, name: "input.normal", type: TVec(3, VFloat) }},
		"tangent" => {display: "Source Tangent", v: { parent: null, id: 0, kind: Input, name: "input.tangent", type: TVec(3, VFloat) }},
	];

	/*public static var availableInputs : Array<TVar> = [
									{ parent: null, id: 0, kind: Input, name: "position", type: TVec(3, VFloat) },
									{ parent: null, id: 0, kind: Input, name: "color", type: TVec(3, VFloat) },
									{ parent: null, id: 0, kind: Input, name: "uv", type: TVec(2, VFloat) },
									{ parent: null, id: 0, kind: Input, name: "normal", type: TVec(3, VFloat) },
									{ parent: null, id: 0, kind: Input, name: "tangent", type: TVec(3, VFloat) },
									{ parent: null, id: 0, kind: Local, name: "relativePosition", type: TVec(3, VFloat) },
									{ parent: null, id: 0, kind: Local, name: "transformedPosition", type: TVec(3, VFloat) },
									{ parent: null, id: 0, kind: Local, name: "projectedPosition", type: TVec(4, VFloat) },
									{ parent: null, id: 0, kind: Local, name: "transformedNormal", type: TVec(3, VFloat) },
									{ parent: null, id: 0, kind: Local, name: "screenUV", type: TVec(2, VFloat) },
									{ parent: null, id: 0, kind: Local, name: "calculatedUV", type: TVec(2, VFloat) },
								];*/

	// override public function loadProperties(props : Dynamic) {
	// 	variable = Reflect.field(props, "Variable");
	// }

	// override public function saveProperties() : Dynamic {
	// 	var parameters = {
	// 		variable: variable;
	// 	};

	// 	return parameters;
	// }

	#if editor
	override public function getPropertiesHTML(width : Float) : Array<hide.Element> {
		var elements = super.getPropertiesHTML(width);
		var element = new hide.Element('<div style="width: 120px; height: 30px"></div>');
		element.append(new hide.Element('<select id="variable"></select>'));

		if (variable == null) {
			variable = "position";
		}

		var input = element.children("select");
		var indexOption = 0;
		for (k => variable in availableInputs) {
			input.append(new hide.Element('<option value="${k}">${variable.display}</option>'));
		}
		input.val(variable);

		input.on("change", function(e) {
			variable = input.val();
		});

		elements.push(element);

		return elements;
	}
	#end

}