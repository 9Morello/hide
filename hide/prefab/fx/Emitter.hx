package hide.prefab.fx;
import hide.prefab.Curve;
import hide.prefab.fx.FXScene.Value;
import hide.prefab.fx.FXScene.Evaluator;
using Lambda;

@:enum abstract EmitShape(Int) {
	var Cone = 0;
	var Disc = 1;
	var Sphere = 2;

	inline function new(v) {
		this = v;
	}

	public inline function toInt() {
		return this;
	}

	public static inline function fromInt( v : Int ) : EmitShape {
		return new EmitShape(v);
	}
}

typedef ParamDef = {
	> hide.comp.PropsEditor.PropDef,  // TODO: Runtime-friendly version
	?noanim: Bool
}

typedef InstanceDef = {
	localSpeed: Value,
	localOffset: Value,
	scale: Value,
	rotation: Value,
}

typedef ShaderAnims = Array<hide.prefab.Shader.ShaderAnimation>;

@:allow(hide.prefab.fx.EmitterObject)
private class ParticleInstance extends h3d.scene.Object {
	var emitter : EmitterObject;
	var evaluator : Evaluator;
	public var life = 0.0;

	public var curVelocity = new h3d.Vector();
	public var orientation = new h3d.Quat();

	public var def : InstanceDef;
	public var shaderAnims : ShaderAnims;

	public function new(emitter: EmitterObject, def: InstanceDef) {
		super(emitter.parent);
		this.def = def;
		this.emitter = emitter;
		this.evaluator = new Evaluator(emitter.random);
		emitter.instances.push(this);
	}

	public function update(dt : Float) {
		var child = getChildAt(0);
		if(child == null)
			return;

		var t = hxd.Math.clamp(life / emitter.lifeTime, 0.0, 1.0);

		var localSpeed = evaluator.getVector(def.localSpeed, t);
		if(localSpeed.length() > 0.001) {
			localSpeed.transform3x3(orientation.toMatrix());
			curVelocity = localSpeed;
		}

		x += curVelocity.x * dt;
		y += curVelocity.y * dt;
		z += curVelocity.z * dt;

		var rot = evaluator.getVector(def.rotation, t);
		rot.scale3(Math.PI / 180.0);
		child.setRotation(rot.x, rot.y, rot.z);

		var offset = evaluator.getVector(def.localOffset, t);
		child.setPosition(offset.x, offset.y, offset.z);

		var scaleVec = evaluator.getVector(def.scale, t);
		child.scaleX = scaleVec.x;
		child.scaleY = scaleVec.y;
		child.scaleZ = scaleVec.z;

		for(anim in shaderAnims) {
			anim.setTime(t);
		}

		life += dt;
	}

	function faceCamera(cam : h3d.Camera) {
		var align = emitter.alignVec;
		if(align != null && align.lengthSq() > 0.01) {
			var local = align.clone();
			local.transform3x3(getAbsPos());
			local.normalize();
			var delta : h3d.Vector = cam.pos.sub(absPos.getPosition());
			delta.normalize();
			var axis = local.cross(delta);
			var l = axis.length();
			if(l > 0.01) {
				var angle = Math.asin(l);
				var q = new h3d.Quat();
				q.initRotateAxis(axis.x, axis.y, axis.z, angle);
				qRot.multiply(q, qRot);
				posChanged = true;
				calcAbsPos(); // Meh
			}
		}
	}

	override function sync( ctx : h3d.scene.RenderContext ) {
		faceCamera(ctx.camera);
	}

	function kill() {
		remove();
		emitter.instances.remove(this);
	}
}

@:allow(hide.prefab.fx.ParticleInstance)
@:allow(hide.prefab.fx.Emitter)
class EmitterObject extends h3d.scene.Object {

	public var particleTemplate : hide.prefab.Prefab;
	public var maxCount = 20;
	public var lifeTime = 2.0;
	public var emitShape : EmitShape = Disc;

	public var emitAngle : Value;
	public var emitRate : Value;
	public var emitSize : Value;
	public var alignVec: h3d.Vector;

	public var instDef : InstanceDef;

	public function new(?parent) {
		super(parent);
		random = new hxd.Rand(0);
		evaluator = new Evaluator(random);
		reset();
	}

	var random: hxd.Rand;
	var context : hide.prefab.Context;
	var emitCount = 0;
	var lastTime = -1.0;
	var curTime = 0.0;
	var evaluator : Evaluator;
	var instances : Array<ParticleInstance> = [];

	function reset() {
		random.init(0);
		curTime = 0.0;
		lastTime = 0.0;
		emitCount = 0;
		for(inst in instances.copy()) {
			inst.kill();
		}
	}

	function doEmit(count: Int) {
		if(count == 0)
			return;

		if(instDef == null || particleTemplate == null)
			return;
		
		var localMat = getAbsPos().clone();
		var parentInvMat = parent.getAbsPos().clone();
		parentInvMat.invert();
		localMat.multiply(localMat, parentInvMat);

		var shapeSize = evaluator.getFloat(emitSize, curTime);
		var shapeAngle = hxd.Math.degToRad(evaluator.getFloat(emitAngle, curTime)) / 2.0;
		
		var tmpq = new h3d.Quat();
		var offset = new h3d.Vector();
		var direction = new h3d.Vector();

		for(i in 0...count) {
			var part = new ParticleInstance(this, instDef);
			context.local3d = part;
			var ctx = particleTemplate.makeInstance(context);

			var localQuat = getRotationQuat().clone();

			switch(emitShape) {
				case Disc:
					var dx = 0.0, dy = 0.0;
					do {
						dx = random.srand(1.0);
						dy = random.srand(1.0);
					}
					while(dx * dx + dy * dy > 1.0);
					offset.set(0, dx, dy);
					direction.set(1, 0, 0);
				case Sphere:
					do {
						offset.x = random.srand(1.0);
						offset.y = random.srand(1.0);
						offset.z = random.srand(1.0);
					}
					while(offset.lengthSq() > 1.0);
					direction = offset.clone();
					direction.normalizeFast();
				case Cone:
					offset.set(0, 0, 0);
					var theta = random.rand() * Math.PI * 2;
					var phi = shapeAngle * random.rand();
					direction.x = Math.sin(phi) * Math.cos(theta);
					direction.y = Math.sin(phi) * Math.sin(theta);
					direction.z = Math.cos(phi);
					direction.normalizeFast();
			}

			tmpq.initDirection(direction);
			localQuat.multiply(localQuat, tmpq);

			part.setRotationQuat(localQuat);
			part.orientation = localQuat.clone();
			offset.transform(localMat);
			part.setPosition(offset.x, offset.y, offset.z);

			part.shaderAnims = [];
			var shaders = particleTemplate.getAll(hide.prefab.Shader);
			for(shader in shaders) {
				var shCtx = shader.makeInstance(ctx);
				if(shCtx == null)
					continue;
				var anim : hide.prefab.Shader.ShaderAnimation = cast shCtx.custom;
				if(anim != null) {
					part.shaderAnims.push(anim);
				}
			}

			var materials = particleTemplate.getAll(hide.prefab.Material);
			for(mat in materials) {
				mat.makeInstance(ctx);
			}
		}
		context.local3d = this;
		emitCount += count;
	}

	function tick(dt: Float) {
		var emitTarget = evaluator.getSum(emitRate, curTime);
		var delta = hxd.Math.floor(emitTarget - emitCount);
		doEmit(delta);

		var i = instances.length;
		while (i-- > 0) {
			if(instances[i].life > lifeTime) {
				instances[i].kill();
			}
			else {
				instances[i].update(dt);
			}
		}
		lastTime = curTime;
		curTime += dt;
	}

	public function setTime(time: Float) {
		if(time < lastTime || lastTime < 0) {
			reset();
		}

		var catchup = time - curTime;
		var numTicks = hxd.Math.round(hxd.Timer.wantedFPS * catchup);
		for(i in 0...numTicks) {
			tick(catchup / numTicks);
		}
	}
}


class Emitter extends Object3D {

	public function new(?parent) {
		super(parent);
		props = { };
	}

	static var emitterParams : Array<ParamDef> = [
		{
			name: "lifeTime",
			t: PFloat(0, 10),
			def: 1.0,
			noanim: true
		},
		{
			name: "maxCount",
			t: PInt(0, 100),
			def: 20,
			noanim: true,
		},
		{
			name: "emitShape",
			t: PChoice(["Cone", "Disc", "Sphere"]),
			noanim: true,
			disp: "Shape",
		},
		{
			name: "emitAngle",
			t: PFloat(0, 360.0),
			noanim: true,
			disp: "Angle",
		},
		{
			name: "emitRate",
			t: PInt(0, 100),
			def: 5,
			disp: "Rate",
		},
		{
			name: "emitSize",
			t: PFloat(0, 10),
			def: 1.0
		},
		{
			name: "camAlign",
			t: PVec(3, -1.0, 1.0),
			def: [0.,0.,0.]
		},
	];

	static var instanceParams : Array<ParamDef> = [
		{
			name: "speed",
			t: PVec(3, -10, 10),
			def: [5.,0.,0.]
		},
		{
			name: "scale",
			t: PVec(3),
			def: [1.,1.,1.]
		},
		{
			name: "rotation",
			t: PVec(3, 0, 360),
			def: [0.,0.,0.]
		},
		{
			name: "offset",
			t: PVec(3, -10, 10),
			def: [0.,0.,0.]
		}
	];

	static var PARAMS : Array<ParamDef> = {
		var a = emitterParams.copy();
		for(i in instanceParams)
			a.push(i);
		a;
	};

	override function save() {
		var obj : Dynamic = super.save();
		for(param in PARAMS) {
			if(Reflect.hasField(props, param.name)) {
				var f = Reflect.field(props, param.name);
				if(f != param.def) {
					Reflect.setField(obj, param.name, f);
				}
			}
		}
		return obj;
	}

	override function load( obj : Dynamic ) {
		super.load(obj);
		for(param in PARAMS) {
			if(Reflect.hasField(obj, param.name))
				Reflect.setField(props, param.name, Reflect.field(obj, param.name));
			else if(param.def != null)
				Reflect.setField(props, param.name, param.def);
		}
	}

	override function makeInstanceRec(ctx: Context) {
		ctx = makeInstance(ctx);
		// Don't make children, which are used to setup particles
	}

	static inline function randProp(name: String) {
		return name + "_rand";
	}

	function getParamVal(name: String, rand: Bool=false) : Dynamic {
		var param = PARAMS.find(p -> p.name == name);
		var isVector = switch(param.t) {
			case PVec(_): true;
			default: false;
		}
		var val : Dynamic = rand ? (isVector ? [0.,0.,0.,0.] : 0.) : param.def;
		if(rand)
			name = randProp(name);
		if(props != null && Reflect.hasField(props, name)) {
			val = Reflect.field(props, name);
		}
		if(isVector)
			return h3d.Vector.fromArray(val);
		return val;
	}

	public function applyParams(emitterObj: EmitterObject) {
		var randIdx = 0;
		var template = children[0];
		if(template == null)
			return;

		function makeVal(base: Float, curve: Curve, randFactor: Float, randCurve: Curve): Value {
			var val : Value = if(curve != null && base != 0.0)
				VCurveValue(curve, base);
			else if(base != 0.0)
				VConst(base);
			else VZero;

			if(randFactor != 0.0) {
				var randScale = randCurve != null ? VCurveValue(randCurve, randFactor) : VConst(randFactor);
				var noise = VRandom(randIdx++, randScale);
				if(val == VZero)
					val = noise;
				else
					val = VAdd(val, noise);
			}
			return val;
		}

		function makeParam(scope: Prefab, name: String): Value {
			inline function getCurve(name) {
				return scope.getOpt(Curve, name);
			}

			var param = PARAMS.find(p -> p.name == name);
			switch(param.t) {
				case PVec(_):
					var baseval : h3d.Vector = getParamVal(param.name);
					var randVal : h3d.Vector = getParamVal(param.name, true);
					return VVector(
						makeVal(baseval.x, getCurve(param.name + ".x"), randVal != null ? randVal.x : 0.0, getCurve(param.name + ".x.rand")),
						makeVal(baseval.y, getCurve(param.name + ".y"), randVal != null ? randVal.y : 0.0, getCurve(param.name + ".y.rand")),
						makeVal(baseval.z, getCurve(param.name + ".z"), randVal != null ? randVal.z : 0.0, getCurve(param.name + ".z.rand")));
				default:
					var baseval : Float = getParamVal(param.name);
					var randVal : Null<Float> = getParamVal(param.name, true);
					return makeVal(baseval, getCurve(param.name), randVal != null ? randVal : 0.0, getCurve(param.name + ".rand"));
			}
		}

		emitterObj.instDef = {
			localSpeed: makeParam(template, "speed"),
			localOffset: makeParam(template, "offset"),
			scale: makeParam(template, "scale"),
			rotation: makeParam(template, "rotation"),
		};

		emitterObj.particleTemplate = template;
		emitterObj.lifeTime = getParamVal("lifeTime");
		emitterObj.maxCount = getParamVal("maxCount");
		emitterObj.emitRate = makeParam(this, "emitRate");
		emitterObj.emitSize = makeParam(this, "emitSize");
		emitterObj.emitShape = getParamVal("emitShape");
		emitterObj.emitAngle = makeParam(this, "emitAngle");
		emitterObj.alignVec = getParamVal("camAlign");

		#if editor
		var debugShape = emitterObj.find(c -> if(c.name == "_debugShape") c else null);
		if(debugShape != null)
			debugShape.remove();

		var mesh : h3d.scene.Mesh = null;
		if(emitterObj.emitShape == Disc) {
			var nsegments = 32;
			var g = new h3d.scene.Graphics(emitterObj);
			g.lineStyle(1, 0xffffff);
			for(i in 0...nsegments) {
				var c = hxd.Math.cos(i / (nsegments - 1) * hxd.Math.PI * 2.0);
				var s = hxd.Math.sin(i / (nsegments - 1) * hxd.Math.PI * 2.0);
				if(i == 0)
					g.moveTo(0, c, s);
				else
					g.lineTo(0, c, s);
			}
			g.ignoreCollide = true;
			mesh = g;
		}
		else if(emitterObj.emitShape == Sphere) {
			mesh = new h3d.scene.Sphere(0xffffff, 1.0, true, emitterObj);
		}

		if(mesh != null) {
			mesh.name = "_debugShape";
			var mat = mesh.material;
			mat.mainPass.setPassName("overlay");
			mat.shadows = false;
		}
		#end
	}

	override function makeInstance(ctx:Context):Context {
		ctx = ctx.clone(this);
		var emitterObj = new EmitterObject(ctx.local3d);
		emitterObj.context = ctx;
		applyParams(emitterObj);
		ctx.local3d = emitterObj;
		ctx.local3d.name = name;
		applyPos(ctx.local3d);
		return ctx;
	}

	override function edit( ctx : EditContext ) {
		super.edit(ctx);
		#if editor

		function refresh() {
			ctx.properties.clear();
			this.edit(ctx);
		}

		var angleProp = null;

		function onChange(pname: String) {
			ctx.onChange(this, pname);
			var emitter = Std.instance(ctx.getContext(this).local3d, EmitterObject);
			if(emitter != null)
				applyParams(emitter);

			if(pname == "emitShape") {
				refresh();
			}
		}

		var params = emitterParams.copy();

		var emitShape : EmitShape = getParamVal("emitShape");
		if(emitShape != null) 
			switch(emitShape) {
				case Cone:
				default: params.remove(params.find(p -> p.name == "emitAngle"));
			}

		var emGroup = new Element('<div class="group" name="Emitter"></div>');
		emGroup.append(hide.comp.PropsEditor.makePropsList(params));
		var props = ctx.properties.add(emGroup, this.props, onChange);
		// angleProp = ctx.properties.fields.find(f -> f.fname == "emitAngle");

		{
			var instGroup = new Element('<div class="group" name="Particles"></div>');
			var dl = new Element('<dl>').appendTo(instGroup);
			for(p in instanceParams) {
				var dt = new Element('<dt>${p.name}</dt>').appendTo(dl);
				var dd = new Element('<dd>').appendTo(dl);
				if(Reflect.hasField(this.props, p.name)) {
					hide.comp.PropsEditor.makePropEl(p, dd);
				}
				else {
					var btn = new Element('<input type="button" value="+"></input>').appendTo(dd);
					btn.click(function(e) {
						Reflect.setField(this.props, p.name, p.def);
						refresh();
					});
				}
				var dt = new Element('<dt>~</dt>').appendTo(dl);
				var dd = new Element('<dd>').appendTo(dl);
				var randDef : Dynamic = switch(p.t) {
					case PVec(n): [for(i in 0...n) 0.0];
					case PFloat(_): 0.0;
					default: 0;
				};
				if(Reflect.hasField(this.props, randProp(p.name))) {
					hide.comp.PropsEditor.makePropEl({
						name: randProp(p.name),
						t: p.t,
						def: randDef}, dd);
				}
				else {
					var btn = new Element('<input type="button" value="+"></input>').appendTo(dd);
					btn.click(function(e) {
						Reflect.setField(this.props, randProp(p.name), randDef);
						refresh();
					});
				}
			}
			var props = ctx.properties.add(instGroup, this.props, onChange);
		}
		#end
	}

	override function getHideProps() {
		return { icon : "asterisk", name : "Emitter", fileSource : null };
	}

	static var _ = Library.register("emitter", Emitter);

}