package hide.view.shadereditor;

import hide.comp.SVG;
import js.jquery.JQuery;
import hrt.shgraph.ShaderNode;
class Box {

	var boolColor = "#cc0505";
	var numberColor = "#00ffea";
	var floatColor = "#00ff73";
	var intColor = "#00ffea";
	var vec2Color = "#5eff00";
	var vec3Color = "#eeff00";
	var vec4Color = "#fc6703";
	var samplerColor = "#600aff";
	var defaultColor = "#c8c8c8";

	var nodeInstance : ShaderNode;

	var x : Float;
	var y : Float;

	var width : Int = 150;
	var height : Int;
	var propsHeight : Int = 0;

	var HEADER_HEIGHT = 22;
	@const var NODE_MARGIN = 17;
	public static var NODE_RADIUS = 5;
	@const var NODE_TITLE_PADDING = 10;
	@const var NODE_INPUT_PADDING = 3;
	public var selected : Bool = false;

	public var inputs : Array<JQuery> = [];
	public var outputs : Array<JQuery> = [];

	var hasHeader : Bool = true;
	var hadToShowInputs : Bool = false;
	var color : String;
	var closePreviewBtn : JQuery;

	var element : JQuery;
	var propertiesGroup : JQuery;

	public function new(editor : SVG, parent : JQuery, x : Float, y : Float, node : ShaderNode) {
		this.nodeInstance = node;

		var metas = haxe.rtti.Meta.getType(Type.getClass(node));
		if (metas.width != null) {
			this.width = metas.width[0];
		}
		if (Reflect.hasField(metas, "color")) {
			color = Reflect.field(metas, "color");
		}
		var className = (metas.name != null) ? metas.name[0] : "Undefined";

		element = editor.group(parent).addClass("box").addClass("not-selected");
		element.attr("id", node.id);
		setPosition(x, y);

		if (Reflect.hasField(metas, "noheader")) {
			HEADER_HEIGHT = 0;
			hasHeader = false;
		}

		// Debug: editor.text(element, 2, -6, 'Node ${node.id}').addClass("node-id-indicator");

		// outline of box
		editor.rect(element, -1, -1, width+2, getHeight()+2).addClass("outline");

		// header

		if (hasHeader) {
			var header = editor.rect(element, 0, 0, this.width, HEADER_HEIGHT).addClass("head-box");
			if (color != null) header.css("fill", color);
			editor.text(element, 7, HEADER_HEIGHT-6, className).addClass("title-box");
		}

		if (Reflect.hasField(metas, "alwaysshowinputs")) {
			hadToShowInputs = true;
		}

		propertiesGroup = editor.group(element).addClass("properties-group");

		// nodes div
		var bg = editor.rect(element, 0, HEADER_HEIGHT, this.width, 0).addClass("nodes");
		if (!hasHeader && color != null) {
			bg.css("fill", color);
		}

		if (node.canHavePreview()) {
			closePreviewBtn = editor.foreignObject(element, width / 2 - 16, 0, 32,32);
			closePreviewBtn.append(new JQuery('<div class="close-preview"><span class="ico"></span></div>'));

			refreshCloseIcon();
			closePreviewBtn.on("click", (e) -> {
				e.stopPropagation();
				setPreviewVisibility(!node.showPreview);
			});
		}
		//editor.line(element, width/2, HEADER_HEIGHT, width/2, 0, {display: "none"}).addClass("nodes-separator");
	}

	public function setPreviewVisibility(visible: Bool) {
		nodeInstance.showPreview = visible;
		refreshCloseIcon();
	}

	function refreshCloseIcon() {
		if (closePreviewBtn == null)
			return;
		closePreviewBtn.find(".ico").toggleClass("ico-angle-down", !nodeInstance.showPreview);
		closePreviewBtn.find(".ico").toggleClass("ico-angle-up", nodeInstance.showPreview);
	}

	public function addInput(editor : SVG, name : String, valueDefault : String = null, type : hxsl.Ast.Type) {
		var node = editor.group(element).addClass("input-node-group");
		var nodeHeight = HEADER_HEIGHT + NODE_MARGIN * (inputs.length+1) + NODE_RADIUS * inputs.length;
		var style = {fill : ""}
		style.fill = defaultColor;

		if (type != null) {
			switch (type) {
				case TBool:
					style.fill = boolColor;
				case TFloat:
					style.fill = floatColor;
				case TVec(size, _):
					switch (size) {
						case 2:
							style.fill = vec2Color;
						case 3:
							style.fill = vec3Color;
						case 4:
							style.fill = vec4Color;
					}
				case TSampler(_):
					style.fill = samplerColor;
				default:
			}
		}

		var nodeCircle = editor.circle(node, 0, nodeHeight, NODE_RADIUS, style).addClass("node input-node");

		var nameWidth = 0.0;
		if (name.length > 0) {
			var inputName = editor.text(node, NODE_TITLE_PADDING, nodeHeight + 4, name).addClass("title-node");
			var domName : js.html.svg.GraphicsElement = cast inputName.get()[0];
			nameWidth = domName.getBBox().width;
		}
		if (valueDefault != null) {
			var widthInput = width / 2 * 0.7;
			var fObject = editor.foreignObject(
				node,
				nameWidth + NODE_TITLE_PADDING + NODE_INPUT_PADDING,
				nodeHeight - 9,
				widthInput,
				20
			).addClass("input-field");
			new Element('<input type="text" style="width: ${widthInput - 7}px" value="${valueDefault}" />')
				.mousedown((e) -> e.stopPropagation())
				.appendTo(fObject);
		}

		inputs.push(nodeCircle);
		refreshHeight();

		return node;
	}

	public function addOutput(editor : SVG, name : String, ?type : hxsl.Ast.Type) {
		var node = editor.group(element).addClass("output-node-group");
		var nodeHeight = HEADER_HEIGHT + NODE_MARGIN * (outputs.length+1) + NODE_RADIUS * outputs.length;
		var style = {fill : ""}

		style.fill = defaultColor;
		if (type != null) {
			switch (type) {
				case TBool:
					style.fill = boolColor;
				case TInt:
					style.fill = intColor;
				case TFloat:
					style.fill = floatColor;
				case TVec(size, t):
					if (size == 2)
						style.fill = vec2Color;
					else if (size == 3)
						style.fill = vec3Color;
					else if (size == 4)
						style.fill = vec4Color;
				case TSampler(_):
					style.fill = samplerColor;
				default:
			}
		}

		var nodeCircle = editor.circle(node, width, nodeHeight, NODE_RADIUS, style).addClass("node output-node");

		if (name.length > 0 && name != "output")
			editor.text(node, width - NODE_TITLE_PADDING - (name.length * 6.75), nodeHeight + 4, name).addClass("title-node");

		outputs.push(nodeCircle);

		refreshHeight();
		return node;
	}

	public function generateProperties(editor : SVG, config:  hide.Config) {
		var props = nodeInstance.getHTML(this.width, config);

		if (props.length == 0) return;

		if (!hadToShowInputs && inputs.length <= 1 && outputs.length <= 1) {
			element.find(".nodes").remove();
			element.find(".input-node-group > .title-node").html("");
			element.find(".output-node-group > .title-node").html("");
		}

		var children = propertiesGroup.children();
		if (children.length > 0) {
			for (c in children) {
				c.remove();
			}
		}

		// create properties box
		var bgParam = editor.rect(propertiesGroup, 0, 0, this.width, 0).addClass("properties");
		if (!hasHeader && color != null) bgParam.css("fill", color);
		propsHeight = 0;

		for (p in props) {
			var prop = editor.group(propertiesGroup).addClass("prop-group");
			prop.attr("transform", 'translate(0, ${propsHeight})');

			var propWidth = (p.width() > 0 ? p.width() : this.width);
			var fObject = editor.foreignObject(prop, (this.width - propWidth) / 2, 5, propWidth, p.height());
			p.appendTo(fObject);
			propsHeight += Std.int(p.outerHeight()) + 1;
		}

		propsHeight += 10;

		refreshHeight();
	}

	public function dispose() {
		element.remove();
	}

	function refreshHeight() {
		var height = getNodesHeight();
		element.find(".nodes").height(height);
		element.find(".outline").attr("height", getHeight()+2);
		if (inputs.length >= 1 && outputs.length >= 1) {
			element.find(".nodes-separator").attr("y2", HEADER_HEIGHT + height);
			element.find(".nodes-separator").show();
		} else if (!hadToShowInputs) {
			element.find(".nodes-separator").hide();
		}

		if (propertiesGroup != null) {
			propertiesGroup.attr("transform", 'translate(0, ${HEADER_HEIGHT + height})');
			propertiesGroup.find(".properties").attr("height", propsHeight);
		}

		closePreviewBtn?.attr("y",HEADER_HEIGHT + height + propsHeight - 16);
	}

	public function setPosition(x : Float, y : Float) {
		this.x = x;
		this.y = y;
		element.attr({transform: 'translate(${x} ${y})'});
	}

	public function setSelected(b : Bool) {
		selected = b;
		if (b) {
			element.removeClass("not-selected");
			element.addClass("selected");
		} else {
			element.removeClass("selected");
			element.addClass("not-selected");
		}
	}
	public function setTitle(str : String) {
		if (hasHeader) {
			element.find(".title-box").html(str);
		}
	}
	public function getId() {
		return this.nodeInstance.id;
	}
	public function getInstance() {
		return this.nodeInstance;
	}
	public function getX() {
		return this.x;
	}
	public function getY() {
		return this.y;
	}
	public function getWidth() {
		return this.width;
	}
	public function getNodesHeight() {
		var maxNb = Std.int(Math.max(inputs.length, outputs.length));
		if (!hadToShowInputs && maxNb <= 1 && propsHeight > 0) {
			return 0;
		}
		return NODE_MARGIN * (maxNb+1) + NODE_RADIUS * maxNb;
	}
	public function getHeight() {
		return HEADER_HEIGHT + getNodesHeight() + propsHeight;
	}
	public function getElement() {
		return element;
	}
}