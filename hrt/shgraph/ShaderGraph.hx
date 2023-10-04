package hrt.shgraph;

import hxsl.SharedShader;
using hxsl.Ast;
using hide.tools.Extensions.ArrayExtensions;
using haxe.EnumTools.EnumValueTools;
using Lambda;

typedef ShaderNodeDef = {
	expr: TExpr,
	inVars: Array<TVar>, // Variables that shows up as input of a node
	outVars: Array<TVar>, // Variables that shows up as outputs of a node
	externVars: Array<TVar>, // All the external variables of a shader, including sginput/sgoutputs
	inits: Array<{variable: TVar, value: Dynamic}>, // Default values for some variables
};

typedef Node = {
	x : Float,
	y : Float,
	id : Int,
	type : String,
	?properties : Dynamic,
	?instance : ShaderNode,
	?outputs: Array<Node>,
	?indegree : Int
};

private typedef Edge = {
	idOutput : Int,
	nameOutput : String,
	idInput : Int,
	nameInput : String
};

typedef Connection = {
	from : Node,
	fromName : String,
	to : Node,
	toName : String,
};

typedef Parameter = {
	name : String,
	type : Type,
	defaultValue : Dynamic,
	?id : Int,
	?variable : TVar,
	index : Int
};

@:autoBuild(hrt.shgraph.Macros.buildNode())
class TestNewNode {

}

class TestNewNode2 extends TestNewNode {

	static var SRC = {
		var calculatedUV : Vec2;

		@sginput var a : Vec4;
		@sginput var b : Vec4;
		@sgoutput var output : Vec4;
		function fragment() {
			var c = a + b;
			output = c;
		}
	}
}

class ShaderGraph {

	var allVariables : Array<TVar> = [];
	var allParameters = [];
	var allParamDefaultValue = [];
	var current_node_id = 0;
	var current_param_id = 0;
	var filepath : String;
	var nodes : Map<Int, Node> = [];
	var connections : Map<Connection, Bool> = [];

	public var parametersAvailable : Map<Int, Parameter> = [];
	public var parametersKeys : Array<Int> = [];

	// subgraph variable
	var variableNamesAlreadyUpdated = false;

	public function new(filepath : String) {
		if (filepath == null) return;
		this.filepath = filepath;

		var json : Dynamic;
		try {
			var content : String = null;
			#if editor
			content = sys.io.File.getContent(hide.Ide.inst.resourceDir + "/" + this.filepath);
			#else
			content = hxd.res.Loader.currentInstance.load(this.filepath).toText();
			//content = hxd.Res.load(this.filepath).toText();
			#end
			if (content.length == 0) return;
			json = haxe.Json.parse(content);
		} catch( e : Dynamic ) {
			throw "Invalid shader graph parsing ("+e+")";
		}

		load(json);

	}

	public function load(json : Dynamic) {
		nodes = [];
		parametersAvailable = [];
		parametersKeys = [];
		generate(Reflect.getProperty(json, "nodes"), Reflect.getProperty(json, "edges"), Reflect.getProperty(json, "parameters"));
	}
	public function checkParameterOrder() {
		parametersKeys.sort((x,y) -> Reflect.compare(parametersAvailable.get(x).index, parametersAvailable.get(y).index));
	}

	public function generate(nodes : Array<Node>, edges : Array<Edge>, parameters : Array<Parameter>) {

		for (p in parameters) {
			var typeString : Array<Dynamic> = Reflect.field(p, "type");
			if (Std.isOfType(typeString, Array)) {
				if (typeString[1] == null || typeString[1].length == 0)
					p.type = std.Type.createEnum(Type, typeString[0]);
				else {
					var paramsEnum = typeString[1].split(",");
					p.type = std.Type.createEnum(Type, typeString[0], [Std.parseInt(paramsEnum[0]), std.Type.createEnum(VecType, paramsEnum[1])]);
				}
			}
			p.variable = generateParameter(p.name, p.type);
			this.parametersAvailable.set(p.id, p);
			parametersKeys.push(p.id);
			current_param_id = p.id + 1;
		}
		checkParameterOrder();

		for (n in nodes) {
			n.outputs = [];
			var cl = std.Type.resolveClass(n.type);
			if( cl == null ) throw "Missing shader node "+n.type;
			n.instance = std.Type.createInstance(cl, []);
			n.instance.setId(n.id);
			n.instance.loadProperties(n.properties);
			this.nodes.set(n.id, n);

			var shaderParam = Std.downcast(n.instance, ShaderParam);
			if (shaderParam != null) {
				var paramShader = getParameter(shaderParam.parameterId);
				shaderParam.variable = paramShader.variable;
				shaderParam.computeOutputs();
			}
		}
		if (nodes[nodes.length-1] != null)
			this.current_node_id = nodes[nodes.length-1].id+1;

		for (e in edges) {
			addEdge(e);
		}
	}

	public function addEdge(edge : Edge) {
		var node = this.nodes.get(edge.idInput);
		var output = this.nodes.get(edge.idOutput);
		node.instance.setInput(edge.nameInput, new NodeVar(output.instance, edge.nameOutput));
		output.outputs.push(node);

		// pas du tout envie de mourrir
		var fromGen = output.instance.getShaderDef();
		var fromName = fromGen.outVars[output.instance.getOutputInfoKeys().indexOf(edge.nameOutput)].name;

		var toGen = node.instance.getShaderDef();
		var toName = toGen.inVars[node.instance.getInputInfoKeys().indexOf(edge.nameInput)].name;

		var connection : Connection = {from: output, fromName: fromName, to: node, toName: toName};
		var prevConn = node.instance.inputs2.get(edge.nameInput);
		if (prevConn != null)
			connections.remove(prevConn);

		node.instance.inputs2.set(edge.nameInput, connection);

		var subShaderIn = Std.downcast(node.instance, hrt.shgraph.nodes.SubGraph);
		var subShaderOut = Std.downcast(output.instance, hrt.shgraph.nodes.SubGraph);
		if( @:privateAccess ((subShaderIn != null) && !subShaderIn.inputInfoKeys.contains(edge.nameInput))
			|| @:privateAccess ((subShaderOut != null) && !subShaderOut.outputInfoKeys.contains(edge.nameOutput))
		) {
			removeEdge(edge.idInput, edge.nameInput, false);
		}

		#if editor
		if (hasCycle()){
			removeEdge(edge.idInput, edge.nameInput, false);
			return false;
		}
		try {
			updateOutputs(output);
		} catch (e : Dynamic) {
			removeEdge(edge.idInput, edge.nameInput);
			throw e;
		}
		#end
		return true;
	}

	public function nodeUpdated(idNode : Int) {
		var node = this.nodes.get(idNode);
		if (node != null) {
			updateOutputs(node);
		}
	}

	function updateOutputs(node : Node) {
		node.instance.computeOutputs();
		for (o in node.outputs) {
			updateOutputs(o);
		}
	}

	public function removeEdge(idNode, nameInput, update = true) {
		var node = this.nodes.get(idNode);
		this.nodes.get(node.instance.getInput(nameInput).node.id).outputs.remove(node);
		node.instance.setInput(nameInput, null);
		if (update) {
			updateOutputs(node);
		}
	}

	public function setPosition(idNode : Int, x : Float, y : Float) {
		var node = this.nodes.get(idNode);
		node.x = x;
		node.y = y;
	}

	public function getNodes() {
		return this.nodes;
	}

	public function getNode(id : Int) {
		return this.nodes.get(id);
	}

	function generateParameter(name : String, type : Type) : TVar {
		return {
				parent: null,
				id: 0,
				kind:Param,
				name: name,
				type: type
			};
	}

	static var nodeCache : Map<String, ShaderData> = [];
	public static function getShaderData(cl: Class<ShaderNode>) {
		var className = Type.getClassName(cl);
		var data = nodeCache.get(className);
		if (data == null) {
			var unser = new hxsl.Serializer();
			var toUnser = (cl:Dynamic).SRC;
			if (toUnser == null) throw "Node " + cl + " has no SRC";
			data = @:privateAccess unser.unserialize(toUnser);
			nodeCache.set(className, data);
		}
		return data;
	}

	public function generate2(?getNewVarId: () -> Int) : ShaderNodeDef {
		if (getNewVarId == null) {
			var varIdCount = 0;
			getNewVarId = function()
				{
					return varIdCount++;
				};
		}

		inline function getNewVarName(node: Node, id: Int) : String {
			return '_sg_${(node.type).split(".").pop()}_var_$id';
		}

		var nodeOutputs : Map<Node, Map<String, TVar>> = [];
		function getOutputs(node: Node) : Map<String, TVar> {
			if (!nodeOutputs.exists(node)) {
				var outputs : Map<String, TVar> = [];

				var def = node.instance.getShaderDef();
				for (output in def.outVars) {
					var type = output.type;
					if (type == null) throw "no type";
					var id = getNewVarId();
					var outVar = {id: id, name: getNewVarName(node, id), type: type, kind : Local};
					outputs.set(output.name, outVar);
				}

				nodeOutputs.set(node, outputs);
			}
			return nodeOutputs.get(node);
		}

		// Recursively replace the to tvar with from tvar in the given expression
		function replaceVar(expr: TExpr, what: TVar, with: TExpr) : TExpr {
			if(!what.type.equals(with.t))
				throw "type missmatch " + what.type + " != " + with.t;
			function repRec(f: TExpr) {
				if (f.e.equals(TVar(what))) {
					return with;
				} else {
					return f.map(repRec);
				}
			}
			return repRec(expr);
		}

		// Shader generation starts here

		var pos : Position = {file: "", min: 0, max: 0};
		var outputNodes : Array<Node> = [];
		var inits : Array<{ variable : hxsl.Ast.TVar, value : Dynamic }> = [];

		var allConnections : Array<Connection> = [for (node in nodes) for (connection in node.instance.inputs2) connection];


		// find all node with no output
		var nodeHasOutputs : Map<Node, Bool> = [];
		for (node in nodes) {
			nodeHasOutputs.set(node, false);
		}
		for (connection in allConnections) {
			nodeHasOutputs.set(connection.from, true);
		}

		var graphInputVars : Array<TVar> = [];
		var graphOutputVars : Array<TVar> = [];
		var externs : Array<TVar> = [];

		var nodeToExplore : Array<Node> = [];

		for (node => hasOutputs in nodeHasOutputs) {
			if (!hasOutputs)
				nodeToExplore.push(node);
		}

		var sortedNodes : Array<Node> = [];

		// Topological sort the nodes with Kahn's algorithm
		// https://en.wikipedia.org/wiki/Topological_sorting#Kahn's_algorithm
		{
			while (nodeToExplore.length > 0) {
				var currentNode = nodeToExplore.pop();
				sortedNodes.push(currentNode);
				for (connection in currentNode.instance.inputs2) {
					var targetNode = connection.from;
					if (!allConnections.remove(connection)) throw "connection not in graph";
					if (allConnections.find((n:Connection) -> n.from == targetNode) == null) {
						nodeToExplore.push(targetNode);
					}
				}
			}
		}

		function convertToType(targetType: hxsl.Ast.Type, sourceExpr: TExpr) : TExpr {
			var sourceType = sourceExpr.t;

			var sourceSize = switch (sourceType) {
				case TFloat: 1;
				case TVec(size, VFloat): size;
				default:
					throw "Unsupported source type " + sourceType;
			}

			var targetSize = switch (targetType) {
				case TFloat: 1;
				case TVec(size, VFloat): size;
				default:
					throw "Unsupported target type " + targetType;
			}

			var delta = targetSize - sourceSize;
			if (delta == 0)
				return sourceExpr;
			if (delta > 0) {
				var args = [];
				if (sourceSize == 1) {
					for (_ in 0...targetSize) {
						args.push(sourceExpr);
					}
				}
				else {
					args.push(sourceExpr);
					for (i in 0...delta) {
						args.push({e : TConst(CFloat(0.0)), p: sourceExpr.p, t: TFloat});
					}
				}
				var global : TGlobal = switch (targetSize) {
					case 2: Vec2;
					case 3: Vec3;
					case 4: Vec4;
					default: throw "unreachable";
				}
				return {e: TCall({e: TGlobal(global), p: sourceExpr.p, t:targetType}, args), p: sourceExpr.p, t: targetType};
			}
			if (delta < 0) {
				var swizz : Array<hxsl.Ast.Component> = [X,Y,Z,W];
				swizz.resize(targetSize);
				return {e: TSwiz(sourceExpr, swizz), p: sourceExpr.p, t: targetType};
			}
			throw "unreachable";
		}

		// Actually build the final shader expression
		var exprsReverse : Array<TExpr> = [];
		for (currentNode in sortedNodes) {
			// Skip nodes with no outputs that arent a final node
			if (Std.downcast(currentNode.instance, ShaderOutput)==null) {
				if (!nodeHasOutputs.get(currentNode))
					continue;
			}


			var outputs = getOutputs(currentNode);

			var inputVars : Map<String, TVar> = [];
			for (input in currentNode.instance.inputs2) {
				if (input.to != currentNode) throw "node connection missmatch";
				var outputs = getOutputs(input.from);
				var outputVar = outputs[input.fromName];
				if (outputVar == null) throw "null tvar";

				inputVars.set(input.toName, outputVar);
			}

			/*if (Std.downcast(currentNode.instance, ShaderOutput) != null) {
				var outputNode : ShaderOutput = cast currentNode.instance;
				var outVar : TVar = {name: outputNode.variable.name, id:getNewVarId(), type: TVec(4, VFloat), kind: Local, qualifiers: [SgOutput]};
				var firstInput = inputVars.iterator().next();
				var finalExpr : TExpr = {e: TBinop(OpAssign, {e: TVar(outVar), p: pos, t: outVar.type}, {e: TVar(firstInput), p: pos, t: outVar.type}), p: pos, t: outVar.type};

				exprsReverse.push(finalExpr);
				externs.push(outVar);
				graphOutputVars.push(outVar);

			} else if (Std.downcast(currentNode.instance, ShaderParam) != null) {
				var inputNode : ShaderParam = cast currentNode.instance;


				for (output in outputs) {
					var inVar : TVar = {name: inputNode.variable.name, id:getNewVarId(), type: output.type, kind: Param, qualifiers: [SgInput]};
					var finalExpr : TExpr = {e: TVarDecl(output, {e: TVar(inVar), p: pos, t: output.type}), p: pos, t: output.type};
					exprsReverse.push(finalExpr);
					externs.push(inVar);
					graphInputVars.push(inVar);

					var param = getParameter(inputNode.parameterId);
					inits.push({variable: inVar, value: param.defaultValue});
				}
			} else if (Std.downcast(currentNode.instance, hrt.shgraph.nodes.SubGraph) != null) {
				var subgraph : hrt.shgraph.nodes.SubGraph = cast currentNode.instance;
				var shader = new ShaderGraph(subgraph.pathShaderGraph);
				var gen = shader.generate2(getNewVarId);


				var finalExprs = [];

				// Patch outputs
				for (output in outputs) {
					gen.expr = replaceVar(gen.expr, gen.outVars[0], {e: TVar(output), p:pos, t: output.type});
				}

				// Patch inputs
				for (inputName => tvar in inputVars) {
					var trueName = subgraph.getInputInfo(inputName).name;
					var originalInput = gen.inVars.find((f) -> f.name == trueName);
					var finalExpr : TExpr = {e: TVarDecl(originalInput, convertToType(originalInput.type, {e: TVar(tvar), p: pos, t: tvar.type})), p: pos, t: originalInput.type};
					finalExprs.push(finalExpr);
				}

				finalExprs.push(gen.expr);
				exprsReverse.push({e: TBlock(finalExprs), p:pos, t:TVoid});

				for (i => output in outputs) {
					var finalExpr : TExpr = {e: TVarDecl(output), p: pos, t: output.type};
					exprsReverse.push(finalExpr);
				}
			}*/
			/*else*/
			{
				var def = currentNode.instance.getShaderDef();
				var expr = def.expr;

				var outputDecls : Array<TVar> = [];
				for (nodeVar in def.externVars) {
					if (nodeVar.qualifiers != null) {
						if (nodeVar.qualifiers.has(SgInput)) {
							var ourInputVar = inputVars.get(nodeVar.name);
							var replacement : TExpr = null;
							if (ourInputVar != null) {
								replacement = convertToType(nodeVar.type,  {e: TVar(ourInputVar), p:pos, t: ourInputVar.type});
							}
							else {
								var id = getNewVarId();
								var outVar = {id: id, name: nodeVar.name, type: nodeVar.type, kind : Param, qualifiers: [SgInput]};
								replacement = {e: TVar(outVar), p:pos, t: nodeVar.type};
								graphInputVars.push(outVar);
								externs.push(outVar);
								inits.push({variable: outVar, value:new h3d.Vector()});
							}
							expr = replaceVar(expr, nodeVar, replacement);

						}
						else if (nodeVar.qualifiers.has(SgOutput)) {
							var outputVar : TVar = outputs.get(nodeVar.name);
							if (outputVar == null) {
								externs.push(nodeVar);
							} else {
								expr = replaceVar(expr, nodeVar, {e: TVar(outputVar), p:pos, t: nodeVar.type});
								outputDecls.push(outputVar);
							}
						}
						else {
							externs.push(nodeVar);
						}
					}
					else {
						externs.push(nodeVar);
					}
				}

				exprsReverse.push(expr);

				for (output in outputDecls) {
					var finalExpr : TExpr = {e: TVarDecl(output), p: pos, t: output.type};
					exprsReverse.push(finalExpr);
				}
			}
		}

		exprsReverse.reverse();

		return {
			expr: {e: TBlock(exprsReverse), t:TVoid, p:pos},
			inVars: graphInputVars,
			outVars: graphOutputVars,
			externVars: externs,
			inits: inits,
		};
	}

	public static function measure2<T>(f:Void->T, ?pos:haxe.PosInfos):T {
		//var t0 = haxe.Timer.stamp();
		var r = f();
		//haxe.Log.trace((haxe.Timer.stamp() - t0) * 1000 + "ms", pos);
		return r;
	}

	public function compile2() : hrt.prefab.ContextShared.ShaderDef {
		var start = haxe.Timer.stamp();

		var gen = measure2(()->generate2());

		var shaderData : ShaderData = {
			name: "",
			vars: [],
			funs: [],
		};

		shaderData.vars.append(gen.externVars);

		shaderData.funs.push({
			ret : TVoid, kind : Fragment,
			ref : {
				name : "fragment",
				id : 0,
				kind : Function,
				type : TFun([{ ret : TVoid, args : [] }])
			},
			expr : gen.expr,
			args : []
		});


		var shared = new SharedShader("");
		@:privateAccess shared.data = shaderData;
		@:privateAccess shared.initialize();

		var time = haxe.Timer.stamp() - start;
		trace("Shader compile2 in " + time * 1000 + " ms");

		return {shader : shared, inits: gen.inits};
	}

	public function getParameter(id : Int) {
		return parametersAvailable.get(id);
	}

	static var alreadyBuiltSubGraphs : Array<Int> = [];
	function buildNodeVar(nodeVar : NodeVar) : Array<TExpr>{
		var node = nodeVar.node;
		var isSubGraph = Std.isOfType(node, hrt.shgraph.nodes.SubGraph);
		if (node == null)
			return [];
		if (alreadyBuiltSubGraphs == null)
			alreadyBuiltSubGraphs = [];
		if (isSubGraph)
			alreadyBuiltSubGraphs.push(node.id);
		var res = [];
		var keys = node.getInputInfoKeys();
		for (key in keys) {
			var input = node.getInput(key);
			if (input != null) {
				if (!Std.isOfType(input.node, hrt.shgraph.nodes.SubGraph) || !alreadyBuiltSubGraphs.contains(input.node.id))
					res = res.concat(buildNodeVar(input));
			} else if (node.getInputInfo(key).hasProperty) {
			} else if (!node.getInputInfo(key).isRequired) {
			} else {
				throw ShaderException.t("This box has inputs not connected", node.id);
			}
		}

		var shaderInput = Std.downcast(node, ShaderInput);
		if (shaderInput != null) {
			var variable = shaderInput.variable;
			if ((variable.kind == Param || variable.kind == Global || variable.kind == Input || variable.kind == Local) && !alreadyAddVariable(variable)) {
				allVariables.push(variable);
			}
		}
		var shaderParam = Std.downcast(node, ShaderParam);
		if (shaderParam != null && !alreadyAddVariable(shaderParam.variable)) {
			if (shaderParam.variable == null) {
				shaderParam.variable = generateParameter(shaderParam.variable.name, shaderParam.variable.type);
			}
			allVariables.push(shaderParam.variable);
			allParameters.push(shaderParam.variable);
			if (parametersAvailable.exists(shaderParam.parameterId))
				allParamDefaultValue.push(getParameter(shaderParam.parameterId).defaultValue);
		}
		var build = [];
		if (!isSubGraph)
			build = nodeVar.getExpr();
		else {
			var subGraph = Std.downcast(node, hrt.shgraph.nodes.SubGraph);
			var nodeBuild = node.build("");
			for (k in subGraph.getOutputInfoKeys()) {
				var tvar = subGraph.getOutput(k);
				if (tvar != null && tvar.kind == Local && ShaderInput.availableInputs.indexOf(tvar) < 0)
					build.push({ e : TVarDecl(tvar), t : tvar.type, p : null });
			}
			if (nodeBuild != null)
				build.push(nodeBuild);

			var params = subGraph.subShaderGraph.parametersAvailable;
			for (subVar in subGraph.varsSubGraph) {
				if (subVar.kind == Param) {
					if (!alreadyAddVariable(subVar)) {
						allVariables.push(subVar);
						allParameters.push(subVar);
						var defaultValueFound = false;
						for (param in params) {
							if (param.variable.name == subVar.name) {
								allParamDefaultValue.push(param.defaultValue);
								defaultValueFound = true;
								break;
							}
						}
						if (!defaultValueFound) {
							throw ShaderException.t("Default value of '" + subVar.name + "' parameter not found", node.id);
						}
					}
				} else {
					if (!alreadyAddVariable(subVar)) {
						allVariables.push(subVar);
					}
				}
			}
			var buildWithoutTBlock = [];
			for (i in 0...build.length) {
				switch (build[i].e) {
					case TBlock(block):
						for (b in block) {
							buildWithoutTBlock.push(b);
						}
					default:
						buildWithoutTBlock.push(build[i]);
				}
			}
			build = buildWithoutTBlock;
		}
		res = res.concat(build);
		return res;
	}

	function alreadyAddVariable(variable : TVar) {
		for (v in allVariables) {
			if (v.name == variable.name && v.type == variable.type) {
				return true;
			}
		}
		return false;
	}

	var variableNameAvailableOnlyInVertex = [];

	public function generateShader(specificOutput : ShaderNode = null, subShaderId : Int = null) : ShaderData {
		allVariables = [];
		allParameters = [];
		allParamDefaultValue = [];
		var contentVertex = [];
		var contentFragment = [];

		if( subShaderId == null )
			alreadyBuiltSubGraphs = [];
		for (n in nodes) {
			if (!variableNamesAlreadyUpdated && subShaderId != null && !Std.isOfType(n.instance, ShaderInput)) {
				for (outputKey in n.instance.getOutputInfoKeys()) {
					var output = n.instance.getOutput(outputKey);
					if (output != null)
						output.name = "sub_" + subShaderId + "_" + output.name;
				}
			}
			n.instance.outputCompiled = [];
			#if !editor
			if (!n.instance.hasInputs()) {
				updateOutputs(n);
			}
			#end
		}
		variableNamesAlreadyUpdated = true;

		var outputs : Array<String> = [];

		for (g in ShaderGlobalInput.globalInputs) {
			allVariables.push(g);
		}

		for (n in nodes) {
			var outNode;
			var outVar;
			if (specificOutput != null) {
				if (n.instance != specificOutput) continue;
				outNode = specificOutput;
				outVar = Std.downcast(specificOutput, hrt.shgraph.nodes.Preview).variable;
			} else {
				var shaderOutput = Std.downcast(n.instance, ShaderOutput);

				if (shaderOutput != null) {
					outVar = shaderOutput.variable;
					outNode = n.instance;
				} else {
					continue;
				}
			}
			if (outNode != null) {
				if (outputs.indexOf(outVar.name) != -1) {
					throw ShaderException.t("This output already exists", n.id);
				}
				outputs.push(outVar.name);
				if ( !alreadyAddVariable(outVar) ) {
					allVariables.push(outVar);
				}
				var nodeVar = new NodeVar(outNode, "input");
				var isVertex = (variableNameAvailableOnlyInVertex.indexOf(outVar.name) != -1);
				if (isVertex) {
					contentVertex = contentVertex.concat(buildNodeVar(nodeVar));
				} else {
					contentFragment = contentFragment.concat(buildNodeVar(nodeVar));
				}
				if (specificOutput != null) break;
			}
		}

		var shvars = [];
		var inputVar : TVar = null, inputVars = [], inputMap = new Map();
		for( v in allVariables ) {
			if( v.id == 0 )
				v.id = hxsl.Tools.allocVarId();
			if( v.kind != Input ) {
				shvars.push(v);
				continue;
			}
			if( inputVar == null ) {
				inputVar = {
					id : hxsl.Tools.allocVarId(),
					name : "input",
					kind : Input,
					type : TStruct(inputVars),
				};
				shvars.push(inputVar);
			}
			var prevId = v.id;
			v = Reflect.copy(v);
			v.id = hxsl.Tools.allocVarId();
			v.parent = inputVar;
			inputVars.push(v);
			inputMap.set(prevId, v);
		}

		if( inputVars.length > 0 ) {
			function remap(e:TExpr) {
				return switch( e.e ) {
				case TVar(v):
					var i = inputMap.get(v.id);
					if( i == null ) e else { e : TVar(i), p : e.p, t : e.t };
				default:
					hxsl.Tools.map(e, remap);
				}
			}
			contentVertex = [for( e in contentVertex ) remap(e)];
			contentFragment = [for( e in contentFragment ) remap(e)];
		}

		var shaderData = {
			funs : [],
			name: "SHADER_GRAPH",
			vars: shvars
		};

		if (contentVertex.length > 0) {
			shaderData.funs.push({
					ret : TVoid, kind : Vertex,
					ref : {
						name : "vertex",
						id : 0,
						kind : Function,
						type : TFun([{ ret : TVoid, args : [] }])
					},
					expr : {
						p : null,
						t : TVoid,
						e : TBlock(contentVertex)
					},
					args : []
				});
		}

		if (contentFragment.length > 0) {
			shaderData.funs.push({
					ret : TVoid, kind : Fragment,
					ref : {
						name : "fragment",
						id : 0,
						kind : Function,
						type : TFun([{ ret : TVoid, args : [] }])
					},
					expr : {
						p : null,
						t : TVoid,
						e : TBlock(contentFragment)
					},
					args : []
				});
		}

		return shaderData;
	}

	public function compile(?specificOutput : ShaderNode, ?subShaderId : Int) : hrt.prefab.ContextShared.ShaderDef {

		var shaderData = generateShader(specificOutput, subShaderId);

		var s = new SharedShader("");
		s.data = shaderData;
		@:privateAccess s.initialize();
		var inits : Array<{ variable : hxsl.Ast.TVar, value : Dynamic }> = [];

		for (i in 0...allParameters.length) {
			inits.push({ variable : allParameters[i], value : allParamDefaultValue[i] });
		}

		var shaderDef = { shader : s, inits : inits };
		return shaderDef;
	}

	public function makeInstance(ctx: hrt.prefab.ContextShared) : hxsl.DynamicShader {
		var def = compile();
		var s = new hxsl.DynamicShader(def.shader);
		for (init in def.inits)
			setParamValue(ctx, s, init.variable, init.value);
		return s;
	}

	static function setParamValue(ctx: hrt.prefab.ContextShared, shader : hxsl.DynamicShader, variable : hxsl.Ast.TVar, value : Dynamic) {
		try {
			switch (variable.type) {
				case TSampler2D:
					var t = ctx.loadTexture(value);
					t.wrap = Repeat;
					shader.setParamValue(variable, t);
				case TVec(size, _):
					shader.setParamValue(variable, h3d.Vector.fromArray(value));
				default:
					shader.setParamValue(variable, value);
			}
		} catch (e : Dynamic) {
			// The parameter is not used
		}
	}


	#if editor
	public function addNode(x : Float, y : Float, nameClass : Class<ShaderNode>) {
		var node : Node = { x : x, y : y, id : current_node_id, type: std.Type.getClassName(nameClass) };

		node.instance = std.Type.createInstance(nameClass, []);
		node.instance.setId(current_node_id);
		node.instance.computeOutputs();
		node.outputs = [];

		this.nodes.set(node.id, node);
		current_node_id++;

		return node.instance;
	}

	public function hasCycle() : Bool {
		var queue : Array<Node> = [];

		var counter = 0;
		var nbNodes = 0;
		for (n in nodes) {
			n.indegree = n.outputs.length;
			if (n.indegree == 0) {
				queue.push(n);
			}
			nbNodes++;
		}

		var currentIndex = 0;
		while (currentIndex < queue.length) {
			var node = queue[currentIndex];
			currentIndex++;

			for (input in node.instance.getInputs()) {
				var nodeInput = nodes.get(input.node.id);
				nodeInput.indegree -= 1;
				if (nodeInput.indegree == 0) {
					queue.push(nodeInput);
				}
			}
			counter++;
		}

		return counter != nbNodes;
	}

	public function addParameter(type : Type) {
		var name = "Param_" + current_param_id;
		parametersAvailable.set(current_param_id, {id: current_param_id, name : name, type : type, defaultValue : null, variable : generateParameter(name, type), index : parametersKeys.length});
		parametersKeys.push(current_param_id);
		current_param_id++;
		return current_param_id-1;
	}

	public function setParameterTitle(id : Int, newName : String) {
		var p = parametersAvailable.get(id);
		if (p != null) {
			if (newName != null) {
				for (p in parametersAvailable) {
					if (p.name == newName) {
						return false;
					}
				}
				p.name = newName;
				p.variable = generateParameter(newName, p.type);
				return true;
			}
		}
		return false;
	}

	public function setParameterDefaultValue(id : Int, newDefaultValue : Dynamic) : Bool {
		var p = parametersAvailable.get(id);
		if (p != null) {
			if (newDefaultValue != null) {
				p.defaultValue = newDefaultValue;
				return true;
			}
		}
		return false;
	}

	public function removeParameter(id : Int) {
		parametersAvailable.remove(id);
		parametersKeys.remove(id);
		checkParameterIndex();
	}

	public function checkParameterIndex() {
		for (k in parametersKeys) {
			var oldParam = parametersAvailable.get(k);
			oldParam.index = parametersKeys.indexOf(k);
			parametersAvailable.set(k, oldParam);
		}
	}

	public function removeNode(idNode : Int) {
		this.nodes.remove(idNode);
	}

	public function save() {
		var edgesJson : Array<Edge> = [];
		for (n in nodes) {
			for (k in n.instance.getInputsKey()) {
				var output =  n.instance.getInput(k);
				edgesJson.push({ idOutput: output.node.id, nameOutput: output.keyOutput, idInput: n.id, nameInput: k });
			}
		}
		var json = haxe.Json.stringify({
			nodes: [
				for (n in nodes) { x : Std.int(n.x), y : Std.int(n.y), id: n.id, type: n.type, properties : n.instance.savePropertiesNode() }
			],
			edges: edgesJson,
			parameters: [
				for (p in parametersAvailable) { id : p.id, name : p.name, type : [p.type.getName(), p.type.getParameters().toString()], defaultValue : p.defaultValue, index : p.index }
			]
		}, "\t");

		return json;
	}
	#end
}