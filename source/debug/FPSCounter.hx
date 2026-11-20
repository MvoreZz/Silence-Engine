package debug;

import flixel.FlxG;
import openfl.Lib;
import openfl.text.TextField;
import openfl.text.TextFormat;
import lime.system.System as LimeSystem;

/**
	Simple FPS / memory overlay. Does not change updateFramerate (prevents slow-mo).
**/
class FPSCounter extends TextField
{
	public var currentFPS(default, null):Int;
	public var memoryMegas(get, never):Float;
	public var peakMemoryMegas(default, null):Float = 0;

	@:noCompletion private var prevTime:Int;
	@:noCompletion private var updateTime:Int;
	@:noCompletion private var framesCount:Int;

	public var os:String = '';

	public function new(x:Float = 10, y:Float = 10, color:Int = 0x000000)
	{
		super();

		var ver:String = LimeSystem.platformVersion;
		if (ver != null && ver != '' && ver != LimeSystem.platformName)
			os = LimeSystem.platformName + ' ' + ver;
		else
			os = LimeSystem.platformName != null ? LimeSystem.platformName : '';

		positionFPS(x, y);

		currentFPS = 0;
		selectable = false;
		mouseEnabled = false;
		defaultTextFormat = new TextFormat("_sans", 13, color);
		width = FlxG.width;
		multiline = true;
		text = "FPS: ";

		prevTime = Lib.getTimer();
		updateTime = prevTime + 500;
		framesCount = 0;
	}

	public dynamic function updateText():Void
	{
		var mem:Float = memoryMegas;
		if (mem > peakMemoryMegas)
			peakMemoryMegas = mem;

		var gfx:String = '';
		try
		{
			var q:String = ClientPrefs.data.graphicsQuality;
			if (q == null || q == 'Custom')
				q = ClientPrefs.analyzeDeviceQuality();
			gfx = q;
		}
		catch (e:Dynamic) { gfx = ''; }

		var luaN:Int = 0;
		var hxN:Int = 0;
		try
		{
			if (states.PlayState.instance != null)
			{
				#if LUA_ALLOWED
				if (states.PlayState.instance.luaArray != null)
					luaN = states.PlayState.instance.luaArray.length;
				#end
				#if HSCRIPT_ALLOWED
				if (states.PlayState.instance.hscriptArray != null)
					hxN = states.PlayState.instance.hscriptArray.length;
				#end
			}
		}
		catch (e:Dynamic) {}

		var lines:Array<String> = [];
		lines.push('FPS: $currentFPS');
		lines.push('Mem: ${flixel.util.FlxStringUtil.formatBytes(mem)}');
		lines.push('Peak: ${flixel.util.FlxStringUtil.formatBytes(peakMemoryMegas)}');
		if (gfx != null && gfx.length > 0)
			lines.push('GPU: ' + gfx);
		if (luaN > 0 || hxN > 0)
			lines.push(luaN + ' lua | ' + hxN + ' haxe');
		if (os != null && os.length > 0)
			lines.push(os);

		text = lines.join('\n');
		textColor = 0xFFFFFFFF;
		if (currentFPS < 30)
			textColor = 0xFFFF0000;
	}

	private override function __enterFrame(deltaTime:Float):Void
	{
		var currentTime = Lib.getTimer();
		framesCount++;
		if (currentTime >= updateTime)
		{
			var elapsed = currentTime - prevTime;
			if (elapsed < 1) elapsed = 1;
			currentFPS = Math.ceil((framesCount * 1000) / elapsed);
			if (currentFPS < 0) currentFPS = 0;
			framesCount = 0;
			prevTime = currentTime;
			updateTime = currentTime + 500;
		}
		updateText();
	}

	inline function get_memoryMegas():Float
	{
		#if cpp
		return cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
		#else
		return openfl.system.System.totalMemory;
		#end
	}

	public inline function positionFPS(X:Float, Y:Float, ?scale:Float = 1)
	{
		scaleX = scaleY = #if android (scale > 1 ? scale : 1) #else (scale < 1 ? scale : 1) #end;
		x = FlxG.game.x + X;
		y = FlxG.game.y + Y;
	}
}
