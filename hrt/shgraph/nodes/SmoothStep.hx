package hrt.shgraph.nodes;

using hxsl.Ast;

@name("Smooth Step")
@description("Linear interpolation between A and B using Mix")
@width(100)
@group("Math")
class SmoothStep extends ShaderNodeHxsl {

	static var SRC = {
		@sginput(0.0) var a : Vec4;
		@sginput(0.0) var b : Vec4;
		@sginput var fact : Vec4;
		@sgoutput var output : Vec4;
		function fragment() {
			output = smoothstep(a,b, fact);
		}
	};

}