package hide.prefab.fx;
import hide.prefab.Curve;
import hide.prefab.fx.FXScene.Value;
import hide.prefab.fx.FXScene.Evaluator;
using Lambda;

enum EmitShape {
	Sphere;
	Circle;
}

enum ParamType {
	TInt(?min: Int, ?max: Int);
	TFloat(?min: Float, ?max: Float);
	TVector(size: Int);
}

typedef ParamDef = {
	name: String,
	type: ParamType,
	defval: Dynamic,
	?noanim: Bool
}

typedef InstanceDef = {
	localSpeed: Value,
	localOffset: Value,
	scale: Value
}

typedef ShaderAnims = Array<hide.prefab.Shader.ShaderAnimation>;

@:allow(hide.prefab.fx.EmitterObject)
private class ParticleInstance extends Evaluator {
	var parent : EmitterObject;
	public var life = 0.0;
	public var obj : h3d.scene.Object;

	public var curVelocity = new h3d.Vector();
	public var curPos = new h3d.Vector();
	public var orientation = new h3d.Quat();
	//public var orientation = new h3d.Matrix();

	// public var speed : VectorParam;
	// public var localSpeed : VectorParam;
	// public var globalSpeed : VectorParam;
	// public var localOffset : VectorParam;
	public var def : InstanceDef;
	public var shaderAnims : ShaderAnims;

	public function new(parent: EmitterObject, def: InstanceDef) {
		super(parent.random);
		this.def = def;
		this.parent = parent;
		parent.instances.push(this);
	}

	public function update(dt : Float) {

		var localSpeed = getVector(def.localSpeed, life);
		if(localSpeed.length() > 0.001) {
			// var locSpeedVec = localSpeed.get(life);
			localSpeed.transform3x3(orientation.toMatrix());
			curVelocity = localSpeed;
		}
		// {
		// 	var globSpeedVec = new h3d.Vector(0, 0, -2);
		// 	curVelocity = curVelocity.add(globSpeedVec);
		// }

		curPos.x += curVelocity.x * dt;
		curPos.y += curVelocity.y * dt;
		curPos.z += curVelocity.z * dt;
		obj.setPos(curPos.x, curPos.y, curPos.z);

		var scaleVec = getVector(def.scale, life);
		obj.scaleX = scaleVec.x;
		obj.scaleY = scaleVec.y;
		obj.scaleZ = scaleVec.z;

		// if(localOffset != null) {
		// 	var off = localOffset.get(life);
		// 	obj.x += off.x;
		// 	obj.y += off.y;
		// 	obj.z += off.x;
		// }

		for(anim in shaderAnims) {
			anim.setTime(life);
		}

		life += dt;
	}

	public function remove() {
		obj.remove();
		parent.instances.remove(this);
	}
}

@:allow(hide.prefab.fx.ParticleInstance)
@:allow(hide.prefab.fx.Emitter)
class EmitterObject extends h3d.scene.Object {

	public var particleTemplate : hide.prefab.Prefab;
	public var maxCount = 20;
	public var lifeTime = 2.0;
	// public var emitRate : FloatParam;
	public var emitShape : EmitShape = Circle;
	// public var emitShapeSize = new FloatParam(6.0);

	var emitRate : Value;
	var emitSize : Value;

	public var instDef : InstanceDef;

	// public var emitSpeed = new FloatParam(1.0);
	// public var localSpeed = new VectorParam();
	// public var partSpeed = new VectorParam();

	public function new(?parent, instDef) {
		super(parent);
		this.instDef = instDef;
		random = new hxd.Rand(0);
		evaluator = new Evaluator(random);
	}

	var random: hxd.Rand;
	var context : hide.prefab.Context;
	var emitCount = 0;
	var lastTime = -1.0;
	var curTime = 0.0;
	var evaluator : Evaluator;

	var instances : Array<ParticleInstance> = [];

	// public function new()


	function reset() {
		curTime = 0.0;
		lastTime = 0.0;
		emitCount = 0;
		for(inst in instances.copy()) {
			inst.remove();
		}
	}

	function doEmit(count: Int) {
		calcAbsPos();

		var shapeSize = evaluator.getFloat(emitSize, curTime);
		context.local3d = this.parent;
		if(particleTemplate == null)
			return;
		// var localTrans = new h3d.Matrix();
		for(i in 0...count) {
			var ctx = particleTemplate.makeInstance(context);
			var obj3d = ctx.local3d;

			var localPos = new h3d.Vector();
			var localDir = new h3d.Vector();
			switch(emitShape) {
				case Circle:
					var dx = 0.0, dy = 0.0;
					do {
						dx = hxd.Math.srand(1.0);
						dy = hxd.Math.srand(1.0);
					}
					while(dx * dx + dy * dy > 1.0);
					dx *= shapeSize / 2.0;
					dy *= shapeSize / 2.0;
					localPos.set(0, dx, dy);
					// localTrans.initTranslate(0, dx, dy);
				default:
			}

			localPos.transform(absPos);
			// localTrans.multiply(localTrans, absPos);
			var part = new ParticleInstance(this, instDef);
			part.obj = obj3d;
			part.curPos = localPos;
			// part.localSpeed = localSpeed.copy();
			//part.transform = localTrans;
			part.orientation.initRotateMatrix(absPos);
			// part.curVelocity

			part.shaderAnims = [];
			// var shaders = particleTemplate.getAll(hide.prefab.Shader);
			// for(shader in shaders) {
			// 	var params = shader.makeParams();
			// 	part.shaderAnims.push({

			// 	});
			// }
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
		}
		context.local3d = this;
		emitCount += count;
	}

	function tick(dt: Float) {
		// def.getSum(EmitRate, this);

		var emitTarget = evaluator.getSum(emitRate, curTime);
		var delta = hxd.Math.floor(emitTarget - emitCount);
		doEmit(delta);


		var i = instances.length;
		while (i-- > 0) {
			if(instances[i].life > lifeTime) {
				instances[i].remove();
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

		// var deltaTime = time - lastTime;
		// lastTime = curTime;
		// curTime = time;

		// if(deltaTime <= 0.01)
		// 	return;
	}

	override function sync(ctx) {
		super.sync(ctx);
		// if(ctx.elapsedTime == 0)
		// 	return;

		// if(ctx.time < lastTime || lastTime < 0) {
		// 	reset();
		// }


		// for(inst in instances) {
		// 	inst.update(deltaTime);
		// }
	}
}


class Emitter extends Object3D {

	var emitRate = 50.0;
	var emitRateRandom = 2.0;

	public function new(?parent) {
		super(parent);
		props = { };
	}

	public static var PARAMS : Array<ParamDef> = [
		{
			name: "lifeTime",
			type: TFloat(0, 10),
			defval: 1.0,
			noanim: true
		},
		{
			name: "maxCount",
			type: TInt(0, 100),
			defval: 20,
			noanim: true
		},
		{
			name: "emitRate",
			type: TInt(0, 100),
			defval: 5
		},
		{
			name: "emitSize",
			type: TFloat(0, 10),
			defval: 1.0
		},
		{
			name: "speed",
			type: TVector(3),
			defval: [5.,0.,0.]
		},
	];

	override function save() {
		var obj : Dynamic = super.save();
		for(param in PARAMS) {
			if(Reflect.hasField(props, param.name)) {
				var f = Reflect.field(props, param.name);
				if(f != param.defval) {
					Reflect.setField(obj, param.name, f);
				}
			}
		}
		return obj;
	}

	override function load( obj : Dynamic ) {
		super.load(obj);
		for(param in PARAMS) {
			if(Reflect.hasField(obj, param.name)) {
				Reflect.setField(props, param.name, Reflect.field(obj, param.name));
			}
		}
	}

	override function makeInstanceRec(ctx: Context) {
		ctx = makeInstance(ctx);
		// Don't make children, which are used to setup particles
	}

	function getParamVal(name: String, rand: Bool=false) : Dynamic {
		var param = PARAMS.find(p -> p.name == name);
		var isVector = switch(param.type) {
			case TVector(_): true;
			default: false;
		}
		var val : Dynamic = rand ? (isVector ? [0.,0.,0.,0.] : 0.) : param.defval;
		if(rand)
			name = name + "_rand";
		if(props != null && Reflect.hasField(props, name)) {
			val = Reflect.field(props, name);
		}
		if(isVector)
			return h3d.Vector.fromArray(val);
		return val;
	}

	override function makeInstance(ctx:Context):Context {
		ctx = ctx.clone(this);

		var randIdx = 0;

		function makeVal(base: Float, curve: Curve, randFactor: Float, randCurve: Curve) {
			var val : Value = if(curve != null)
				VCurveValue(curve, base);
			else
				VConst(base);

			if(randFactor != 0.0) {
				var randScale = randCurve != null ? VCurveValue(randCurve, randFactor) : VConst(randFactor);
				val = VAdd(val, VNoise(randIdx++, randScale));
			}

			return val;
		}

		var template = children[0];
		if(template == null)
			return ctx;

		function getCurve(name) {
			return template.getOpt(Curve, name);
		}

		// function makeVal(base: Float, name: String, randFactor: Float, randCurve: Curve) {
		// 	var val : Value = if(curve != null)
		// 		VCurveValue(curve, base);
		// 	else
		// 		VConst(base);

		// 	if(randFactor != 0.0) {
		// 		var randScale = randCurve != null ? VCurveValue(randCurve, randFactor) : VConst(randFactor);
		// 		val = VAdd(val, VNoise(randIdx++, randScale));
		// 	}

		// 	return val;
		// }

		// function makeFloat(name: String) : Value {
		// 	getCurve(name
		// }

		// function makeVec(name: String) : Value {
		// 	var base : h3d.Vector = getParamVal(name);
		// 	if(base.length() == 0.0) {
		// 		return VZero;
		// 	}

		// 	var x = getCurve(name + ".x");
		// 	var y = getCurve(name + ".y");
		// 	var z = getCurve(name + ".z");
		// 	var w = getCurve(name + ".w");

		// 	return VVector(
		// 		x != null ? VCurveValue(x, base.x) : VConst(base.x),
		// 		y != null ? VCurveValue(y, base.y) : VConst(base.y),
		// 		z != null ? VCurveValue(z, base.z) : VConst(base.z),
		// 		w != null ? VCurveValue(w, base.w) : VConst(base.w));
		// }

		function makeParam(name: String) {
			var param = PARAMS.find(p -> p.name == name);
			switch(param.type) {
				case TVector(_):
					var baseval : h3d.Vector = getParamVal(param.name);
					var randVal : h3d.Vector = getParamVal(param.name, true);
					return VVector(
						makeVal(baseval.x, getCurve(param.name + ".x"), randVal != null ? randVal.x : 0.0, getCurve(param.name + ".x.rand")),
						makeVal(baseval.y, getCurve(param.name + ".y"), randVal != null ? randVal.y : 0.0, getCurve(param.name + ".y.rand")),
						makeVal(baseval.z, getCurve(param.name + ".z"), randVal != null ? randVal.z : 0.0, getCurve(param.name + ".z.rand")),
						makeVal(baseval.w, getCurve(param.name + ".w"), randVal != null ? randVal.w : 0.0, getCurve(param.name + ".w.rand")));
					// var val = makeVec(param.name);
					// var rand = makeVec(param.name + "_rand");
					// if(rand != VZero) {
					// 	val = VAdd(val, rand);
					// }
					// return val;
				default:
					var baseval : Float = getParamVal(param.name);
					var randVal : Float = getParamVal(param.name, true);
					return makeVal(baseval, getCurve(param.name), randVal != null ? randVal : 0.0, getCurve(param.name + ".rand"));
			}
		}

		var instDef : InstanceDef = {
			localSpeed: makeParam("speed"),
			localOffset: VConst(0.0),
			scale: VConst(1.0), //makeVal(1.0, template.getOpt(Curve, "scale.x"), 0.0, null)
		};

		var emitterObj = new EmitterObject(ctx.local3d, instDef);
		emitterObj.context = ctx;
		emitterObj.particleTemplate = children[0];
		emitterObj.lifeTime = getParamVal("lifeTime");
		emitterObj.maxCount = getParamVal("maxCount");
		emitterObj.emitRate = makeParam("emitRate"); //makeVal(10.0, getOpt(Curve, "emitRate"), 0.0, null);
		emitterObj.emitSize = makeParam("emitSize");
		//emitterObj.localSpeed = 


		//emitterObj.emitRate = getFloatParam("emitRate");
		// emitterObj.localSpeed = getVectorParam("localSpeed");
		//ctx.local3d.addChild(emitterObj);
		ctx.local3d = emitterObj;
		ctx.local3d.name = name;
		applyPos(ctx.local3d);
		return ctx;
	}

	override function edit( ctx : EditContext ) {
		super.edit(ctx);
		#if editor
		var props = ctx.properties.add(new hide.Element('
			<div class="group" name="Layer">
				<dl>
					<dt>Locked</dt><dd><input type="checkbox" field="locked"/></dd>
					<dt>Color</dt><dd><input name="colorVal"/></dd>
				</dl>
			</div>
		'),this, function(pname) {
			ctx.onChange(this, pname);
		});
		#end
	}


	override function getHideProps() {
		return { icon : "asterisk", name : "Emitter", fileSource : null };
	}

	static var _ = Library.register("emitter", Emitter);

}