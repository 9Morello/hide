package hide.prefab.fx;
import hide.prefab.Curve;
import hide.prefab.Prefab as PrefabElement;

typedef ShaderAnimation = hide.prefab.Shader.ShaderAnimation;

enum Value {
	VZero;
	VConst(v: Float);
	VCurve(c: Curve);
	VCurveValue(c: Curve, scale: Float);
	VRandom(idx: Int, scale: Value);
	VAdd(a: Value, b: Value);
	VMult(a: Value, b: Value);
	VVector(x: Value, y: Value, z: Value, ?w: Value);
	VHsl(h: Value, s: Value, l: Value, a: Value);
	VBool(v: Value);
	VInt(v: Value);
}

class Evaluator {
	var randValues : Array<Float> = [];
	var random: hxd.Rand;

	public function new(random: hxd.Rand) {
		this.random = random;
	}

	public function getVal(val: Value, time: Float) : Dynamic {
		return null; // TODO?
	}

	public function getFloat(val: Value, time: Float) : Float {
		if(val == null)
			return 0.0;
		switch(val) {
			case VZero: return 0.0;
			case VConst(v): return v;
			case VCurve(c): return c.getVal(time);
			case VCurveValue(c, scale): return c.getVal(time) * scale;
			case VRandom(idx, scale):
				var len = randValues.length;
				while(idx >= len) {
					randValues.push(random.srand());
					++len;
				}
				return randValues[idx] * getFloat(scale, time);
			case VMult(a, b):
				return getFloat(a, time) * getFloat(b, time);
			case VAdd(a, b):
				return getFloat(a, time) + getFloat(b, time);
			default: 0.0;
		}
		return 0.0;
	}

	public function getSum(val: Value, time: Float) : Float {
		switch(val) {
			case VConst(v): return v * time;
			case VCurveValue(c, scale): return c.getSum(time) * scale;
			case VAdd(a, b):
				return getSum(a, time) + getSum(b, time);
			default: 0.0;
		}
		return 0.0;
	}

	public function getVector(v: Value, time: Float) : h3d.Vector {
		switch(v) {
			case VMult(a, b):
				var av = getVector(a, time);
				var bv = getVector(b, time);
				return new h3d.Vector(av.x * bv.x, av.y * bv.y, av.z * bv.z, av.w * bv.w);
			case VVector(x, y, z, null):
				return new h3d.Vector(getFloat(x, time), getFloat(y, time), getFloat(z, time), 1.0);
			case VVector(x, y, z, w):
				return new h3d.Vector(getFloat(x, time), getFloat(y, time), getFloat(z, time), getFloat(w, time));
			case VHsl(h, s, l, a):
				var hval = getFloat(h, time);
				var sval = getFloat(s, time);
				var lval = getFloat(l, time);
				var aval = getFloat(a, time);
				var col = new h3d.Vector(0,0,0,1);
				col.makeColor(hval, sval, lval);
				col.a = aval;
				return col;
			default:
				var f = getFloat(v, time);
				return new h3d.Vector(f, f, f, 1.0);
		}
	}
}

typedef ObjectAnimation = {
	elt: hide.prefab.Object3D,
	obj: h3d.scene.Object,
	?position: Value,
	?scale: Value,
	?rotation: Value,
	?color: Value,
	?visibility: Value
};

class FXAnimation extends h3d.scene.Object {
	
	public var duration : Float;
	public var objects: Array<ObjectAnimation> = [];
	public var shaderAnims : Array<ShaderAnimation> = [];
	public var emitters : Array<hide.prefab.fx.Emitter.EmitterObject> = [];
	var evaluator : Evaluator; 
	var random : hxd.Rand;

	public function new(?parent) {
		super(parent);
		random = new hxd.Rand(Std.random(0xFFFFFF));
		evaluator = new Evaluator(random);
	}

	public function setRandSeed(seed: Int) {
		random.init(seed);
		for(em in emitters) {
			em.setRandSeed(seed);
		}
	}

	static var tempMat = new h3d.Matrix();
	public function setTime(time: Float) {
		for(anim in objects) {
			var mat = getTransform(anim, time, tempMat);
			mat.multiply(mat, anim.elt.getTransform());
			anim.obj.setTransform(mat);

			if(anim.visibility != null)
				anim.obj.visible = evaluator.getFloat(anim.visibility, time) > 0.5;

			if(anim.color != null) {
				var mesh = Std.instance(anim.obj, h3d.scene.Mesh);
				var col = evaluator.getVector(anim.color, time);
				if(mesh != null) {
					mesh.material.color = col;
				}
			}
		}

		for(anim in shaderAnims) {
			anim.setTime(time);
		}

		for(i in 0...numChildren) {
			var child = getChildAt(i);
			if(child.currentAnimation != null) {
				var anim = child.currentAnimation;
				anim.loop = false;
				anim.pause = true;
				anim.setFrame(hxd.Math.clamp(time * anim.sampling * anim.speed, 0, anim.frameCount));
			}
		}

		for(em in emitters) {
			em.setTime(time);
		}
	}

	public function getTransform(anim: ObjectAnimation, time: Float, ?m: h3d.Matrix) {
		if(m == null)
			m = new h3d.Matrix();
	
		if(anim.scale != null) {
			var scale = evaluator.getVector(anim.scale, time);
			m.initScale(scale.x, scale.y, scale.z);
		}
		else
			m.identity();

		if(anim.rotation != null) {
			var rotation = evaluator.getVector(anim.rotation, time);
			rotation.scale3(Math.PI / 180.0);
			m.rotate(rotation.x, rotation.y, rotation.z);
		}

		if(anim.position != null) {
			var pos = evaluator.getVector(anim.position, time);
			m.translate(pos.x, pos.y, pos.z);
		}

		return m;
	}
}

class FXScene extends Library {

	public var duration : Float;

	public function new() {
		super();
		type = "fx";
		duration = 5.0;
	}

	override function save() {
		var obj : Dynamic = super.save();
		obj.duration = duration;
		return obj;
	}

	override function load( obj : Dynamic ) {
		super.load(obj);
		duration = obj.duration;
	}

	function getObjAnimations(ctx:Context, elt: PrefabElement, anims: Array<ObjectAnimation>) {
		if(Std.instance(elt, hide.prefab.fx.Emitter) == null) {
			// Don't extract animations for children of Emitters
			for(c in elt.children) {
				getObjAnimations(ctx, c, anims);
			}
		}

		var obj3d = elt.to(hide.prefab.Object3D);
		if(obj3d == null)
			return;

		var objCtx = ctx.shared.contexts.get(elt);
		if(objCtx == null || objCtx.local3d == null)
			return;

		var anyFound = false;

		function makeVal(name, def) : Value {
			var c = getCurve(elt, name);
			if(c != null)
				anyFound = true;
			return c != null ? VCurve(c) : def;
		}
		
		function makeVector(name: String, defVal: Float)  {
			var curves = hide.prefab.Curve.getCurves(elt, name);
			if(curves == null || curves.length == 0)
				return null;

			anyFound = true;
			return hide.prefab.Curve.getVectorValue(curves);
		}

		function makeColor(name: String)  {
			var curves = hide.prefab.Curve.getCurves(elt, name);
			if(curves == null || curves.length == 0)
				return null;

			anyFound = true;
			return hide.prefab.Curve.getColorValue(curves);
		}

		var anim : ObjectAnimation = {
			elt: obj3d,
			obj: objCtx.local3d,
			position: makeVector("position", 0.0),
			scale: makeVector("scale", 1.0),
			rotation: makeVector("rotation", 0.0),
			color: makeColor("color"),
			visibility: makeVal("visibility", null),
		};

		if(anyFound)
			anims.push(anim);
	}

	function getShaderAnims(ctx: Context, elt: PrefabElement, anims: Array<ShaderAnimation>) {
		if(Std.instance(elt, hide.prefab.fx.Emitter) == null) {
			for(c in elt.children) {
				getShaderAnims(ctx, c, anims);
			}
		}

		var shader = elt.to(hide.prefab.Shader);
		if(shader == null)
			return;

		var shCtx = ctx.shared.contexts.get(elt);
		if(shCtx == null || shCtx.custom == null)
			return;

		anims.push(cast shCtx.custom);
	}

	function getEmitters(ctx: Context, elt: PrefabElement, emitters: Array<hide.prefab.fx.Emitter.EmitterObject>) {
		var em = Std.instance(elt, hide.prefab.fx.Emitter);
		if(em != null)  {
			var emCtx = ctx.shared.contexts.get(elt);
			if(emCtx == null || emCtx.local3d == null)
				return;
			emitters.push(cast emCtx.local3d);
		}
		else {
			for(c in elt.children) {
				getEmitters(ctx, c, emitters);
			}
		}
	}

	override function makeInstance(ctx:Context):Context {
		if( inRec )
			return ctx;
		ctx = ctx.clone(this);
		var fxanim = new FXAnimation(ctx.local3d);
		fxanim.duration = duration;
		ctx.local3d = fxanim;
		super.makeInstance(ctx);
		getObjAnimations(ctx, this, fxanim.objects);
		getShaderAnims(ctx, this, fxanim.shaderAnims);
		getEmitters(ctx, this, fxanim.emitters);
		return ctx; 
	}

	override function edit( ctx : EditContext ) {
		#if editor
		var props = new hide.Element('
			<div class="group" name="FX Scene">
				<dl>
					<dt>Duration</dt><dd><input type="number" value="0" field="duration"/></dd>
				</dl>
			</div>');
		ctx.properties.add(props, this, function(pname) {
			ctx.onChange(this, pname);
		});
		#end
	}

	override function getHideProps() {
		return { icon : "cube", name : "FX", fileSource : ["fx"] };
	}

	static function getCurve(element : hide.prefab.Prefab, name: String) {
		for(c in element.children) {
			if(c.name != name) continue;
			var curve = c.to(Curve);
			if(curve == null) continue;
			return curve;
		}
		return null;
	}

	static var _ = Library.register("fx", FXScene);
}