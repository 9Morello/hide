package hrt.prefab.l3d;
import h3d.scene.Object;
import hrt.prefab.Context;
import hrt.prefab.Library;

class CameraSyncObject extends h3d.scene.Object {

	public var enable : Bool;
	public var fovY : Float;
	public var zFar : Float;
	public var zNear : Float;

	override function sync( ctx ) {
		if( enable ) {
			var c = getScene().camera;
			if( c != null ) {
				c.fovY = fovY;
				c.zFar = zFar;
				c.zNear = zNear;
			}
		}
	}
}

class Camera extends Object3D {

	@:s var fovY : Float = 45;
	@:s var zFar : Float = 200;
	@:s var zNear : Float = 0.02;
	@:s var showFrustum = false;
	var preview = false;

	public function new(?parent) {
		super(parent);
		type = "camera";
	}

	var g : h3d.scene.Graphics;
	function drawFrustum( ctx : Context ) {

		if( !showFrustum ) {
			if( g != null ) {
				g.remove();
				g = null;
			}
			return;
		}

		if( g == null ) {
			g = new h3d.scene.Graphics(ctx.local3d);
			g.name = "frustumDebug";
			g.material.mainPass.setPassName("overlay");
		}

		var c = new h3d.Camera();
		c.pos.set(0,0,0);
		c.target.set(1,0,0);
		c.fovY = fovY;
		c.zFar = zFar;
		c.zNear = zNear;
		c.update();

		var nearPlaneCorner = [c.unproject(-1, 1, 0), c.unproject(1, 1, 0), c.unproject(1, -1, 0), c.unproject(-1, -1, 0)];
		var farPlaneCorner = [c.unproject(-1, 1, 1), c.unproject(1, 1, 1), c.unproject(1, -1, 1), c.unproject(-1, -1, 1)];

		g.clear();
		g.lineStyle(1, 0xffffff);

		// Near Plane
		var last = nearPlaneCorner[nearPlaneCorner.length - 1];
		g.moveTo(last.x,last.y,last.z);
		for( fc in nearPlaneCorner ) {
			g.lineTo(fc.x, fc.y, fc.z);
		}

		// Far Plane
		var last = farPlaneCorner[farPlaneCorner.length - 1];
		g.moveTo(last.x,last.y,last.z);
		for( fc in farPlaneCorner ) {
			g.lineTo(fc.x, fc.y, fc.z);
		}

		// Connections
		for( i in 0 ... 4 ) {
			var np = nearPlaneCorner[i];
			var fp = farPlaneCorner[i];
			g.moveTo(np.x, np.y, np.z);
			g.lineTo(fp.x, fp.y, fp.z);
		}

		// Connections to camera pos
		g.lineStyle(1, 0xff0000);
		for( i in 0 ... 4 ) {
			var np = nearPlaneCorner[i];
			g.moveTo(np.x, np.y, np.z);
			g.lineTo(0, 0, 0);
		}
	}

	override function makeInstance( ctx : hrt.prefab.Context ) {
		ctx = ctx.clone(this);
		ctx.local3d = new CameraSyncObject(ctx.local3d);
		ctx.local3d.name = name;
		updateInstance(ctx);
		return ctx;
	}

	override function updateInstance( ctx : hrt.prefab.Context, ?p ) {
		super.updateInstance(ctx, p);
		drawFrustum(ctx);
		var cso = Std.downcast(ctx.local3d, CameraSyncObject);
		if( cso != null ) {
			cso.fovY = fovY;
			cso.zFar = zFar;
			cso.zNear = zNear;
			cso.enable = preview;
		}
	}

	public function applyTo(c: h3d.Camera) {
		var front = getTransform().front();
		var ray = h3d.col.Ray.fromValues(x, y, z, front.x, front.y, front.z);
		c.pos.set(x, y, z);
		c.target = c.pos.add(front);

		// this does not change camera rotation but allows for better navigation in editor
		var plane = h3d.col.Plane.Z();
		var pt = ray.intersect(plane);
		if( pt != null && pt.sub(c.pos.toPoint()).length() > 1 )
			c.target = pt.toVector();

		c.fovY = fovY;
		c.zFar = zFar;
		c.zNear = zNear;
	}

	function applyRFX(ctx : hrt.prefab.Context) {
		if (ctx.local3d.getScene() == null) return;
		var renderer = ctx.local3d.getScene().renderer;
		if (renderer == null) return;
		if (preview) {

			for ( effect in getAll(hrt.prefab.rfx.RendererFX) ) {
				var prevEffect = renderer.getEffect(hrt.prefab.rfx.RendererFX);
				if ( prevEffect != null )
					renderer.effects.remove(prevEffect);
				renderer.effects.push( effect );
			}
		}
		else {
			for ( effect in getAll(hrt.prefab.rfx.RendererFX) )
				renderer.effects.remove( effect );
		}
	}

	#if editor

	dynamic function setEditModeButton() {

	}

	override function setSelected( ctx : Context, b : Bool ) {
		updateInstance(ctx);
		setEditModeButton();
		return false;
	}

	override function edit( ctx : hide.prefab.EditContext ) {
		super.edit(ctx);

		var props : hide.Element = ctx.properties.add(new hide.Element('
			<div class="group" name="Camera">
				<dl>
					<dt>Fov Y</dt><dd><input type="range" min="0" max="180" field="fovY"/></dd>
					<dt>Z Far</dt><dd><input type="range" min="0" max="1000" field="zFar"/></dd>
					<dt>Z Near</dt><dd><input type="range" min="0" max="10" field="zNear"/></dd>
					<dt></dt><dd><input class="copy" type="button" value="Copy Current"/></dd>
					<dt></dt><dd><input class="apply" type="button" value="Apply" /></dd>
					<dt></dt><dd><input class="reset" type="button" value="Reset" /></dd>
				</dl>
			</div>
			<div class="group" name="Debug">
				<dl>
					<dt>Show Frustum</dt><dd><input type="checkbox" field="showFrustum"/></dd>
					<div align="center">
						<input type="button" value="Preview Mode : Disabled" class="editModeButton" />
					</div>
				</dl>
			</div>
		'),this, function(pname) {
			ctx.onChange(this, pname);
		});

		var editModeButton = props.find(".editModeButton");
		setEditModeButton = function () {
			editModeButton.val(preview ? "Preview Mode : Enabled" : "Preview Mode : Disabled");
			editModeButton.toggleClass("editModeEnabled", preview);
		};
		editModeButton.click(function(_) {
			preview = !preview;
			setEditModeButton();
			var cam = ctx.scene.s3d.camera;
			if (preview) {
				updateInstance(ctx.getContext(this));
				applyTo(cam);
				for ( effect in getAll(hrt.prefab.rfx.RendererFX) ) {
					var prevEffect = @:privateAccess ctx.scene.s3d.renderer.getEffect(hrt.prefab.rfx.RendererFX);
					if ( prevEffect != null )
						ctx.scene.s3d.renderer.effects.remove(prevEffect);
					ctx.scene.s3d.renderer.effects.push( effect );
				}
				ctx.scene.editor.cameraController.lockZPlanes = true;
				ctx.scene.editor.cameraController.loadFromCamera();
			}
			else {
				for ( effect in getAll(hrt.prefab.rfx.RendererFX) )
					ctx.scene.s3d.renderer.effects.remove( effect );
				ctx.makeChanges(this, function() {
					var transform = new h3d.Matrix();
					transform.identity();
					var q = new h3d.Quat();
					q.initDirection(cam.target.sub(cam.pos));
					var angles = q.toEuler();
					transform.rotate(angles.x, angles.y, angles.z);
					transform.translate(cam.pos.x, cam.pos.y, cam.pos.z);

					var parent = getParent(hrt.prefab.Object3D);
					if ( parent != null ) {
						var invPos = new h3d.Matrix();
						invPos._44 = 0;
						invPos.inverse3x4(parent.getAbsPos());
						transform.multiply(transform, invPos);
					}
					setTransform(transform);
					this.zFar = cam.zFar;
					this.zNear = cam.zNear;
					this.fovY = cam.fovY;
				});
			}
		});

		props.find(".copy").click(function(e) {
			var cam = ctx.scene.s3d.camera;
			ctx.makeChanges(this, function() {
				var transform = new h3d.Matrix();
				transform.identity();
				var q = new h3d.Quat();
				q.initDirection(cam.target.sub(cam.pos));
				var angles = q.toEuler();
				transform.rotate(angles.x, angles.y, angles.z);
				transform.translate(cam.pos.x, cam.pos.y, cam.pos.z);

				var parent = getParent(hrt.prefab.Object3D);
				if ( parent != null ) {
					var invPos = new h3d.Matrix();
					invPos._44 = 0;
					invPos.inverse3x4(parent.getAbsPos());
					transform.multiply(transform, invPos);
				}
				setTransform(transform);
				this.zFar = cam.zFar;
				this.zNear = cam.zNear;
				this.fovY = cam.fovY;
			});
		});


		props.find(".apply").click(function(e) {
			applyTo(ctx.scene.s3d.camera);
			ctx.scene.editor.cameraController.lockZPlanes = true;
			ctx.scene.editor.cameraController.loadFromCamera();
		});

		props.find(".reset").click(function(e) {
			ctx.scene.editor.resetCamera();
		});
	}

	override function getHideProps() : hide.prefab.HideProps {
		return { icon : "video-camera", name : "Camera" };
	}
	#end

	static var _ = Library.register("camera", Camera);

}
