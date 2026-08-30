package psychlua;

import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import flixel.FlxG;

/**
 * 0.6.3 / 0.7.3 VideoHandler-compatible shim on top of 1.0.4 VideoSprite (hxvlc).
 * Allows mods to `new VideoHandler()` / playVideo / bitmapData without hxCodec
 * (hxCodec cannot coexist with hxvlc).
 */
class VideoHandlerShim
{
	public var finishCallback:Void->Void = null;
	public var visible:Bool = true;
	public var volume(default, set):Float = 1;

	/** Updated each frame for loadGraphic(video.bitmapData) scripts */
	public var bitmapData:BitmapData;

	#if VIDEOS_ALLOWED
	var _video:Dynamic = null; // objects.VideoSprite
	#end

	var _path:String = null;
	var _finished:Bool = false;

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

	/** 0.6.3 API */
	public function playVideo(path:String):Void
	{
		_path = path;
		_finished = false;
		#if VIDEOS_ALLOWED
		try {
			// forMidSong=true: don't hijack whole PlayState cutscene like intro videos
			_video = Type.createInstance(Type.resolveClass('objects.VideoSprite'), [path, true, false, false]);
			if (_video == null) return;

			_video.finishCallback = function() {
				_finished = true;
				syncBitmap();
				if (finishCallback != null) finishCallback();
			};
			try {
				_video.onSkip = _video.finishCallback;
			} catch (e:Dynamic) {}

			if (PlayState.instance != null)
				PlayState.instance.add(_video);

			try {
				_video.play();
			} catch (e:Dynamic) {
				try { Reflect.callMethod(_video, Reflect.field(_video, 'play'), []); } catch (e2:Dynamic) {}
			}
		} catch (e:Dynamic) {
			trace('VideoHandlerShim.playVideo failed: ' + e);
		}
		#else
		trace('VideoHandlerShim: VIDEOS_ALLOWED is off');
		if (finishCallback != null) finishCallback();
		#end
	}

	/** Some 0.6.3 scripts call this to pre-cache / stop */
	public function finishVideo():Void
	{
		_finished = true;
		#if VIDEOS_ALLOWED
		try {
			if (_video != null) {
				try { _video.destroy(); } catch (e:Dynamic) {}
				_video = null;
			}
		} catch (e:Dynamic) {}
		#end
		if (finishCallback != null) finishCallback();
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

	/** enterFrame listener target in old scripts — keep bitmapData in sync */
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
			// common hxvlc / VideoSprite paths
			if (_video.videoSprite != null) {
				if (_video.videoSprite.bitmapData != null)
					bd = _video.videoSprite.bitmapData;
				else if (_video.videoSprite.bitmap != null && _video.videoSprite.bitmap.bitmapData != null)
					bd = _video.videoSprite.bitmap.bitmapData;
			}
			if (bd != null && bd.width > 1 && bd.height > 1) {
				if (bitmapData == null || bitmapData.width != bd.width || bitmapData.height != bd.height) {
					if (bitmapData != null) bitmapData.dispose();
					bitmapData = bd.clone();
				} else {
					bitmapData.copyPixels(bd, new Rectangle(0, 0, bd.width, bd.height), new openfl.geom.Point());
				}
			}
		} catch (e:Dynamic) {}
		#end
	}
}
