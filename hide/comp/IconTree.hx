package hide.comp;

typedef IconTreeItem = {
	var id : String;
	var text : String;
	@:optional var children : Bool;
	@:optional var icon : String;
	@:optional var state : {
		@:optional var opened : Bool;
		@:optional var selected : Bool;
		@:optional var disabled : Bool;
	};
}

class IconTree extends Component {

	public dynamic function get( id : String ) : Array<IconTreeItem> {
		return [{ id : id+"0", text : "get()", children : true }];
	}

	public dynamic function onDblClick( id : String ) : Void {
	}

	public dynamic function onToggle( id : String, isOpen : Bool ) : Void {
	}

	public function init() {
		(untyped root.jstree)({
			core : {
				themes: {
					name: "default-dark",
					dots: true,
					icons: true
            	},
				data : function(obj,callb) {
					callb.call(this,get(obj.parent == null ? null : obj.id));
				}
			},
			plugins : [ "wholerow" ],
		});
		root.on("dblclick.jstree", function (event) {
			var node = new Element(event.target).closest("li");
   			var data = node[0].id;
			onDblClick(data);
		});
		root.on("open_node.jstree", function(event,e) {
			onToggle(e.node.id, true);
		});
		root.on("close_node.jstree", function(event,e) {
			onToggle(e.node.id, false);
		});
	}
	
}