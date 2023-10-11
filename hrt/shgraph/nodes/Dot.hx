package hrt.shgraph.nodes;

using hxsl.Ast;

@name("Dot")
@description("The output is the dot product of a and b")
@width(80)
@group("Math")
class Dot extends ShaderNodeHxsl {

	static var SRC = {
		@sginput(0.0) var a : Dynamic;
		@sginput(0.0) var b : Dynamic;
		@sgoutput var output : Float;
		function fragment() {
			output = dot(a,b);
		}
	};

}