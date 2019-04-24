package hrt.shgraph;

import hide.Element;
import hxsl.*;

using hxsl.Ast;

@noheader()
@width(100)
@color("#1F690A")
class ShaderParam extends ShaderNode {

	@output() var output = SType.Variant;

	@prop() public var parameterId : Int;

	public var variable : TVar;
	private var parameterName : String;

	override public function computeOutputs() {
		if (variable != null)
			addOutput("output", variable.type);
		else
			removeOutput("output");
	}

	override public function getOutput(key : String) : TVar {
		return variable;
	}

	override public function loadProperties(props : Dynamic) {
		parameterId = Reflect.field(props, "parameterId");
	}

	override public function saveProperties() : Dynamic {
		var parameters = {
			parameterId: parameterId
		};

		return parameters;
	}

	override public function build(key : String) : TExpr {
		return null;
	}

	#if editor
	private var eltName : Element;
	public function setName(s : String) {
		parameterName = s;
		if (eltName != null)
			eltName.html(s);
	}
	override public function getPropertiesHTML(width : Float) : Array<Element> {
		var elements = super.getPropertiesHTML(width);
		var element = new Element('<div style="width: 75px; height: 30px"></div>');
		eltName = new Element('<span class="variable">${parameterName}</span>').appendTo(element);

		elements.push(element);

		return elements;
	}
	#end

}