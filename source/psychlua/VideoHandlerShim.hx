package psychlua;

import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import flixel.FlxG;

/**
 * 0.6.3 VideoHandler + 0.7.3 FlxVideo compatible shim on 1.0.4 VideoSprite (hxvlc).
 * Supports: playVideo(path), play(path, ?loop), pause, resume, stop, dispose,
 * finishCallback, onEndReached, bitmapData, volume, visible.
 */
class VideoHandlerShim
{
	public var finishCallback:Void->Void = null;
	/** FlxVideo-style end callback */
	public var onEndReached:Void->Void = null;
	public var visible:Bool = true;
	public var volume(default, set):Float = 1;
	public var alpha:Float = 1;
	public var bitmapData:BitmapData;

	#if VIDEOS_ALLOWED
	var _video:Dynamic = null;
	#end

	var _path:String = null;
	var _finished:Bool = false;
	var _loop:Bool = false;

	public function new()
	{
		bitmapData = new BitmapData(2, 2, true, 0x00000000);
	}

	function set_volume(v:Float):Float
	{
		volume = v;
		#if VIDEOS_ALLOWED
		try {
			if (_video != null && _video.videoSprite != null && _video.videoSprite.bitmap != null)
				_video.videoSprite.bitmap.volume = Std.int(Math.max(0, Math.min(100, v * 100)));
		} catch (e:Dynamic) {}
		#end
		return volume;
	}

	function fireEnd():Void
	{
		_finished = true;
		syncBitmap();
		if (finishCallback != null) {
			try { finishCallback(); } catch (e:Dynamic) {}
		}
		if (onEndReached != null) {
			try { onEndReached(); } catch (e:Dynamic) {}
		}
	}

	/** 0.6.3 API */
	public function playVideo(path:String):Void
	{
		play(path, false);
	}

	/**
	 * FlxVideo / some 0.7.3 scripts: play(path, loop)
	 * Also safe no-arg play() if path already set via playVideo.
	 */
	public function play(?path:String = null, ?loop:Bool = false):Void
	{
		if (path != null && path.length > 0)
			_path = path;
		_loop = loop == true;
		_finished = false;

		if (_path == null || _path.length < 1)
		{
			trace('VideoHandlerShim.play: no path');
			return;
		}

		#if VIDEOS_ALLOWED
		try {
			// destroy previous
			if (_video != null) {
				try { _video.destroy(); } catch (e:Dynamic) {}
				_video = null;
			}

			var cls = Type.resolveClass('objects.VideoSprite');
			if (cls == null) {
				trace('VideoHandlerShim: objects.VideoSprite not found');
				fireEnd();
				return;
			}

			// VideoSprite(path, forMidSong, canSkip, loop)
			_video = Type.createInstance(cls, [_path, true, false, _loop]);
			if (_video == null) {
				trace('VideoHandlerShim: createInstance returned null');
				fireEnd();
				return;
			}

			var onEnd = function() {
				fireEnd();
			};
			try { _video.finishCallback = onEnd; } catch (e:Dynamic) {}
			try { _video.onSkip = onEnd; } catch (e:Dynamic) {}

			if (PlayState.instance != null) {
				try { PlayState.instance.add(_video); } catch (e:Dynamic) {}
			}

			// Call play safely — never throw "null function play"
			var played = false;
			try {
				if (Reflect.field(_video, 'play') != null) {
					Reflect.callMethod(_video, Reflect.field(_video, 'play'), []);
					played = true;
				}
			} catch (e:Dynamic) {
				trace('VideoHandlerShim play() call: ' + e);
			}
			if (!played) {
				try {
					Reflect.callMethod(_video, Reflect.field(_video, 'start'), []);
					played = true;
				} catch (e:Dynamic) {}
			}
			syncBitmap();
		} catch (e:Dynamic) {
			trace('VideoHandlerShim.play failed: ' + e);
			fireEnd();
		}
		#else
		trace('VideoHandlerShim: VIDEOS_ALLOWED off');
		fireEnd();
		#end
	}

	public function finishVideo():Void
	{
		stop();
		fireEnd();
	}

	public function stop():Void
	{
		_finished = true;
		#if VIDEOS_ALLOWED
		try {
			if (_video != null) {
				try {
					if (Reflect.field(_video, 'destroy') != null)
						Reflect.callMethod(_video, Reflect.field(_video, 'destroy'), []);
				} catch (e:Dynamic) {}
				_video = null;
			}
		} catch (e:Dynamic) {}
		#end
	}

	public function dispose():Void
	{
		stop();
		try {
			if (bitmapData != null) bitmapData.dispose();
		} catch (e:Dynamic) {}
		bitmapData = new BitmapData(2, 2, true, 0x00000000);
	}

	public function pause():Void
	{
		#if VIDEOS_ALLOWED
		try {
			if (_video != null && _video.videoSprite != null && _video.videoSprite.bitmap != null)
				_video.videoSprite.bitmap.pause();
		} catch (e:Dynamic) {}
		#end
	}

	public function resume():Void
	{
		#if VIDEOS_ALLOWED
		try {
			if (_video != null && _video.videoSprite != null && _video.videoSprite.bitmap != null)
				_video.videoSprite.bitmap.resume();
		} catch (e:Dynamic) {}
		#end
	}

	/** Dummy for FlxVideo.onTextureSetup.add(...) scripts — no-op signal */
	public var onTextureSetup:Dynamic = {
		add: function(cb:Dynamic) {}
	};

	public function update(?_):Void
	{
		syncBitmap();
	}

	function syncBitmap():Void
	{
		#if VIDEOS_ALLOWED
		try {
			if (_video == null) return;
			var bd:BitmapData = null;
			if (_video.videoSprite != null) {
				if (_video.videoSprite.bitmapData != null)
					bd = _video.videoSprite.bitmapData;
				else if (_video.videoSprite.bitmap != null && _video.videoSprite.bitmap.bitmapData != null)
					bd = _video.videoSprite.bitmap.bitmapData;
			}
			if (bd != null && bd.width > 1 && bd.height > 1) {
				if (bitmapData == null || bitmapData.width != bd.width || bitmapData.height != bd.height) {
					if (bitmapData != null) try { bitmapData.dispose(); } catch (e:Dynamic) {}
					bitmapData = bd.clone();
				} else {
					bitmapData.copyPixels(bd, new Rectangle(0, 0, bd.width, bd.height), new Point());
				}
			}
		} catch (e:Dynamic) {}
		#end
	}
}
