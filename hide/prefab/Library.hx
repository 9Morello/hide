package hide.prefab;

class Library extends Prefab {

	var inRec = false;

	public function new() {
		super(null);
		type = "prefab";
	}

	// hacks to use directly non-recursive api

	override function load( obj : Dynamic ) {
		var children : Array<Dynamic> = obj.children;
		if( children != null )
			for( v in children )
				Prefab.loadRec(v, this);
	}

	override function save() {
		if( inRec )
			return {};
		inRec = true;
		var obj = saveRec();
		inRec = false;
		return obj;
	}

	override function makeInstance(ctx:Context):Context {
		if( inRec )
			return ctx;
		inRec = true;
		makeInstanceRec(ctx);
		inRec = false;
		return ctx;
	}

	static var registeredElements = new Map<String,Class<Prefab>>();
	public static function register( type : String, cl : Class<Prefab> ) {
		registeredElements.set(type, cl);
		return true;
	}

}