package hrt.shgraph.nodes;

using hxsl.Ast;

@name("Multiply")
@description("The output is the result of A * B")
@width(80)
@group("Operation")
class Multiply extends Operation {

	public function new() {
		super(OpMult);
	}

	static var SRC = {
		@sginput var a : Vec4;
		@sginput var b : Vec4;
		@sgoutput var output : Vec4;
		function fragment() {
			output = a * b;
		}
	}
}