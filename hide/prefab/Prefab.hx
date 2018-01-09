package hide.prefab;

class Prefab {

	public var type(default, null) : String;
	public var name(default, set) : String;
	public var parent(default, set) : Prefab;
	public var source(default, set) : String;
	public var children(default, null) : Array<Prefab>;

	public function new(?parent) {
		this.parent = parent;
		children = [];
	}

	function set_name(n) {
		return name = n;
	}

	function set_source(f) {
		return source = f;
	}

	function set_parent(p) {
		if( parent != null )
			parent.children.remove(this);
		parent = p;
		if( parent != null )
			parent.children.push(this);
		return p;
	}

	public function edit( ctx : EditContext ) {
	}

	public function getHideProps() : HideProps {
		return { icon : "question-circle", name : "Unknown" };
	}

	public inline function iterator() : Iterator<Prefab> {
		return children.iterator();
	}

	public function load( v : Dynamic ) {
		throw "Not implemented";
	}

	public function save() : {} {
		throw "Not implemented";
		return null;
	}

	public function makeInstance( ctx : Context ) : Context {
		throw "Not implemented";
		return null;
	}

	public function saveRec() : {} {
		var obj : Dynamic = save();
		obj.type = type;
		if( name != null )
			obj.name = name;
		if( source != null )
			obj.source = source;
		if( children.length > 0 )
			obj.children = [for( s in children ) s.saveRec()];
		return obj;
	}

	public static function loadRec( v : Dynamic, ?parent : Prefab ) {
		var pcl = @:privateAccess Library.registeredElements.get(v.type);
		if( pcl == null ) throw "Unregistered prefab " + v.type;
		var p = Type.createInstance(pcl, [parent]);
		p.type = v.type;
		p.name = v.name;
		if( v.source != null )
			p.source = v.source;
		p.load(v);
		var children : Array<Dynamic> = p.children;
		if( children != null )
			for( v in children )
				loadRec(v, p);
		return p;
	}

	public function makeInstanceRec( ctx : Context ) {
		if( ctx == null ) {
			ctx = new Context();
			ctx.init();
		}
		ctx = makeInstance(ctx);
		for( c in children )
			c.makeInstanceRec(ctx);
	}

	public function getPrefabByName( name : String ) {
		if( this.name == name )
			return this;
		for( c in children ) {
			var p = c.getPrefabByName(name);
			if( p != null )
				return p;
		}
		return null;
	}

	public function get<T:Prefab>( cl : Class<T>, ?name : String ) : T {
		for( c in children ) {
			if( (name == null || c.name == name) && Std.is(c, cl) )
				return cast c;
			var p = c.get(cl, name);
			if( p != null )
				return p;
		}
		return null;
	}

}