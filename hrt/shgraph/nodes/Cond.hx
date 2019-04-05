package hrt.shgraph.nodes;

import hide.Element;
using hxsl.Ast;

@name("Condition")
@description("Create a custom condition between two inputs")
@group("Condition")
class Cond extends ShaderNode {

	@input("left") var leftVar = SType.Variant;
	@input("right") var rightVar = SType.Variant;

	@output("boolean") var output = SType.Bool;

	@param() var condition : Binop;

	override public function checkValidityInput(key : String, type : ShaderType.SType) : Bool {

		if (key == "leftVar" && rightVar != null)
			return ShaderType.checkCompatibilities(type, ShaderType.getType(rightVar.getType()));

		if (key == "rightVar" && leftVar != null)
			return ShaderType.checkCompatibilities(type, ShaderType.getType(leftVar.getType()));

		return true;
	}

	override public function createOutputs() {
		addOutput("output", TBool);
	}

	override public function build(key : String) : TExpr {

		return {
				p : null,
				t : output.type,
				e : TBinop(OpAssign, {
						e: TVar(output),
						p: null,
						t: output.type
					}, {e: TBinop(this.condition,
							leftVar.getVar(),
							rightVar.getVar()),
						p: null, t: output.type })
			};
	}

	var availableConditions = [OpEq, OpNotEq, OpGt, OpGte, OpLt, OpLte, OpAnd, OpOr];
	var conditionStrings 	= ["==", "!=",    ">",  ">=",  "<",  "<=",  "AND", "OR"];

	override public function saveParameters() : Dynamic {
		var parameters = {
			condition: this.condition.getName()
		};

		return parameters;
	}

	#if editor
	override public function getParametersHTML(width : Float) : Array<Element> {
		var elements = super.getParametersHTML(width);
		var element = new Element('<div style="width: ${width * 0.8}px; height: 40px"></div>');
		element.append('<span>Condition</span>');
		element.append(new Element('<select id="condition"></select>'));

		var input = element.children("select");
		var indexOption = 0;
		for (c in conditionStrings) {
			input.append(new Element('<option value="${indexOption}">${c}</option>'));
			indexOption++;
		}
		input.on("change", function(e) {
			var value = input.val();
			this.condition = availableConditions[value];
		});
		this.condition = availableConditions[0];

		elements.push(element);

		return elements;
	}
	#end

}