package hide.prefab.fx;
import hide.prefab.Curve;
using Lambda;

enum EmitShape {
	Sphere;
	Circle;
}

enum Value {
	VConst(v: Float);
	VCurveValue(c: Curve, scale: Float);
	// VCurveValue(c: Curve, scale: Float);
	VNoise(idx: Int, scale: Value);
	VAdd(a: Value, b: Value);
	VMult(a: Value, b: Value);
	VVector(x: Value, y: Value, z: Value);
}

// enum ParamKind {
// 	TFloat,
// 	TVector
// }
// typedef VectorValue {
// 	x: Value, y: Value, z: Value
// }

// typedef ParamDef = {
// 	kind: ParamKind,

// }

class Evaluator {
	var randValues : Array<Float> = [];
	var random: hxd.Rand;

	public function new(random: hxd.Rand) {
		this.random = random;
		// randValues[numParams-1] = 0.0;
	}

	public function getFloat(val: Value, time: Float) : Float {
		switch(val) {
			case VConst(v): return v;
			case VCurveValue(c, scale): return c.getVal(time) * scale;
			case VNoise(idx, scale):
				if(!(randValues[idx] > 0))
					randValues[idx] = random.rand();
				return randValues[idx] * getFloat(scale, time);
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
			case VVector(x, y, z):
				return new h3d.Vector(getFloat(x, time), getFloat(y, time), getFloat(z, time));
			default:
				var f = getFloat(v, time);
				return new h3d.Vector(f, f, f);
		}
	}
}

private class FloatParam {
	public var baseValue : Float;
	public var curve : hide.prefab.Curve;
	public var randScale : Float;
	public var randCurve : hide.prefab.Curve;

	var random : Float = 0.0;

	public function new(val: Float=1.0) {
		this.baseValue = val;
		random = hxd.Math.srand();
	}
	
	public function get(t: Float) {
		var val = baseValue;
		if(curve != null)
			val *= curve.getVal(t);
		return val;
	}

	public function getSum(t: Float) {
		if(curve != null)
			return baseValue * curve.getSum(t);
		return baseValue * t;
	}

	public function copy() {
		var p = new FloatParam(this.baseValue);
		p.curve = curve;
		return p;
	}
}

private class VectorParam {
	public var x : FloatParam;
	public var y : FloatParam;
	public var z : FloatParam;

	public function new() {
	}

	public function get(t: Float) : h3d.Vector {
		return new h3d.Vector(x.get(t), y.get(t), z.get(t));
	}

	public function copy() {
		var p = new VectorParam();
		if(x != null) p.x = x.copy();
		if(y != null) p.y = y.copy();
		if(z != null) p.z = z.copy();
		return p;
	}
}

// class InstanceDef {
// 	public var localSpeed : Value;
// 	public var localOffset : Value;
// }

typedef InstanceDef = {
	localSpeed: Value,
	localOffset: Value,
	scale: Value
}

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

	override function save() {
		var obj : Dynamic = super.save();
		return obj;
	}

	override function load( obj : Dynamic ) {
		super.load(obj);
	}

	function getVectorParam(name: String) {
		var curves = hide.prefab.Curve.getCurves(this, name);
		var ret = new VectorParam();
		inline function find(suf) return curves.find(c->c.name.indexOf(suf) >= 0);
		ret.x = new FloatParam(3.0);  // TODO
		ret.y = new FloatParam(0.0);
		ret.z = new FloatParam(0.0);
		ret.x.curve = find(".x");
		ret.y.curve = find(".y");
		ret.z.curve = find(".z");
		return ret;
	}

	function getFloatParam(name: String) {
		var v : Float = Reflect.field(this, name);
		var curve = getOpt(Curve, name);
		if(v == null)
			v = curve != null ? 1.0 : 0.0;
		var ret = new FloatParam(v);
		ret.curve = curve;
		// var rand : Float = Reflect.field(this, name + "Random");
		return ret;
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
		
		var localSpeed : Value = VVector(
			makeVal(2.0, template.getOpt(Curve, "localSpeed.x"), 1.0, template.getOpt(Curve, "localSpeedRand.x")),
			VConst(0),
			VConst(0)
		);

		var instDef : InstanceDef = {
			localSpeed: localSpeed,
			localOffset: VConst(0.0),
			scale: makeVal(1.0, template.getOpt(Curve, "scale.x"), 0.0, null)
		};
		

		var emitterObj = new EmitterObject(ctx.local3d, instDef);
		emitterObj.context = ctx;
		emitterObj.particleTemplate = children[0];
		emitterObj.emitRate = makeVal(10.0, getOpt(Curve, "emitRate"), 0.0, null);
		emitterObj.emitSize = VConst(0.0);
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