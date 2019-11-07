package hrt.prefab.l3d;

import h3d.Vector;
import hxd.Key as K;

class MeshSpray extends Object3D {

	#if editor

	var meshes : Array<String> = [];
	var sceneEditor : hide.comp.SceneEditor;

	var density : Int = 10;
	var densityOffset : Int = 0;
	var radius : Float = 10.0;
	var scale : Float = 1.0;
	var scaleOffset : Float = 0.1;
	var rotation : Float = 0.0;
	var rotationOffset : Float = 0.0;

	var dontRepeatMesh : Bool = false;
	var lastIndexMesh = -1;

	var sprayEnable : Bool = false;
	var interactive : h2d.Interactive;
	var gBrush : h3d.scene.Mesh;

	var timerCicle : haxe.Timer;

	var lastSpray : Float = 0;

	#end

	public function new( ?parent ) {
		super(parent);
		type = "meshBatch";
	}

	#if editor

	override function save() {
		var obj : Dynamic = super.save();
		obj.meshes = meshes;
		obj.dontRepeatMesh = dontRepeatMesh;
		obj.density = density;
		obj.densityOffset = densityOffset;
		obj.radius = radius;
		obj.scale = scale;
		obj.scaleOffset = scaleOffset;
		obj.rotation = rotation;
		obj.rotationOffset = rotationOffset;
		return obj;
	}

	override function load( obj : Dynamic ) {
		super.load(obj);
		if (obj.meshes != null)
			meshes = obj.meshes;
		if (obj.density != null)
			density = obj.density;
		if (obj.densityOffset != null)
			densityOffset = obj.densityOffset;
		if (obj.radius != null)
			radius = obj.radius;
		if (obj.scale != null)
			scale = obj.scale;
		if (obj.scaleOffset != null)
			scaleOffset = obj.scaleOffset;
		if (obj.rotation != null)
			rotation = obj.rotation;
		if (obj.rotationOffset != null)
			rotationOffset = obj.rotationOffset;
		dontRepeatMesh = obj.dontRepeatMesh;
	}

	override function getHideProps() : HideProps {
		return { icon : "paint-brush", name : "MeshSpray" };
	}

	function extractMeshName( path : String ) : String {
		if( path == null ) return "None";
		var childParts = path.split("/");
		return childParts[childParts.length - 1].split(".")[0];
	}

	var wasEdited = false;
	override function edit( ectx : EditContext ) {
		sceneEditor = ectx.scene.editor;


		var ctx = ectx.getContext(this);
		var s2d = @:privateAccess ctx.local2d.getScene();
		interactive = new h2d.Interactive(10000, 10000, s2d);
		interactive.propagateEvents = true;
		interactive.cancelEvents = false;

		interactive.onWheel = function(e) {

		};

		interactive.onPush = function(e) {
			e.propagate = false;
			sprayEnable = true;
			var worldPos = getMousePicker(s2d.mouseX, s2d.mouseY);
			addMeshesAround(ctx, worldPos);
		};

		interactive.onRelease = function(e) {
			e.propagate = false;
			sprayEnable = false;
			if (wasEdited)
				sceneEditor.refresh(Partial, () -> { });
			wasEdited = false;
		};

		interactive.onMove = function(e) {
			var worldPos = getMousePicker(s2d.mouseX, s2d.mouseY);

			drawCircle(ctx, worldPos.x, worldPos.y, worldPos.z, radius, 5, 16711680);

			if( K.isDown( K.MOUSE_LEFT) ) {
				e.propagate = false;

				if (sprayEnable) {

					if (lastSpray < Date.now().getTime() - 50) {
						if( K.isDown( K.SHIFT) ) {
							removeMeshesAround(ctx, worldPos);
						} else {
							addMeshesAround(ctx, worldPos);
						}
						lastSpray = Date.now().getTime();
					}
				}
			}
		};

		var props = new hide.Element('<div class="group" name="Meshes"></div>');
		var selectElement = new hide.Element('<select multiple size="6" style="width: 300px" ></select>').appendTo(props);
		for (m in meshes) {
			addMeshPath(m);
			selectElement.append(new hide.Element('<option value="${m}">${extractMeshName(m)}</option>'));
		}
		var options = new hide.Element('<div class="btn-list" align="center" ></div>').appendTo(props);

		var selectAllBtn = new hide.Element('<input type="button" value="Select all" />').appendTo(options);
		var addBtn = new hide.Element('<input type="button" value="Add" >').appendTo(options);
		var removeBtn = new hide.Element('<input type="button" value="Remove" />').appendTo(options);
		var cleanBtn = new hide.Element('<input type="button" value="Remove all meshes" /><br />').appendTo(options);
		var repeatMeshBtn = new hide.Element('<input type="checkbox" style="margin-bottom: -5px;margin-right: 5px;" >Don\'t repeat same mesh in a row</input>').appendTo(options);
		new hide.Element('<br /><b><i>Hold down SHIFT to remove meshes</i></b>').appendTo(options);

		repeatMeshBtn.on("change", function() {
			dontRepeatMesh = repeatMeshBtn.is(":checked");
		});
		repeatMeshBtn.prop("checked", dontRepeatMesh);

		selectAllBtn.on("click", function() {
			var options = selectElement.children().elements();
			for (opt in options) {
				opt.prop("selected", true);
			}
		});
		addBtn.on("click", function () {
			hide.Ide.inst.chooseFiles(["fbx"], function(path) {
				for( m in path ) {
					addMeshPath(m);
					selectElement.append(new hide.Element('<option value="$m">${extractMeshName(m)}</option>'));
				}
			});
		});
		removeBtn.on("click", function () {
			var options = selectElement.children().elements();
			for (opt in options) {
				if (opt.prop("selected")) {
					removeMeshPath(opt.val());
					opt.remove();
				}
			}
		});
		cleanBtn.on("click", function() {
			if (hide.Ide.inst.confirm("Are you sure to remove all meshes for this MeshSpray ?")) {
				sceneEditor.deleteElements(children.copy());
				sceneEditor.selectObjects([this]);
			}
		});

		ectx.properties.add(props, this, function(pname) {});

		var optionsGroup = new hide.Element('<div class="group" name="Options"><dl></dl></div>');
		optionsGroup.append(hide.comp.PropsEditor.makePropsList([
				{ name: "density", t: PInt(1, 25), def: density },
				{ name: "densityOffset", t: PInt(0, 10), def: densityOffset },
				{ name: "radius", t: PFloat(0, 50), def: radius },
				{ name: "scale", t: PFloat(0, 10), def: scale },
				{ name: "scaleOffset", t: PFloat(0, 1), def: scaleOffset },
				{ name: "rotation", t: PFloat(0, 180), def: rotation },
				{ name: "rotationOffset", t: PFloat(0, 30), def: rotationOffset }
			]));
		ectx.properties.add(optionsGroup, this, function(pname) {  });
	}

	override function setSelected( ctx : Context, b : Bool ) {

		if (timerCicle != null) {
			timerCicle.stop();
		}
		if( !b ) {
			if( interactive != null ) interactive.remove();
			timerCicle = new haxe.Timer(100);
			timerCicle.run = function() {
				timerCicle.stop();
				gBrush.visible = false;
			};
		}
	}

	function addMeshPath(path : String) {
		if (meshes.indexOf(path) == -1)
			meshes.push(path);
	}

	function removeMeshPath(path : String) {
		meshes.remove(path);
	}

	var localMat = new h3d.Matrix();
	function addMeshesAround(ctx : Context, point : h3d.col.Point) {
		if (meshes.length == 0) {
			throw "There is no meshes";
		}
		var nbMeshesInZone = 0;
		var vecRelat = point.toVector();
		var transform = this.getTransform().clone();
		transform.invert();
		vecRelat.transform3x4(transform);
		var point2d = new h2d.col.Point(vecRelat.x, vecRelat.y);

		var computedDensity = density + Std.random(densityOffset+1);

		var minDistanceBetweenMeshesSq = (radius * radius / computedDensity);

		var currentPivots : Array<h2d.col.Point> = [];
		inline function distance(x1 : Float, y1 : Float, x2 : Float, y2 : Float) return (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
		var fakeRadius = radius * radius + minDistanceBetweenMeshesSq;
		for (child in children) {
			var model = child.to(hrt.prefab.Object3D);
			if (distance(point2d.x, point2d.y, model.x, model.y) < fakeRadius) {
				nbMeshesInZone++;
				currentPivots.push(new h2d.col.Point(model.x, model.y));
			}
		}
		var nbMeshesToPlace = computedDensity - nbMeshesInZone;
		if (nbMeshesToPlace > 0) {
			var models : Array<hrt.prefab.Prefab> = [];

			var random = new hxd.Rand(Std.random(0xFFFFFF));

			while (nbMeshesToPlace-- > 0) {
				var nbTry = 5;
				var position : h3d.col.Point;
				do {
					var randomRadius = radius*Math.sqrt(random.rand());
					var angle = random.rand() * 2*Math.PI;

					position = new h3d.col.Point(point.x + randomRadius*Math.cos(angle), point.y + randomRadius*Math.sin(angle), 0);
					var vecRelat = position.toVector();
					vecRelat.transform3x4(transform);

					var isNextTo = false;
					for (cPivot in currentPivots) {
						if (distance(vecRelat.x, vecRelat.y, cPivot.x, cPivot.y) <= minDistanceBetweenMeshesSq) {
							isNextTo = true;
							break;
						}
					}
					if (!isNextTo) {
						break;
					}
				} while (nbTry-- > 0);

				var randRotationOffset = random.rand() * rotationOffset;
				if (Std.random(2) == 0) {
					randRotationOffset *= -1;
				}
				var rotationZ = ((rotation  + randRotationOffset) % 360)/360 * 2*Math.PI;

				var model = new hrt.prefab.Model(this);
				var meshId = -1;
				if (dontRepeatMesh && lastIndexMesh != -1 && meshes.length > 0) {
					meshId = Std.random(meshes.length-1);
					if (meshId >= lastIndexMesh) {
						meshId++;
					}
				} else {
					meshId = Std.random(meshes.length);
				}
				lastIndexMesh = meshId;
				model.source = meshes[meshId];
				model.name = extractMeshName(model.source);

				localMat.initRotationZ(rotationZ);

				var randScaleOffset = random.rand() * scaleOffset;
				if (Std.random(2) == 0) {
					randScaleOffset *= -1;
				}
				var currentScale = (scale + randScaleOffset);

				localMat.scale(currentScale, currentScale, currentScale);

				position.z = getZ(position.x, position.y);
				localMat.setPosition(new Vector(position.x, position.y, position.z));

				var invParent = getTransform().clone();
				invParent.invert();
				localMat.multiply(localMat, invParent);

				model.setTransform(localMat);

				models.push(model);
				currentPivots.push(new h2d.col.Point(model.x, model.y));
			}

			if (models.length > 0) {
				wasEdited = true;
				sceneEditor.addObject(models, false, false);
			}

		}
	}

	function removeMeshesAround(ctx : Context, point : h3d.col.Point) {
		var vecRelat = point.toVector();
		var transform = this.getTransform().clone();
		transform.invert();
		vecRelat.transform3x4(transform);
		var point2d = new h2d.col.Point(vecRelat.x, vecRelat.y);

		var childToRemove = [];
		inline function distance(x1 : Float, y1 : Float, x2 : Float, y2 : Float) return (x1 - x2) * (x1 - x2) + (y1 - y2) * (y1 - y2);
		var fakeRadius = radius * radius;
		for (child in children) {
			var model = child.to(hrt.prefab.Object3D);
			if (distance(point2d.x, point2d.y, model.x, model.y) < fakeRadius) {
				childToRemove.push(child);
			}
		}
		if (childToRemove.length > 0) {
			wasEdited = true;
			sceneEditor.deleteElements(childToRemove, () -> { }, false);
			sceneEditor.selectObjects([this]);
		}
	}

	public function drawCircle(ctx : Context, originX : Float, originY : Float, originZ : Float, radius: Float, thickness: Float, color) {
		if (gBrush == null || gBrush.scaleX != radius) {
			if (gBrush != null) gBrush.remove();
			gBrush = new h3d.scene.Mesh(makePrimCircle(32, 0.98), ctx.local3d);
			gBrush.scaleX = gBrush.scaleY = radius;
			gBrush.material.mainPass.setPassName("overlay");
			gBrush.material.shadows = false;
			gBrush.material.color = h3d.Vector.fromColor(color);
			gBrush.material.color.w = 0.2;
			gBrush.material.blendMode = AlphaAdd;
		}
		gBrush.visible = true;
		gBrush.x = originX;
		gBrush.y = originY;
		gBrush.z = originZ+0.1;
	}

	function makePrimCircle(segments: Int, inner : Float = 0, rings : Int = 0) {
		var points = [];
		var uvs = [];
		var indices = [];
		++segments;
		var anglerad = hxd.Math.degToRad(360);
		for(i in 0...segments) {
			var t = i / (segments - 1);
			var a = hxd.Math.lerp(-anglerad/2, anglerad/2, t);
			var ct = hxd.Math.cos(a);
			var st = hxd.Math.sin(a);
			for(r in 0...(rings + 2)) {
				var v = r / (rings + 1);
				var r = hxd.Math.lerp(inner, 1.0, v);
				points.push(new h2d.col.Point(ct * r, st * r));
				uvs.push(new h2d.col.Point(t, v));
			}
		}
		for(i in 0...segments-1) {
			for(r in 0...(rings + 1)) {
				var idx = r + i * (rings + 2);
				var nxt = r + (i + 1) * (rings + 2);
				indices.push(idx);
				indices.push(idx + 1);
				indices.push(nxt);
				indices.push(nxt);
				indices.push(idx + 1);
				indices.push(nxt + 1);
			}
		}

		var verts = [for(p in points) new h3d.col.Point(p.x, p.y, 0.)];
		var idx = new hxd.IndexBuffer();
		for(i in indices)
			idx.push(i);
		var primitive = new h3d.prim.Polygon(verts, idx);
		primitive.normals = [for(p in points) new h3d.col.Point(0, 0, 1.)];
		primitive.tangents = [for(p in points) new h3d.col.Point(0., 1., 0.)];
		primitive.uvs = [for(uv in uvs) new h3d.prim.UV(uv.x, uv.y)];
		primitive.colors = [for(p in points) new h3d.col.Point(1,1,1)];
		primitive.incref();
		return primitive;
	}

	var terrainPrefab : hrt.prefab.terrain.Terrain = null;
	
	// GET Z with TERRAIN
	public function getZ( x : Float, y : Float ) {
		var z = this.z;

		if (terrainPrefab == null)
			@:privateAccess terrainPrefab = sceneEditor.sceneData.find(p -> Std.downcast(p, hrt.prefab.terrain.Terrain));

		if(terrainPrefab != null){
			var pos = new h3d.Vector(x, y, 0);
			pos.transform3x4(this.getTransform());
			z = terrainPrefab.terrain.getHeight(pos.x, pos.y);
		}

		return z;
	}

	public function  getMousePicker( ?x, ?y ) {
		var camera = sceneEditor.scene.s3d.camera;
		var ray = camera.rayFromScreen(x, y);
		var planePt = ray.intersect(h3d.col.Plane.Z());
		var offset = ray.getDir();

		// Find rough intersection point in the camera forward direction to get first collision point
		final maxZBounds = 25;
		offset.scale(maxZBounds);
		var pt = planePt.clone();
		pt.load(pt.sub(offset));

		var step = ray.getDir();
		step.scale(0.25);

		while(pt.z > -maxZBounds) {
			var z = getZ(pt.x, pt.y);
			if(pt.z < z)
				break;
			pt.load(pt.add(step));
		}

		// Bissect search for exact intersection point
		for(_ in 0...50) {
			var z = getZ(pt.x, pt.y);
			var delta = z - pt.z;
			if(hxd.Math.abs(delta) < 0.05)
				return pt;

			if(delta < 0)
				pt.load(pt.add(step));
			else
				pt.load(pt.sub(step));

			step.scale(0.5);
		}

		return planePt;
	}
	

	public function screenToWorld(sx: Float, sy: Float) {
		var camera = sceneEditor.scene.s3d.camera;
		var ray = camera.rayFromScreen(sx, sy);
		var dist = projectToGround(ray);
		if(dist >= 0) {
			return ray.getPoint(dist);
		}
		return null;
	}

	function projectToGround( ray: h3d.col.Ray ) {
		var dist = 0.0;
		if (terrainPrefab == null)
			@:privateAccess terrainPrefab = sceneEditor.sceneData.find(p -> Std.downcast(p, hrt.prefab.terrain.Terrain));
		
		if (terrainPrefab != null) {
			var normal = terrainPrefab.terrain.getAbsPos().up();
			var plane = h3d.col.Plane.fromNormalPoint(normal.toPoint(), new h3d.col.Point(terrainPrefab.terrain.getAbsPos().tx, terrainPrefab.terrain.getAbsPos().ty, terrainPrefab.terrain.getAbsPos().tz));
			var pt = ray.intersect(plane);
			if(pt != null) { dist = pt.sub(ray.getPos()).length();}
		}
		return dist;
	}

	#end

	static var _ = Library.register("meshSpray", MeshSpray);
}