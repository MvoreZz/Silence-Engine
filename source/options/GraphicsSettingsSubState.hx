package options;

import objects.Character;

class GraphicsSettingsSubState extends BaseOptionsMenu
{
	var antialiasingOption:Int;
	var boyfriend:Character = null;
	public function new()
	{
		title = Language.getPhrase('graphics_menu', 'Graphics Settings');
		rpcTitle = 'Graphics Settings Menu'; //for Discord Rich Presence

		boyfriend = new Character(840, 170, 'bf', true);
		boyfriend.setGraphicSize(Std.int(boyfriend.width * 0.75));
		boyfriend.updateHitbox();
		boyfriend.dance();
		boyfriend.animation.finishCallback = function (name:String) boyfriend.dance();
		boyfriend.visible = false;

		// Only the detected device preset + Custom (cannot pick lower or higher presets)
		var deviceQ:String = ClientPrefs.getMaxDeviceQuality();
		var qualityChoices:Array<String> = [deviceQ, 'Custom'];

		// Force non-Custom saves onto the device preset only
		if (ClientPrefs.data.graphicsQuality != 'Custom')
			ClientPrefs.data.graphicsQuality = deviceQ;

		var option:Option = new Option('Graphics Quality:',
			ClientPrefs.getGraphicsQualityDescription(ClientPrefs.data.graphicsQuality),
			'graphicsQuality',
			STRING,
			qualityChoices);
		option.onChange = onChangeGraphicsQuality;
		addOption(option);

		//I'd suggest using "Low Quality" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Low Quality',
			'If checked, disables some background details,\ndecreases loading times and improves performance.\nEditing this switches Quality to Custom.',
			'lowQuality',
			BOOL);
		option.onChange = onManualGraphicsEdit;
		addOption(option);

		var option:Option = new Option('Anti-Aliasing',
			'If unchecked, disables anti-aliasing, increases performance\nat the cost of sharper visuals.\nEditing this switches Quality to Custom.',
			'antialiasing',
			BOOL);
		option.onChange = function() {
			onManualGraphicsEdit();
			onChangeAntiAliasing();
		};
		addOption(option);
		antialiasingOption = optionsArray.length-1;

		var option:Option = new Option('Shaders',
			"If unchecked, disables shaders.\nIt's used for some visual effects, and also CPU intensive for weaker " + Main.platform + ".\nEditing this switches Quality to Custom.",
			'shaders',
			BOOL);
		option.onChange = onManualGraphicsEdit;
		addOption(option);

		var option:Option = new Option('GPU Caching',
			"If checked, allows the GPU to be used for caching textures, decreasing RAM usage.\nEditing this switches Quality to Custom.",
			'cacheOnGPU',
			BOOL);
		option.onChange = onManualGraphicsEdit;
		addOption(option);

		#if !html5 //Apparently other framerates isn't correctly supported on Browser? Probably it has some V-Sync shit enabled by default, idk
		var option:Option = new Option('Framerate',
			"Pretty self explanatory, isn't it?",
			'framerate',
			INT);
		addOption(option);

		final refreshRate:Int = FlxG.stage.application.window.displayMode.refreshRate;
		option.minValue = 60;
		option.maxValue = 240;
		option.defaultValue = Std.int(FlxMath.bound(refreshRate, option.minValue, option.maxValue));
		option.displayFormat = '%v FPS';
		option.onChange = function() {
			onManualGraphicsEdit();
			onChangeFramerate();
		};
		#end

		var option:Option = new Option('FPS Rework',
			"If checked, this works around the game becoming \"slow\" and \"smooth\" when the current FPS is lower than the FPS cap.",
			'fpsRework',
			BOOL);
		addOption(option);

		var option:Option = new Option('Unlimited FPS',
			"If checked, removes the FPS cap (runs as high as your device allows).\nFramerate option is ignored while this is on.\nEditing this switches Quality to Custom.",
			'unlimitedFPS',
			BOOL);
		option.onChange = function() {
			onManualGraphicsEdit();
			onChangeFramerate();
		};
		addOption(option);

		super();
		insert(1, boyfriend);
	}

	function onChangeGraphicsQuality()
	{
		var deviceQ:String = ClientPrefs.getMaxDeviceQuality();
		var q:String = ClientPrefs.data.graphicsQuality;
		if (q != 'Custom')
			q = deviceQ;
		ClientPrefs.data.graphicsQuality = q;
		ClientPrefs.applyGraphicsQuality(q);
		onChangeFramerate();
		onChangeAntiAliasing();
		// refresh description on the quality option if possible
		for (opt in optionsArray)
		{
			if (opt != null && opt.variable == 'graphicsQuality')
			{
				opt.description = ClientPrefs.getGraphicsQualityDescription(q);
				break;
			}
		}
	}

	function onManualGraphicsEdit()
	{
		ClientPrefs.data.graphicsQuality = 'Custom';
	}

	function onChangeAntiAliasing()
	{
		for (sprite in members)
		{
			var sprite:FlxSprite = cast sprite;
			if(sprite != null && (sprite is FlxSprite) && !(sprite is FlxText)) {
				sprite.antialiasing = ClientPrefs.data.antialiasing;
			}
		}
	}

	function onChangeFramerate()
	{
		var fps:Int = ClientPrefs.data.unlimitedFPS ? 999 : ClientPrefs.data.framerate;
		if(fps > FlxG.drawFramerate)
		{
			if (ClientPrefs.data.fpsRework)
				FlxG.stage.window.frameRate = fps;
			else
			{
				FlxG.updateFramerate = fps;
				FlxG.drawFramerate = fps;
			}
		}
		else
		{
			if (ClientPrefs.data.fpsRework)
				FlxG.stage.window.frameRate = fps;
			else
			{
				FlxG.drawFramerate = fps;
				FlxG.updateFramerate = fps;
			}
		}
	}

	override function changeSelection(change:Int = 0)
	{
		super.changeSelection(change);
		boyfriend.visible = (antialiasingOption == curSelected);
	}
}
