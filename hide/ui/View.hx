package hide.ui;

enum DisplayPosition {
	Left;
	Center;
	Right;
	Bottom;
}

typedef ViewOptions = { ?position : DisplayPosition, ?width : Int }

@:keepSub @:allow(hide.ui.Ide)
class View<T> extends hide.comp.Component {

	var container : golden.Container;
	var state : T;
	var keys(get,null) : Keys;
	var props(get,null) : Props;
	var undo = new hide.ui.UndoHistory();
	public var defaultOptions(get,never) : ViewOptions;

	var contentWidth(get,never) : Int;
	var contentHeight(get,never) : Int;

	public function new(state:T) {
		super(null);
		this.state = state;
		ide = Ide.inst;
	}

	function get_props() {
		if( props == null )
			props = ide.currentProps;
		return props;
	}

	function get_keys() {
		if( keys == null ) keys = new Keys(props);
		return keys;
	}

	public function getTitle() {
		var name = Type.getClassName(Type.getClass(this));
		return name.split(".").pop();
	}

	public function onBeforeClose() {
		return true;
	}

	function syncTitle() {
		container.setTitle(getTitle());
	}

	public function setContainer(cont) {
		this.container = cont;
		@:privateAccess ide.views.push(this);
		syncTitle();
		container.on("resize",function(_) {
			container.getElement().find('*').trigger('resize');
			onResize();
		});
		container.on("destroy",function(e) {
			if( !onBeforeClose() ) {
				e.preventDefault();
				return;
			}
			@:privateAccess ide.views.remove(this);
		});
		container.getElement().keydown(function(e) {
			keys.processEvent(e);
		});
		untyped cont.parent.__view = this;
		root = cont.getElement();
	}

	public function rebuild() {
		if( container == null ) return;
		syncTitle();
		root.html('');
		onDisplay();
	}

	public function onDisplay() {
		root.text(Type.getClassName(Type.getClass(this))+(state == null ? "" : " "+state));
	}

	public function onResize() {
	}

	public function saveState() {
		container.setState(state);
	}

	public function close() {
		if( container != null ) {
			container.close();
			container = null;
		}
	}

	function get_contentWidth() return container.width;
	function get_contentHeight() return container.height;
	function get_defaultOptions() return viewClasses.get(Type.getClassName(Type.getClass(this))).options;

	public static var viewClasses = new Map<String,{ name : String, cl : Class<View<Dynamic>>, options : ViewOptions }>();
	public static function register<T>( cl : Class<View<T>>, ?options : ViewOptions ) {
		var name = Type.getClassName(cl);
		if( viewClasses.exists(name) )
			return null;
		if( options == null )
			options = {}
		if( options.position == null )
			options.position = Center;
		viewClasses.set(name, { name : name, cl : cl, options : options });
		return null;
	}

}