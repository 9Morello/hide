package hrt.prefab;
import hxd.Math;

class Object3D extends Prefab {

	public var local3d : h3d.scene.Object = null;

	@:s @:range(0,400) public var x : Float = 0.0;
	@:s @:range(0,400) public var y : Float = 0.0;
	@:s @:range(0,400) public var z : Float = 0.0;

	@:s public var scaleX : Float = 1.0;
	@:s public var scaleY : Float = 1.0;
	@:s public var scaleZ : Float = 1.0;

	@:s public var rotationX : Float = 0.0;
	@:s public var rotationY : Float = 0.0;
	@:s public var rotationZ : Float = 0.0;

	@:s public var visible : Bool = true;

	#if editor
	public var editorIcon : h2d.ObjectFollower;
	#end

	public static inline function getLocal3d(prefab: Prefab) : h3d.scene.Object {
		var obj3d = Std.downcast(prefab, Object3D);
		if (obj3d != null)
			return obj3d.local3d;
		return null;
	}

	public function setTransform(mat : h3d.Matrix) {
		var rot = mat.getEulerAngles();
		x = mat.tx;
		y = mat.ty;
		z = mat.tz;
		var s = mat.getScale();
		scaleX = s.x;
		scaleY = s.y;
		scaleZ = s.z;
		rotationX = Math.radToDeg(rot.x);
		rotationY = Math.radToDeg(rot.y);
		rotationZ = Math.radToDeg(rot.z);
	}

	override function make( ?sh:hrt.prefab.Prefab.ContextMake) : Prefab {
		makeInstance();

		var old3d = shared.current3d;
		shared.current3d = local3d ?? shared.current3d;

		for (c in children)
			makeChild(c);

		shared.current3d = old3d;

		postMakeInstance();

		return this;
	}

	/* Override makeObject instead of this */
	override function makeInstance() : Void {
		local3d = makeObject(shared.current3d);
		if( local3d != null )
			local3d.name = name;
		updateInstance();
	}

	function makeObject(parent3d: h3d.scene.Object) : h3d.scene.Object {
		return new h3d.scene.Object(parent3d);
	}

	override function updateInstance(?propName : String ) {
		applyTransform();
		if (local3d != null) {
			local3d.name = name;
			local3d.visible = visible;
		}
	}

	public static var _ = Prefab.register("object", Object3D);

	public function saveTransform() {
		return { x : x, y : y, z : z, scaleX : scaleX, scaleY : scaleY, scaleZ : scaleZ, rotationX : rotationX, rotationY : rotationY, rotationZ : rotationZ };
	}

	public function applyTransform() {
		var o = local3d;
		if (o == null) return;
		o.x = x;
		o.y = y;
		o.z = z;
		o.scaleX = scaleX;
		o.scaleY = scaleY;
		o.scaleZ = scaleZ;
		o.setRotation(Math.degToRad(rotationX), Math.degToRad(rotationY), Math.degToRad(rotationZ));
	}

	public function getTransform( ?m: h3d.Matrix ) {
		if( m == null ) m = new h3d.Matrix();
		m.initScale(scaleX, scaleY, scaleZ);
		m.rotate(Math.degToRad(rotationX), Math.degToRad(rotationY), Math.degToRad(rotationZ));
		m.translate(x, y, z);
		return m;
	}

	public function localRayIntersection(ray : h3d.col.Ray ) : Float {
		return -1;
	}

	public function loadTransform(t) {
		x = t.x;
		y = t.y;
		z = t.z;
		scaleX = t.scaleX;
		scaleY = t.scaleY;
		scaleZ = t.scaleZ;
		rotationX = t.rotationX;
		rotationY = t.rotationY;
		rotationZ = t.rotationZ;
	}

	public function getAbsPos( followRefs : Bool = false ) {
		var p = parent;
		while( p != null ) {
			var obj = p.to(Object3D);
			if( obj == null ) {
				if( p.parent == null && followRefs ) {
					p = p.shared.parentPrefab;
					continue;
				}
				p = p.parent;
				continue;
			}
			var m = getTransform();
			var abs = obj.getAbsPos(followRefs);
			m.multiply3x4(m, abs);
			return m;
		}
		return getTransform();
	}

	/**
		Returns the list of all h3d.scene.Object with the given class contained
		by this prefab and all of it's children
	**/
	public function getObjects<T:h3d.scene.Object>(c: Class<T> ) : Array<T> {
		var root = Object3D.getLocal3d(this);
		if(root == null) return [];
		var childObjs = Prefab.getChildrenRoots(root, this, []);
		var ret = [];
		function rec(o : h3d.scene.Object) {
			var m = Std.downcast(o, c);
			if(m != null) {
				ret.push(m);
			}
			for( child in o )
				if( childObjs.indexOf(child) < 0 )
					rec(child);
		}
		rec(root);
		return ret;
	}

	public function getDisplayFilters() : Array<String> {
		return [];
	}

#if editor
	override function setSelected(b:Bool):Bool {
		if (local3d == null)
			return true;

		var materials = local3d.getMaterials();

		if( !b ) {
			for( m in materials ) {
				//m.mainPass.stencil = null;
				m.removePass(m.getPass("highlight"));
				m.removePass(m.getPass("highlightBack"));
			}
			return true;
		}

		var shader = new h3d.shader.FixedColor(0xffffff);
		var shader2 = new h3d.shader.FixedColor(0xff8000);
		for( m in materials ) {
			if( m.name != null && StringTools.startsWith(m.name,"$UI.") )
				continue;
			var p = m.allocPass("highlight");
			p.culling = None;
			p.depthWrite = false;
			p.depthTest = LessEqual;
			p.addShader(shader);
			var p = m.allocPass("highlightBack");
			p.culling = None;
			p.depthWrite = false;
			p.depthTest = Always;
			p.addShader(shader2);
		}
		return true;
	}

	public function addEditorUI(ctx : hide.prefab.EditContext) {
		var objs = findAll(Object3D, true);
		for( obj in objs ) {
			var local3d : h3d.scene.Object = obj.local3d;
			if( local3d != null && local3d.name != null && StringTools.startsWith(local3d.name,"$UI.") )
				local3d.remove();
		}
		// add ranges

			var sheet = getCdbType();
			if( sheet != null ) {
				var ide = hide.Ide.inst;
			var ranges = Reflect.field(ctx.scene.config.get("sceneeditor.ranges"), sheet);
				if( ranges != null ) {
					for( key in Reflect.fields(ranges) ) {
						var color = Std.parseInt(Reflect.field(ranges,key));
						var value : Dynamic = hide.comp.cdb.DataFiles.resolveCDBValue(sheet,key, props);
						if( value != null ) {
						var mesh = new h3d.scene.Mesh(hrt.prefab.l3d.Spray.makePrimCircle(128, 0.99), local3d);
							mesh.name = "$UI.RANGE";
							mesh.ignoreCollide = true;
							mesh.ignoreBounds = true;
							mesh.material.mainPass.culling = None;
							mesh.material.name = "$UI.RANGE";
							mesh.setScale(value);
							mesh.scaleZ = 0.1;
							mesh.material.color.setColor(color|0xFF000000);
							mesh.material.mainPass.enableLights = false;
							mesh.material.shadows = false;
							mesh.material.mainPass.setPassName("overlay");
						}
					}
				}
			var huds : Dynamic = ctx.scene.config.get("sceneeditor.huds");
				var icon = Reflect.field(huds, sheet);
				if( icon != null ) {
					var t : Dynamic = hide.comp.cdb.DataFiles.resolveCDBValue(sheet,icon, props);
					if( t != null && (t.file != null || Std.isOfType(t,String)) ) {
					var obj = editorIcon;
					if( obj == null || obj.follow != local3d ) {
						editorIcon = obj = new h2d.ObjectFollower(local3d, shared.root2d);
							obj.horizontalAlign = Middle;
							obj.followVisibility = true;
						}
						if( t.file != null ) {
							var t : cdb.Types.TilePos = t;
							var bmp = Std.downcast(obj.getObjectByName("$huds"), h2d.Bitmap);
							var shouldAddInt = false;
							if( bmp == null ) {
								shouldAddInt = true;
								bmp = new h2d.Bitmap(null, obj);
								bmp.name = "$huds";
							}
						bmp.tile = h2d.Tile.fromTexture(shared.loadTexture(t.file)).sub(
								t.x * t.size,
								t.y * t.size,
								(t.width == null ? 1 : t.width) * t.size,
								(t.height == null ? 1 : t.height) * t.size
							);

							if (shouldAddInt) {
								var int = new h2d.Interactive(huds.maxWidth, huds.maxWidth, bmp);
								int.propagateEvents = false;
								int.x = bmp.tile.dx;
								int.y = bmp.tile.dy;

								int.onClick = function(e) {
									var editorContext = Std.downcast(shared, hide.prefab.ContextShared);
									if (editorContext != null)
										editorContext.editor.selectElements([ this ]);
								}
							}

							var maxWidth : Dynamic = huds.maxWidth;
							if( maxWidth != null && bmp.tile.width > maxWidth )
								bmp.width = maxWidth;
						} else {
							var f = Std.downcast(obj.getObjectByName("$huds_f"), h2d.Flow);
							if( f == null ) {
								f = new h2d.Flow(obj);
								f.name = "$huds_f";
								f.padding = 3;
								f.paddingTop = 1;
								f.backgroundTile = h2d.Tile.fromColor(0,1,1,0.5);
							}
							var tf = cast(f.getChildAt(1), h2d.Text);
							if( tf == null )
								tf = new h2d.Text(hxd.res.DefaultFont.get(), f);
							tf.text = t;
						}
					}
				}
			}
		}

	override function makeInteractive() : hxd.SceneEvents.Interactive {
		if(local3d == null)
			return null;
		var meshes = getObjects(h3d.scene.Mesh);
		var mesh = Std.downcast(local3d, h3d.scene.Mesh);
		if (mesh != null ) {
			meshes.push(mesh);
		}// ctx.shared.getObjects(this, h3d.scene.Mesh);
		var invRootMat = local3d.getAbsPos().clone();
		invRootMat.invert();
		var bounds = new h3d.col.Bounds();
		var localBounds = [];
		var totalSeparateBounds = 0.;
		var visibleMeshes = [];
		var hasSkin = false;

		inline function getVolume(b:h3d.col.Bounds) {
			var c = b.getSize();
			return c.x * c.y * c.z;
		}
		for(mesh in meshes) {
			if(mesh.ignoreCollide)
				continue;

			// invisible objects are ignored collision wise
			var p : h3d.scene.Object = mesh;
			while( p != local3d ) {
				if( !p.visible ) break;
				p = p.parent;
			}
			if( p != local3d ) continue;

			var localMat = mesh.getAbsPos().clone();
			localMat.multiply(localMat, invRootMat);

			if( mesh.primitive == null ) continue;
			visibleMeshes.push(mesh);

			if( Std.downcast(mesh, h3d.scene.Skin) != null ) {
				hasSkin = true;
				continue;
			}

			var asIcon = Std.downcast(mesh, hrt.impl.EditorTools.EditorIcon);
			if (asIcon != null) {
				hasSkin = true; // hack
				/*var pos = asIcon.getAbsPos();
				bounds.addSpherePos(pos.tx, pos.ty, pos.tz, asIcon.billboardScale);*/
				continue;
			}

			var asIcon = Std.downcast(mesh, hrt.impl.EditorTools.EditorIcon);
			if (asIcon != null) {
				hasSkin = true; // hack
				/*var pos = asIcon.getAbsPos();
				bounds.addSpherePos(pos.tx, pos.ty, pos.tz, asIcon.billboardScale);*/
				continue;
			}

			var lb = mesh.primitive.getBounds().clone();
			lb.transform(localMat);
			bounds.add(lb);

			totalSeparateBounds += getVolume(lb);
			for( b in localBounds ) {
				var tmp = new h3d.col.Bounds();
				tmp.intersection(lb, b);
				totalSeparateBounds -= getVolume(tmp);
			}
			localBounds.push(lb);
		}
		if( visibleMeshes.length == 0 )
			return null;
		var colliders = [for(m in visibleMeshes) {
			var c : h3d.col.Collider = try m.getGlobalCollider() catch(e: Dynamic) null;
			if(c != null) c;
		}];
		var meshCollider = colliders.length == 1 ? colliders[0] : new h3d.col.Collider.GroupCollider(colliders);
		var collider : h3d.col.Collider = new h3d.col.ObjectCollider(local3d, bounds);
		if( hasSkin ) {
			collider = meshCollider; // can't trust bounds
			meshCollider = null;
		} else if( totalSeparateBounds / getVolume(bounds) < 0.5 ) {
			collider = new h3d.col.Collider.OptimizedCollider(collider, meshCollider);
			meshCollider = null;
		}
		var int = new h3d.scene.Interactive(collider, local3d);
		int.ignoreParentTransform = true;
		int.preciseShape = meshCollider;
		int.propagateEvents = true;
		int.enableRightButton = true;
		return int;
	}

	override function edit( ctx : hide.prefab.EditContext ) {
		var props = new hide.Element('
			<div class="group" name="Position">
				<dl>
					<dt>X</dt><dd><input type="range" min="-10" max="10" value="0" field="x"/></dd>
					<dt>Y</dt><dd><input type="range" min="-10" max="10" value="0" field="y"/></dd>
					<dt>Z</dt><dd><input type="range" min="-10" max="10" value="0" field="z"/></dd>
					<dt>Scale</dt><dd><input type="multi-range" min="0" max="5" value="0" field="scale" data-subfields="X,Y,Z"/></dd>
					<dt>Rotation X</dt><dd><input type="range" min="-180" max="180" value="0" field="rotationX" /></dd>
					<dt>Rotation Y</dt><dd><input type="range" min="-180" max="180" value="0" field="rotationY" /></dd>
					<dt>Rotation Z</dt><dd><input type="range" min="-180" max="180" value="0" field="rotationZ" /></dd>
					<dt>Visible</dt><dd><input type="checkbox" field="visible"/></dd>
				</dl>
			</div>
		');
		ctx.properties.add(props, this, function(pname) {
			ctx.onChange(this, pname);
		});
	}

	override function getHideProps() : hide.prefab.HideProps {
		// Check children
		var cname = Type.getClassName(Type.getClass(this)).split(".").pop();
		return {
			icon : children == null || children.length > 0 ? "folder-open" : "genderless",
			name : cname == "Object3D" ? "Group" : cname,
		};
	}

#end // if editor
}