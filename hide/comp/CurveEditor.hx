package hide.comp;

class CurveEditor extends Component {

	public var xScale = 200.;
	public var yScale = 30.;
	public var xOffset = 0.;
	public var yOffset = 0.;

	public var curve : hide.prefab.Curve;
	public var undo : hide.ui.UndoHistory;

	var svg : hide.comp.SVG;
	var width = 0;
	var height = 0;
	var gridGroup : Element;
	var graphGroup : Element;
	var selectGroup : Element;

	var refreshTimer : haxe.Timer = null;
	var lastValue : Dynamic;

	var selectedKeys: Array<hide.prefab.Curve.CurveKey> = [];

	public function new(parent, curve : hide.prefab.Curve, undo) {
		super(parent);
		this.undo = undo;
		this.curve = curve;
		var div = new Element("<div></div>");
		div.attr({ tabindex: "1" });
		div.css({ width: "100%", height: "100%" });

		div.appendTo(parent);
		div.focus();
		svg = new hide.comp.SVG(div);
		var root = svg.element;

		lastValue = haxe.Json.parse(haxe.Json.stringify(curve.save()));

		gridGroup = svg.group(root, "grid");
		graphGroup = svg.group(root, "graph");
		selectGroup = svg.group(root, "selection-overlay");

		root.resize((e) -> refresh());
		root.addClass("hide-curve-editor");
		root.mousedown(function(e) {
			var offset = root.offset();
			var px = e.clientX - offset.left;
			var py = e.clientY - offset.top;
			e.preventDefault();
			e.stopPropagation();
			div.focus();
			if(e.which == 1) {
				if(e.ctrlKey) {
					addPoint(ixt(px), iyt(py));
				}
				else {
					startSelectRect(px, py);
				}
			}
			else if(e.which == 2) {
				// Pan
				startPan(e);
			}
		});
		root.contextmenu(function(e) {
			e.preventDefault();
			return false;
		});
		root.on("mousewheel", function(e) {
			var step = e.originalEvent.wheelDelta > 0 ? 1.0 : -1.0;
			if(hxd.Key.isDown(hxd.Key.SHIFT))
				yScale *= Math.pow(1.125, step);
			else
				xScale *= Math.pow(1.125, step);
			refresh();
		});
		div.keydown(function(e) {
			if(e.keyCode == 46) {
				var newVal = [for(k in curve.keys) if(selectedKeys.indexOf(k) < 0) k];
				curve.keys = newVal;
				selectedKeys = [];
				e.preventDefault();
				e.stopPropagation();
				afterChange();
			}
		});
	}

	function addPoint(time: Float, ?val: Float) {
		var index = 0;
		for(ik in 0...curve.keys.length) {
			var key = curve.keys[ik];
			if(time > key.time)
				index = ik + 1;
		}

		if(val == null)
			val = curve.getVal(time);

		var key : hide.prefab.Curve.CurveKey = {
			time: time,
			value: val,
			mode: Linear
		};
		curve.keys.insert(index, key);
		afterChange();
	}

	function fixKey(key : hide.prefab.Curve.CurveKey) {
		var index = curve.keys.indexOf(key);
		var prev = curve.keys[index-1];
		var next = curve.keys[index+1];

		inline function addPrevH() {
			if(key.prevHandle == null)
				key.prevHandle = { dt: prev != null ? (prev.time - key.time) / 3 : -0.5, dv: 0};
		}
		inline function addNextH() {
			if(key.nextHandle == null)
				key.nextHandle = { dt: next != null ? (next.time - key.time) / 3 : -0.5, dv: 0};
		}
		switch(key.mode) {
			case Aligned:
				addPrevH();
				addNextH();
				var pa = hxd.Math.atan2(key.prevHandle.dv, key.prevHandle.dt);
				var na = hxd.Math.atan2(key.nextHandle.dv, key.nextHandle.dt);
				if(hxd.Math.abs(hxd.Math.angle(pa - na)) < Math.PI - (1./180.)) {
					key.nextHandle.dt = -key.prevHandle.dt;
					key.nextHandle.dv = -key.prevHandle.dv;
				}
			case Free:
				addPrevH();
				addNextH();
			case Linear:
				key.nextHandle = null;
				key.prevHandle = null;
			case Constant:
				key.nextHandle = null;
				key.prevHandle = null;
		}

		if(key.time < 0)
			key.time = 0;

		if(prev != null && key.time < prev.time)
			key.time = prev.time + 0.01;
		if(next != null && key.time > next.time)
			key.time = next.time - 0.01;

		if(next != null && key.nextHandle != null) {
			var slope = key.nextHandle.dv / key.nextHandle.dt;
			slope = hxd.Math.clamp(slope, -1000, 1000);
			if(key.nextHandle.dt + key.time > next.time) {
				key.nextHandle.dt = next.time - key.time;
				key.nextHandle.dv = slope * key.nextHandle.dt;
			}
		}
		if(prev != null && key.prevHandle != null) {
			var slope = key.prevHandle.dv / key.prevHandle.dt;
			slope = hxd.Math.clamp(slope, -1000, 1000);
			if(key.prevHandle.dt + key.time < prev.time) {
				key.prevHandle.dt = prev.time - key.time;
				key.prevHandle.dv = slope * key.prevHandle.dt;
			}
		}
	}

	function startSelectRect(p1x: Float, p1y: Float) {
		var offset = root.offset();
		var selX = p1x;
		var selY = p1y;
		var selW = 0.;
		var selH = 0.;
		startDrag(root, function(e) {
			var p2x = e.clientX - offset.left;
			var p2y = e.clientY - offset.top;
			selX = hxd.Math.min(p1x, p2x);
			selY = hxd.Math.min(p1y, p2y);
			selW = hxd.Math.abs(p2x-p1x);
			selH = hxd.Math.abs(p2y-p1y);
			selectGroup.empty();
			svg.rect(selectGroup, selX, selY, selW, selH);
		}, function(e) {
			selectGroup.empty();
			var minT = ixt(selX);
			var minV = iyt(selY);
			var maxT = ixt(selX + selW);
			var maxV = iyt(selY + selH);
			selectedKeys = [for(key in curve.keys)
				if(key.time >= minT && key.time <= maxT && key.value >= minV && key.value <= maxV) key];
			refresh();
		});
	}

	function startPan(e) {
		var lastX = e.clientX;
		var lastY = e.clientY;
		startDrag(root, function(e) {
			var dt = (e.clientX - lastX) / xScale;
			var dv = (e.clientY - lastY) / yScale;
			xOffset += dt;
			yOffset += dv;
			lastX = e.clientX;
			lastY = e.clientY;
			refresh(true);
		}, function(e) {
			refresh();
		});
	}

	inline function xt(x: Float) return Math.round((x + xOffset) * xScale);
	inline function yt(y: Float) return Math.round((y + yOffset) * yScale + height/2);
	inline function ixt(px: Float) return px / xScale - xOffset;
	inline function iyt(py: Float) return (py - height/2) / yScale - yOffset;

	function startDrag(el: Element, onMove, onStop) {
		el.mousemove(onMove);
		el.mouseup(function(e) {
			el.off("mousemove");
			el.off("mouseup");
			e.preventDefault();
			e.stopPropagation();
			onStop(e);
		});
	}

	function copyKey(key: hide.prefab.Curve.CurveKey): hide.prefab.Curve.CurveKey {
		return cast haxe.Json.parse(haxe.Json.stringify(key));
	}

	function afterChange() {
		var newVal = haxe.Json.parse(haxe.Json.stringify(curve.save()));
		var oldVal = lastValue;
		lastValue = newVal;
		undo.change(Custom(function(undo) {
			if(undo) {
				curve.load(oldVal);
			}
			else {
				curve.load(newVal);
			}
			lastValue = haxe.Json.parse(haxe.Json.stringify(curve.save()));
			selectedKeys = [];
			refresh();
		}));
		refresh();
	}

	public function resetView() {
		// var margin = 20;
		// var minT = ixt(-margin);
		// var maxT = ixt(width + margin);
		// var minV = iyt(0);
		// var maxV = iyt(height);
		// xOffset = minT;
		// xScale = (maxT - minT)
		// TODO
	}

	public function refresh(?anim: Bool = false, ?animKey: hide.prefab.Curve.CurveKey) {
		width = Math.round(svg.element.width());
		height = Math.round(svg.element.height());
		gridGroup.empty();
		graphGroup.empty();
		selectGroup.empty();

		if(refreshTimer != null)
			refreshTimer.stop();
		if(!anim) {
			refreshTimer = haxe.Timer.delay(function() {
				refreshTimer = null;
				untyped window.gc();
			}, 100);
		}

		var minX = Math.floor(ixt(0));
		var maxX = Math.ceil(ixt(width));
		var hgrid = svg.group(gridGroup, "hgrid");
		for(ix in minX...(maxX+1)) {
			var l = svg.line(hgrid, xt(ix), 0, xt(ix), height).attr({
				"shape-rendering": "crispEdges"
			});
			if(ix == 0)
				l.addClass("axis");
		}

		var minY = Math.floor(iyt(0));
		var maxY = Math.ceil(iyt(height));
		var vgrid = svg.group(gridGroup, "vgrid");
		for(iy in minY...(maxY+1)) {
			var l = svg.line(vgrid, 0, yt(iy), width, yt(iy)).attr({
				"shape-rendering": "crispEdges"
			});
			if(iy == 0)
				l.addClass("axis");
		}

		var curveGroup = svg.group(graphGroup, "curve");
		var vectorsGroup = svg.group(graphGroup, "vectors");
		var handlesGroup = svg.group(graphGroup, "handles");
		var tangentsHandles = svg.group(handlesGroup, "tangents");
		var keyHandles = svg.group(handlesGroup, "keys");
		var selection = svg.group(graphGroup, "selection");
		var size = 7;

		// Draw curve
		{
			var keys = curve.keys;
			var lines = ['M ${xt(keys[0].time)},${yt(keys[0].value)}'];
			for(ik in 1...keys.length) {
				var prev = keys[ik-1];
				var cur = keys[ik];
				lines.push('C
					${xt(prev.time + (prev.nextHandle != null ? prev.nextHandle.dt : 0.))}, ${yt(prev.value + (prev.nextHandle != null ? prev.nextHandle.dv : 0.))}
					${xt(cur.time + (cur.prevHandle != null ? cur.prevHandle.dt : 0.))}, ${yt(cur.value + (cur.prevHandle != null ? cur.prevHandle.dv : 0.))}
					${xt(cur.time)}, ${yt(cur.value)} ');
			}
			svg.make(curveGroup, "path", {d: lines.join("")});
			// var pts = curve.sample(200);
			// var poly = [];
			// for(i in 0...pts.length) {
			// 	var x = xt(curve.duration * i / (pts.length - 1));
			// 	var y = yt(pts[i]);
			// 	poly.push(new h2d.col.Point(x, y));
			// }
			// svg.polygon(curveGroup, poly);
		}


		function addRect(group, x: Float, y: Float) {
			return svg.rect(group, x - Math.floor(size/2), y - Math.floor(size/2), size, size).attr({
				"shape-rendering": "crispEdges"
			});
		}

		for(key in curve.keys) {
			var kx = xt(key.time);
			var ky = yt(key.value);
			var keyHandle = addRect(keyHandles, kx, ky);
			var selected = selectedKeys.indexOf(key) >= 0;
			if(selected)
				keyHandle.addClass("selected");
			if(!anim) {
				keyHandle.mousedown(function(e) {
					if(e.which != 1) return;
					e.preventDefault();
					e.stopPropagation();
					var offx = e.clientX - keyHandle.offset().left;
					var offy = e.clientY - keyHandle.offset().top;
					var offset = svg.element.offset();
					startDrag(root, function(e) {
						var lx = e.clientX - offset.left - offx;
						var ly = e.clientY - offset.top - offy;
						var nkx = ixt(lx);
						var nky = iyt(ly);
						key.time = nkx;
						key.value = nky;
						fixKey(key);
						refresh(true, key);
					}, function(e) {
						selectedKeys = [key];
						fixKey(key);
						afterChange();
					});
					selectedKeys = [key];
					refresh();
				});
				keyHandle.contextmenu(function(e) {
					e.preventDefault();
					function setMode(m: hide.prefab.Curve.CurveKeyMode) {
						key.mode = m;
						fixKey(key);
						refresh();
					}
					new ContextMenu([
						{ label : "Mode", menu :[
							{ label : "Aligned", checked: key.mode == Aligned, click : setMode.bind(Aligned) },
							{ label : "Free", checked: key.mode == Free, click : setMode.bind(Free) },
							{ label : "Linear", checked: key.mode == Linear, click : setMode.bind(Linear) },
							{ label : "Constant", checked: key.mode == Constant, click : setMode.bind(Constant) },
						] }
					]);
					return false;
				});
			}
			function addHandle(next: Bool) {
				var handle = next ? key.nextHandle : key.prevHandle;
				var other = next ? key.prevHandle : key.nextHandle;
				if(handle == null) return null;
				var px = xt(key.time + handle.dt);
				var py = yt(key.value + handle.dv);
				var line = svg.line(vectorsGroup, kx, ky, px, py);
				var circle = svg.circle(tangentsHandles, px, py, size/2);
				if(selected) {
					line.addClass("selected");
					circle.addClass("selected");
				}
				if(anim)
					return circle;
				circle.mousedown(function(e) {
					if(e.which != 1) return;
					e.preventDefault();
					e.stopPropagation();
					var offx = e.clientX - circle.offset().left;
					var offy = e.clientY - circle.offset().top;
					var offset = svg.element.offset();
					var otherLen = hxd.Math.distance(other.dt * xScale, other.dv * yScale);
					startDrag(root, function(e) {
						var lx = e.clientX - offset.left - offx;
						var ly = e.clientY - offset.top - offy;
						if(next && lx < kx || !next && lx > kx)
							lx = kx;
						var ndt = ixt(lx) - key.time;
						var ndv = iyt(ly) - key.value;
						handle.dt = ndt;
						handle.dv = ndv;
						if(key.mode == Aligned) {
							var angle = Math.atan2(ly - ky, lx - kx);
							other.dt = Math.cos(angle + Math.PI) * otherLen / xScale;
							other.dv = Math.sin(angle + Math.PI) * otherLen / yScale;
						}
						fixKey(key);
						refresh(true, key);
					}, function(e) {
						afterChange();
					});
				});
				return circle;
			}
			if(!anim || animKey == key) {
				var pHandle = addHandle(false);
				var nHandle = addHandle(true);
			}
		}

		if(selectedKeys.length > 1) {
			var bounds = new h2d.col.Bounds();
			for(key in selectedKeys)
				bounds.addPoint(new h2d.col.Point(xt(key.time), yt(key.value)));
			var margin = 12.5;
			bounds.xMin -= margin;
			bounds.yMin -= margin;
			bounds.xMax += margin;
			bounds.yMax += margin;
			var rect = svg.rect(selection, bounds.x, bounds.y, bounds.width, bounds.height).attr({
				"shape-rendering": "crispEdges"
			});
			if(!anim) {
				rect.mousedown(function(e) {
					if(e.which != 1) return;
					e.preventDefault();
					e.stopPropagation();
					var lastX = e.clientX;
					var lastY = e.clientY;
					startDrag(root, function(e) {
						var dx = e.clientX - lastX;
						var dy = e.clientY - lastY;
						for(key in selectedKeys) {
							key.time += dx / xScale;
							key.value += dy / yScale;
						}
						lastX = e.clientX;
						lastY = e.clientY;
						refresh(true);
					}, function(e) {
						afterChange();
					});
					refresh();
				});
			}
		}
	}
}