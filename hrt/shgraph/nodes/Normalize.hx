package hrt.shgraph.nodes;

using hxsl.Ast;

@name("Normalize")
@description("The output is the result of normalize(x)")
@width(80)
@group("Math")
class Normalize extends ShaderNodeHxsl {

	static var SRC = {
		@sginput var a : Vec4;
		@sgoutput var output : Vec4;
		function fragment() {
			output = normalize(a);
		}
	};

}