package hrt.shgraph.nodes;

using hxsl.Ast;

@name("Min")
@description("The output is the minimum between A and B")
@width(80)
@group("Math")
class Min extends ShaderNodeHxsl {

	static var SRC = {
		@sginput(0.0) var a : Dynamic;
		@sginput(0.0) var b : Dynamic;
		@sgoutput var output : Dynamic;
		function fragment() {
			output = min(a,b);
		}
	};

}