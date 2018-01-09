package hide.prefab;

class Constraint extends Prefab {

	var object : String;
	var target : String;

	override public function load(v:Dynamic) {
		object = v.object;
		target = v.target;
	}

	override function save() {
		return { object : object, target : target };
	}

	override function makeInstance( ctx : Context ) {
		var srcObj = ctx.locateObject(object);
		var targetObj = ctx.locateObject(target);
		if( srcObj != null ) srcObj.follow = targetObj;
		return ctx;
	}

	override function getHideProps() : HideProps {
		return { icon : "lock", name : "Constraint" };
	}

	override function edit(ctx:EditContext) {
		#if editor
		var curObj = ctx.rootContext.locateObject(object);
		var props = ctx.properties.add(new hide.Element('
			<dl>
				<dt>Source</dt><dd><select field="object"><option value="">-- Choose --</option></select>
				<dt>Target</dt><dd><select field="target"><option value="">-- Choose --</option></select>
			</dl>
		'),this, function(_) {
			if( curObj != null ) curObj.follow = null;
			makeInstance(ctx.rootContext);
			curObj = ctx.rootContext.locateObject(object);
		});
		for( select in [props.find("[field=object]"), props.find("[field=target]")] ) {
			for( path in ctx.getNamedObjects() ) {
				var parts = path.split(".");
				var opt = new hide.Element("<option>").attr("value", path).html([for( p in 1...parts.length ) "&nbsp; "].join("") + parts.pop());
				select.append(opt);
			}
			select.val(Reflect.field(this, select.attr("field")));
		}
		#end
	}

	static var _ = Library.register("constraint", Constraint);

}