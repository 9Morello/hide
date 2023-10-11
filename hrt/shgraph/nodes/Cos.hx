package hrt.shgraph.nodes;

using hxsl.Ast;

@name("Cosinus")
@description("The output is the cosinus of A")
@width(80)
@group("Math")
class Cos extends ShaderNodeHxsl {

	static var SRC = {
		@sginput(0.0) var a : Dynamic;
		@sgoutput var output : Dynamic;
		function fragment() {
			output = cos(a);
		}
	};

}