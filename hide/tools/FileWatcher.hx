package hide.tools;

class FileWatcher {

	var ide : hide.Ide;
	var watches : Map<String,{ events : Array<{path:String,fun:Void->Void,checkDel:Bool}>, w : js.node.fs.FSWatcher, changed : Bool, isDir : Bool }> = new Map();

	public function new() {
		ide = hide.Ide.inst;
	}

	public function dispose() {
		for( w in watches )
			if( w.w != null )
				w.w.close();
		watches = new Map();
	}

	public function register( path : String, updateFun, ?checkDelete : Bool ) {
		var w = getWatches(path);
		w.events.push({ path : path, fun : updateFun, checkDel : checkDelete });
	}

	public function unregister( path : String, updateFun : Void -> Void ) {
		var w = getWatches(path);
		for( e in w.events )
			if( Reflect.compareMethods(e.fun, updateFun) ) {
				w.events.remove(e);
				break;
			}
		if( w.events.length == 0 ) {
			watches.remove(path);
			if( w.w != null ) w.w.close();
		}
	}

	function getWatches( path : String ) {
		var w = watches.get(path);
		if( w == null ) {
			var fullPath = ide.getPath(path);
			w = {
				events : [],
				w : null,
				changed : false,
				isDir : try sys.FileSystem.isDirectory(fullPath) catch( e : Dynamic ) false,
			};
			w.w = try js.node.Fs.watch(fullPath, function(k:String, file:String) {
				if( w.changed || (w.isDir && k == "change") ) return;
				w.changed = true;
				haxe.Timer.delay(function() {
					if( !w.changed ) return;
					w.changed = false;
					for( e in w.events.copy() )
						if( k == "change" || e.checkDel )
							e.fun();
				}, 100);
			}) catch( e : Dynamic ) {
				// file does not exists, trigger a delayed event
				haxe.Timer.delay(function() {
					for( e in w.events.copy() )
						if( e.checkDel )
							e.fun();
				}, 0);
				return w;
			}
			watches.set(path, w);
		}
		return w;
	}


}