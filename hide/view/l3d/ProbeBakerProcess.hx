package hide.view.l3d;

class ProbeBakerProcess {

	public var progress : Float = 0.;

	var lightProbeBaker : hide.tools.LightProbeBaker;
	var volumetricLightmap : hide.prefab.l3d.VolumetricLightmap;
	var bakeTime : Float;
	var resolution : Int;

	public function new(volumetricLightmap, res, useGPU, bakeTime = 0.016 ){
		progress = 0;
		this.bakeTime = bakeTime;
		this.volumetricLightmap = volumetricLightmap;
		this.resolution = res;
		lightProbeBaker = new hide.tools.LightProbeBaker();
		lightProbeBaker.useGPU = useGPU;
	}

	public function init( env : h3d.scene.pbr.Environment, sceneData : hide.prefab.Prefab , shared : hide.prefab.ContextShared, scene : hide.comp.Scene) {
		lightProbeBaker.initScene(sceneData, shared, scene, env);
	}

	public function update(dt:Float) {
		lightProbeBaker.bake(volumetricLightmap.volumetricLightmap, resolution, bakeTime);
		progress = (volumetricLightmap.volumetricLightmap.lastBakedProbeIndex +1.0) / volumetricLightmap.volumetricLightmap.getProbeCount();
		if( progress == 1 ) {
			lightProbeBaker.dispose();
			lightProbeBaker = null;
			onEnd();
		}
	}

	public dynamic function onEnd() {

	}

}

