package hrt.shgraph;

import hide.Element;
import h3d.Vector;
import hxsl.*;

using hxsl.Ast;

@name("Outputs")
@description("Parameters outputs, it's dynamic")
@group("Output")
@noheader()
class ShaderOutput extends ShaderNode {

	@input("input") var input = SType.Variant;

	@param("Variable") public var variable : TVar;

	var components = [X, Y, Z, W];

	override public function checkValidityInput(key : String, type : ShaderType.SType) : Bool {
		return ShaderType.checkCompatibilities(type, ShaderType.getType(variable.type));
	}

	override public function build(key : String) : TExpr {

		return {
				p : null,
				t : TVoid,
				e : TBinop(OpAssign, {
					e: TVar(variable),
					p: null,
					t: variable.type
				}, input.getVar(variable.type))
			};

	}
	static var availableOutputs = [];

	override public function loadParameters(params : Dynamic) {
		var paramVariable : Array<String> = Reflect.field(params, "variable");

		for (c in ShaderNode.availableVariables) {
			if (c.name == paramVariable[0]) {
				this.variable = c;
				return;
			}
		}
		for (c in ShaderOutput.availableOutputs) {
			if (c.name == paramVariable[0]) {
				this.variable = c;
				return;
			}
		}
	}

	override public function saveParameters() : Dynamic {
		var parameters = {
			variable: [variable.name, variable.type.getName()]
		};

		return parameters;
	}


	#if editor
	override public function getParametersHTML(width : Float) : Array<Element> {
		var elements = super.getParametersHTML(width);
		var element = new Element('<div style="width: 110px; height: 30px"></div>');
		element.append(new Element('<select id="variable"></select>'));

		if (this.variable == null) {
			this.variable = ShaderNode.availableVariables[0];
		}
		var input = element.children("select");
		var indexOption = 0;
		for (c in ShaderNode.availableVariables) {
			input.append(new Element('<option value="${indexOption}">${c.name}</option>'));
			if (this.variable.name == c.name) {
				input.val(indexOption);
			}
			indexOption++;
		}
		for (c in ShaderOutput.availableOutputs) {
			input.append(new Element('<option value="${indexOption}">${c.name}</option>'));
			if (this.variable.name == c.name) {
				input.val(indexOption);
			}
			indexOption++;
		}
		input.on("change", function(e) {
			var value = input.val();
			this.variable = ShaderNode.availableVariables[value];
		});

		elements.push(element);

		return elements;
	}
	#end
}