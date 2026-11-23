package states;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.math.FlxMath;
import flixel.input.keyboard.FlxKey;
import haxe.io.Path;
import backend.WeekData;
import objects.Character;
#if sys
import sys.FileSystem;
#end

/**
 * Character skin select menu (mobile friendly).
 *
 * - Scans assets/base_game/shared/characters (+ other asset folders) and every enabled mod.
 * - Stores the choice in ClientPrefs.data.currentSkin.
 * - Uses ONLY the default camera (no extra FlxCamera) and its own touch buttons,
 *   so it can't hit the "TouchButton -> FlxPointer.getWorldPosition null object" crash.
 */
class SkinsState extends MusicBeatState
{
	static var BLACKLISTED_CHARACTERS = ['default'];
	public static var LEFT_SUFFIX = ['-opponent', '-left'];
	public static var RIGHT_SUFFIX = ['-player', '-playable', '-right'];
	static var SKIP_SUFFICES = ['-pixel', '-christmas', '-car', '-blazin'];

	/** Folders that can hold base game character jsons (first ones are the engine's real path). */
	static var BASE_CHARACTER_DIRS = [
		'assets/base_game/shared/characters/',
		'assets/shared/characters/',
		'assets/base_game/characters/',
		'assets/characters/'
	];

	/** Same zoom the original character camera used. */
	static inline var CHAR_ZOOM:Float = 0.8;

	var charactersWithWeeks:Array<Int> = [];
	// [character_name, left_suffix, right_suffix, mod_folder]
	var charactersList:Array<Array<String>> = [];
	static var curCharacter:Int = -1;

	var character:FlxTypedGroup<Character>;

	var charSelect:FlxText;
	var charInfo:FlxText;

	var bg:FlxSprite;
	var title:Alphabet;

	var arrowLeft:Alphabet;
	var arrowRight:Alphabet;
	var alX:Float = 0;
	var arX:Float = 0;

	static var flipped:Bool = false;
	static var backClass:Class<Dynamic>;

	var reloadedState:Bool = false;
	var ready:Bool = false;

	var blackRectangle:FlxSprite;

	static var staticSound:FlxSound;
	static var favSound:FlxSound;
	static var unfavSound:FlxSound;
	public static var music:FlxSound;

	static var prevConBPM:Float;
	static var prevConBPMChanges:Array<backend.BPMChangeEvent>;
	static var prevConTime:Float;

	var staticMan:FlxSprite;
	var selectTimer:FlxTimer;

	var camFollow:FlxObject;

	var stageObjects:Array<FlxSprite> = [];

	// touch ui

	var scanLog:String = '';

	public function new()
	{
		super();

		if (FlxG.state is SkinsState)
		{
			reloadedState = true;
			return;
		}

		backClass = Type.getClass(FlxG.state);
	}

	override function create()
	{
		Paths.clearUnusedMemory();
		Paths.clearStoredMemory();

		#if DISCORD_ALLOWED
		DiscordClient.changePresence("Selecting Skin", null, null, false);
		#end

		Mods.loadTopMod();
		WeekData.setDirectoryFromWeek();

		if (!reloadedState)
		{
			for (v in [FlxG.sound.music, FreeplayState.vocals, FreeplayState.opponentVocals])
			{
				if (v == null) continue;
				v.pause();
			}

			prevConBPM = Conductor.bpm;
			prevConBPMChanges = Conductor.bpmChangeMap;
			prevConTime = Conductor.songPosition;

			if (music != null)
				music.stop();

			try
			{
				music = FlxG.sound.play(Paths.music('stayFunky'), 1, true);
				music.persist = true;
				FlxG.sound.list.add(music);
			}
			catch (e:Dynamic)
			{
				music = null;
			}

			Conductor.bpm = 90;
			Conductor.bpmChangeMap = [];
			Conductor.songPosition = 0;
		}

		// Everything lives on the DEFAULT camera. HUD pieces use scrollFactor 0.
		camFollow = new FlxObject(FlxG.width / 2, FlxG.height / 2 - 200, 1, 1);
		camera.follow(camFollow, LOCKON, 0.05);
		camera.snapToTarget();
		camFollow.setPosition(FlxG.width / 2, FlxG.height / 2);

		blackRectangle = new FlxSprite();
		blackRectangle.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		blackRectangle.scrollFactor.set(0, 0);

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xff303030;
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, 0);
		add(bg);

		stageObjects = [bg];

		if (!ClientPrefs.data.lowQuality)
		{
			try
			{
				var stageBg = new FlxSprite(0, -220).loadGraphic(Paths.image('charSelect/charSelectBG'));
				stageBg.setGraphicSize(Std.int(stageBg.width * 1.1));
				stageBg.updateHitbox();
				stageBg.antialiasing = ClientPrefs.data.antialiasing;
				stageBg.screenCenter(X);
				stageBg.scrollFactor.set(0.5, 0.5);
				add(stageBg);

				var stageCrowd:FlxSprite = makeAnimate(0, 240, 'charSelect/crowd', 'crowd', 0.7);

				var stage = new FlxSprite(0, 390);
				stage.antialiasing = ClientPrefs.data.antialiasing;
				stage.frames = Paths.getSparrowAtlas('charSelect/charSelectStage');
				stage.animation.addByPrefix('idle', "stage full instance 1", 24);
				stage.animation.play('idle');
				stage.updateHitbox();
				stage.screenCenter(X);
				stage.scrollFactor.set(0.9, 0.9);
				add(stage);

				var lights:Array<FlxSprite> = [];
				try
				{
					for (lx in [200, 700])
					{
						var light = new FlxSprite(lx, 280).loadGraphic(Paths.image('charSelect/charLight'));
						light.antialiasing = ClientPrefs.data.antialiasing;
						light.scrollFactor.set(0.75, 0.75);
						add(light);
						lights.push(light);
					}
				}
				catch (e:Dynamic) {}

				var stageCurtain = new FlxSprite(0, 0).loadGraphic(Paths.image('charSelect/curtains'));
				stageCurtain.setGraphicSize(Std.int(stageCurtain.width * 1.05));
				stageCurtain.updateHitbox();
				stageCurtain.antialiasing = ClientPrefs.data.antialiasing;
				stageCurtain.screenCenter(XY);
				stageCurtain.scrollFactor.set(0.95, 0.1);
				add(stageCurtain);

				var stageSpeakers:FlxSprite = makeAnimate(-80, 440, 'charSelect/charSelectSpeakers', 'Speakers ALL', 0.95);
				var defaultGirlfriend:FlxSprite = makeAnimate(-80, 440, 'charSelect/gfChill', 'GIRLFRIEND CS', 0.95);

				stageObjects = [stageBg, stage, stageCurtain];
				for (o in [stageCrowd, stageSpeakers, defaultGirlfriend])
					if (o != null) stageObjects.push(o);
				for (l in lights)
					stageObjects.push(l);
			}
			catch (e:Dynamic) {}
		}

		var oldModDir = Mods.currentModDirectory;
		scanCharacters();
		Mods.currentModDirectory = oldModDir;

		try
		{
			if (favSound == null)
			{
				favSound = new FlxSound();
				favSound.loadEmbedded(Paths.sound('fav'));
				favSound.persist = true;
			}
			if (unfavSound == null)
			{
				unfavSound = new FlxSound();
				unfavSound.loadEmbedded(Paths.sound('unfav'));
				unfavSound.persist = true;
			}
			if (staticSound == null)
			{
				staticSound = new FlxSound();
				staticSound.loadEmbedded(Paths.sound('static loop'));
				staticSound.persist = true;
			}
		}
		catch (e:Dynamic) {}

		character = new FlxTypedGroup<Character>();
		add(character);

		staticMan = new FlxSprite();
		staticMan.antialiasing = ClientPrefs.data.antialiasing;
		try
		{
			staticMan.frames = Paths.getSparrowAtlas('randomChill');
			staticMan.animation.addByPrefix('idle', "LOCKED MAN instance 1", 24);
			staticMan.animation.play('idle');
		}
		catch (e:Dynamic)
		{
			staticMan.makeGraphic(200, 400, FlxColor.GRAY);
		}
		staticMan.flipX = !flipped;
		staticMan.updateHitbox();
		staticMan.screenCenter(XY);
		staticMan.y += 50;
		add(staticMan);

		var barUp = new FlxSprite();
		barUp.makeGraphic(FlxG.width, 100, FlxColor.BLACK);
		barUp.scrollFactor.set(0, 0);
		add(barUp);

		var barDown = new FlxSprite();
		barDown.makeGraphic(FlxG.width, 100, FlxColor.BLACK);
		barDown.y = FlxG.height - barDown.height;
		barDown.scrollFactor.set(0, 0);
		add(barDown);

		title = new Alphabet(0, 0, "BOYFRIEND", true);
		title.scrollFactor.set(0, 0);
		title.y = barUp.height / 2 - title.height / 2;
		title.x = FlxG.width / 2 - title.width / 2;
		add(title);

		arrowLeft = new Alphabet(0, 0, "<", true);
		arrowLeft.scrollFactor.set(0, 0);
		arrowLeft.y = FlxG.height / 2 - arrowLeft.height / 2;
		arrowLeft.x = alX = 100;
		add(arrowLeft);

		arrowRight = new Alphabet(0, 0, ">", true);
		arrowRight.scrollFactor.set(0, 0);
		arrowRight.y = FlxG.height / 2 - arrowRight.height / 2;
		arrowRight.x = arX = FlxG.width - arrowRight.width - 100;
		add(arrowRight);

		// ---- bottom bar texts (like the original) ----
		charSelect = new FlxText(0, 0, FlxG.width);
		#if mobile
		charSelect.text = 'Press A to select!';
		#else
		charSelect.text = 'Press ACCEPT to select!';
		#end
		charSelect.setFormat("VCR OSD Mono", 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		charSelect.y = barDown.y + barDown.height / 2 - charSelect.height / 2;
		charSelect.alpha = 0.8;
		charSelect.scrollFactor.set(0, 0);
		add(charSelect);

		charInfo = new FlxText(0, 0, FlxG.width);
		charInfo.setFormat("VCR OSD Mono", 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		charInfo.y = barDown.y - 30;
		charInfo.scrollFactor.set(0, 0);
		charInfo.visible = false;
		add(charInfo);

		#if mobile
		var tip1 = new FlxText(20, 0, 400, 'A - Select\nB - Back\nQ - Add/remove favorite\nD - Next favorite\nC - Flip skin');
		#else
		var tip1 = new FlxText(20, 0, 400, 'TAB - Flip skin\nQ - Add/remove favorite\nF - Next favorite (SHIFT+F back)\nRESET - None');
		#end
		tip1.setFormat("VCR OSD Mono", 13, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tip1.y = barDown.y + (barDown.height - tip1.height) / 2;
		tip1.alpha = 0.6;
		tip1.scrollFactor.set(0, 0);
		add(tip1);

		#if mobile
		// on-screen buttons, same idea as the original mobile layout: Q C B A
		final bs:Int = 72;
		final gap:Int = 12;
		final by:Float = barDown.y + (barDown.height - bs) / 2;
		var bx:Float = FlxG.width - 5 * (bs + gap);
		addTouchButton('D', 'favjump', bx, by, bs, FlxColor.fromRGB(40, 90, 230));
		addTouchButton('Q', 'fav', bx + (bs + gap), by, bs, FlxColor.fromRGB(140, 90, 220));
		addTouchButton('C', 'flip', bx + 2 * (bs + gap), by, bs, FlxColor.fromRGB(60, 190, 80));
		addTouchButton('B', 'back', bx + 3 * (bs + gap), by, bs, FlxColor.fromRGB(230, 190, 40));
		addTouchButton('A', 'accept', bx + 4 * (bs + gap), by, bs, FlxColor.fromRGB(220, 50, 50));
		#end

		if ((animateLog != '' && !ClientPrefs.data.lowQuality) || touchLog != '')
		{
			var dbgText:String = '';
			if (animateLog != '') dbgText += 'Animate atlas problem:\n' + animateLog;
			if (touchLog != '') dbgText += 'Touch button PNG not found for: ' + touchLog + '(drawn square used)\n';
			var dbg = new FlxText(10, 104, FlxG.width - 20, dbgText);
			dbg.setFormat("VCR OSD Mono", 12, FlxColor.YELLOW, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			dbg.alpha = 0.7;
			dbg.scrollFactor.set(0, 0);
			add(dbg);
		}

		tweenColor(FlxColor.fromHSL(180, 1, 0.5));
		if (colorTweens != null)
			for (tween in colorTweens)
				tween.duration = 0;

		setCharacter(0);

		super.create();
		ready = true;
	}

	var animateLog:String = '';

	static var ATLAS_IMAGE_DIRS = [
		'assets/base_game/shared/images/',
		'assets/shared/images/',
		'assets/base_game/images/',
		'assets/images/'
	];

	/** Folder of an animate atlas on disk (the atlases are FOLDERS: Animation.json + spritemap). */
	function findAtlasDir(folder:String):String
	{
		#if sys
		for (prefix in ATLAS_IMAGE_DIRS)
		{
			var dir = prefix + folder;
			try { if (FileSystem.exists(dir) && FileSystem.isDirectory(dir)) return dir; } catch (e:Dynamic) {}
		}
		#end
		return null;
	}

	function createAnimateInstance(cls:Class<Dynamic>, x:Float, y:Float, path:String):Dynamic
	{
		var tries:Array<Array<Dynamic>> = (path != null) ? [[x, y, path, null], [x, y, path]] : [[x, y, null, null], [x, y, null], [x, y]];
		var last:Dynamic = 'could not create instance';
		for (a in tries)
		{
			try { return Type.createInstance(cls, a); }
			catch (e:Dynamic) { last = e; }
		}
		throw last;
	}

	function callPathsLoader(spr:Dynamic, folder:String):Void
	{
		var pathsCls:Class<Dynamic> = Type.resolveClass('backend.Paths');
		if (pathsCls == null) pathsCls = Type.resolveClass('Paths');
		var loader:Dynamic = (pathsCls != null) ? Reflect.field(pathsCls, 'loadAnimateAtlas') : null;
		if (loader == null)
			throw 'Paths.loadAnimateAtlas not found';

		try { Reflect.callMethod(pathsCls, loader, [spr, folder, null, null]); }
		catch (e:Dynamic) { Reflect.callMethod(pathsCls, loader, [spr, folder]); }
	}

	/**
	 * Creates a Flash/Animate atlas sprite (crowd, speakers, gf...) without hard-linking the class.
	 * Tries: Paths.loadAnimateAtlas -> loadAtlas(folder on disk) -> constructor(folder on disk).
	 * Returns null (and fills animateLog with the exact step that failed) when nothing works.
	 */
	function makeAnimate(x:Float, y:Float, folder:String, symbol:String, scroll:Float):FlxSprite
	{
		var errors:String = '';
		var absDir:String = findAtlasDir(folder);
		if (absDir == null)
			errors += '\n  folder not found in: ' + ATLAS_IMAGE_DIRS.join(', ');

		for (cn in ['flxanimate.FlxAnimate', 'flxanimate.PsychFlxAnimate'])
		{
			var cls:Class<Dynamic> = Type.resolveClass(cn);
			if (cls == null)
				continue;

			for (mode in 1...4)
			{
				var step:String = 'create';
				try
				{
					var spr:Dynamic = createAnimateInstance(cls, x, y, (mode == 3) ? absDir : null);
					if (spr == null) throw 'instance is null';

					step = 'load';
					if (mode == 1)
						callPathsLoader(spr, folder);
					else if (absDir == null)
						throw 'no folder on disk';
					else if (mode == 2)
						spr.loadAtlas(absDir);

					step = 'anim';
					if (spr.anim == null) throw 'anim is null';

					step = 'symbol';
					try { spr.anim.addBySymbol('beat', symbol, 24, true); }
					catch (e:Dynamic) { errors += '\n  (symbol "' + symbol + '": ' + Std.string(e) + ')'; }

					step = 'play';
					spr.anim.play('beat');
					spr.antialiasing = ClientPrefs.data.antialiasing;
					spr.scrollFactor.set(scroll, scroll);
					add(spr);
					return cast spr;
				}
				catch (e:Dynamic)
				{
					errors += '\n  ' + cn.substr(cn.lastIndexOf('.') + 1) + ' #' + mode + ' ' + step + ': ' + Std.string(e);
				}
			}
		}

		animateLog += folder + errors + '\n';
		return null;
	}

	var touchBtns:Array<{spr:FlxSprite, action:String}> = [];
	var touchLog:String = '';

	/** letter (lowercase) -> png path, found once by scanning the engine's mobile/touchpad assets */
	static var touchPngCache:Map<String, String> = null;

	static function indexTouchPngs():Void
	{
		touchPngCache = new Map();
		#if sys
		var skip = ['songs', 'music', 'sounds', 'videos', 'fonts', 'data', 'characters', 'characters_weeks', 'weeks', 'stages',
			'scripts', 'custom_events', 'custom_notetypes', 'shaders', 'achievements', 'locales', 'jsons'];

		function walk(dir:String, depth:Int, inTouch:Bool):Void
		{
			if (depth > 7) return;
			var items:Array<String> = [];
			try { items = FileSystem.readDirectory(dir); } catch (e:Dynamic) { return; }

			for (it in items)
			{
				var full = dir + '/' + it;
				var low = it.toLowerCase();
				var isDir = false;
				try { isDir = FileSystem.isDirectory(full); } catch (e:Dynamic) {}

				if (isDir)
				{
					if (skip.contains(low)) continue;
					walk(full, depth + 1, inTouch || low.indexOf('touch') != -1 || low.indexOf('mobile') != -1);
				}
				else if (inTouch && StringTools.endsWith(low, '.png'))
				{
					var base = low.substr(0, low.length - 4);
					var old = touchPngCache.get(base);
					// prefer files inside a "touchpad" folder
					if (old == null || (old.toLowerCase().indexOf('touchpad') == -1 && full.toLowerCase().indexOf('touchpad') != -1))
						touchPngCache.set(base, full);
				}
			}
		}
		walk('assets', 0, false);
		#end
	}

	function loadPngSprite(path:String, size:Int, x:Float, y:Float):FlxSprite
	{
		#if sys
		try
		{
			var bmd = openfl.display.BitmapData.fromFile(path);
			if (bmd == null) return null;
			var sp = new FlxSprite(x, y);
			sp.loadGraphic(bmd);
			sp.setGraphicSize(size);
			sp.updateHitbox();
			sp.x = x;
			sp.y = y;
			sp.antialiasing = ClientPrefs.data.antialiasing;
			sp.scrollFactor.set(0, 0);
			add(sp);
			return sp;
		}
		catch (e:Dynamic) {}
		#end
		return null;
	}

	function dirOf(path:String):String
	{
		if (path == null) return null;
		var i = path.lastIndexOf('/');
		return i == -1 ? '' : path.substr(0, i);
	}

	/** Uses the engine's own mobile button PNGs; falls back to a drawn square only if they can't be found. */
	function addTouchButton(letter:String, action:String, x:Float, y:Float, size:Int, color:FlxColor):Void
	{
		if (touchPngCache == null)
			indexTouchPngs();

		var glyphPath:String = touchPngCache.get(letter.toLowerCase());
		var bgPath:String = touchPngCache.get('bg');
		var main:FlxSprite = null;
		var needLetterText:Bool = false;

		// background + glyph in the same folder (tinted background style)
		if (glyphPath != null && bgPath != null && dirOf(glyphPath) == dirOf(bgPath))
		{
			main = loadPngSprite(bgPath, size, x, y);
			if (main != null)
			{
				main.color = color;
				loadPngSprite(glyphPath, size, x, y);
			}
		}

		// glyph only: it is the whole button
		if (main == null && glyphPath != null)
			main = loadPngSprite(glyphPath, size, x, y);

		// background exists but this letter has no png (e.g. Q): bg + text
		if (main == null && bgPath != null)
		{
			main = loadPngSprite(bgPath, size, x, y);
			if (main != null)
			{
				main.color = color;
				needLetterText = true;
			}
		}

		// nothing found: simple square
		if (main == null)
		{
			main = new FlxSprite(x, y);
			main.makeGraphic(size, size, FlxColor.WHITE);
			main.color = color;
			main.alpha = 0.8;
			main.scrollFactor.set(0, 0);
			add(main);
			needLetterText = true;
			if (touchLog.indexOf(letter) == -1)
				touchLog += letter + ' ';
		}
		else if (glyphPath == null && !needLetterText)
			needLetterText = true;

		if (needLetterText)
		{
			var t = new FlxText(x, 0, size, letter);
			t.setFormat("VCR OSD Mono", 40, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
			t.y = y + (main.height - t.height) / 2;
			t.scrollFactor.set(0, 0);
			add(t);
		}

		touchBtns.push({spr: main, action: action});
	}

	function getEntry(i:Int):Array<String>
	{
		return (i >= 0 && i < charactersList.length) ? charactersList[i] : null;
	}

	// ------------------------------------------------------------------
	//  Character discovery
	// ------------------------------------------------------------------

	var weeksKeys:Map<String, Bool> = new Map();

	/** NONE is always first, then bf, pico, tankman, then mod characters in scan order. */
	function finalizeList():Void
	{
		var order = ['bf', 'pico', 'tankman'];
		var items:Array<{e:Array<String>, i:Int}> = [];
		for (i in 0...charactersList.length)
			items.push({e: charactersList[i], i: i});

		function weight(e:Array<String>):Int
		{
			if (e[3] == '')
			{
				var k = order.indexOf(e[0]);
				if (k != -1) return k;
			}
			return 100;
		}

		items.sort(function(a, b)
		{
			var wa = weight(a.e);
			var wb = weight(b.e);
			return (wa != wb) ? (wa - wb) : (a.i - b.i);
		});

		charactersList = [for (it in items) it.e];
		charactersWithWeeks = [];
		for (i in 0...charactersList.length)
		{
			var e = charactersList[i];
			if (weeksKeys.exists(e[0] + '|' + e[3]))
				charactersWithWeeks.push(i);
			if (isEquipped(i))
				curCharacter = i;
		}
	}

	function scanCharacters()
	{
		charactersList = [];
		charactersWithWeeks = [];
		weeksKeys = new Map();
		scanLog = '';

		var seen:Map<String, Bool> = new Map();

		// 1) base game: every existing known folder (the engine's real one is assets/base_game/shared/characters)
		Mods.loadTopMod();
		var baseDirs:Array<String> = BASE_CHARACTER_DIRS.copy();
		try
		{
			var p:String = Paths.getSharedPath('characters/');
			if (p != null && baseDirs.indexOf(p) == -1)
				baseDirs.insert(0, p);
		}
		catch (e:Dynamic) {}

		for (dir in baseDirs)
			scanDirectory(dir, StringTools.replace(dir, 'characters/', 'characters_weeks/'), null, seen);

		// 2) mods
		var mods:Array<String> = [];
		#if MODS_ALLOWED
		try
		{
			for (m in Mods.parseList().enabled)
				mods.push(m);
		}
		catch (e:Dynamic) {}
		#end

		for (m in mods)
		{
			Mods.currentModDirectory = m;
			scanDirectory(Paths.mods(m + '/characters/'), Paths.mods(m + '/characters_weeks/'), m, seen);
		}

		// global mods/characters
		try
		{
			scanDirectory(Paths.mods('characters/'), Paths.mods('characters_weeks/'), null, seen);
		}
		catch (e:Dynamic) {}

		Mods.loadTopMod();
		finalizeList();
	}

	function scanDirectory(charactersDir:String, charactersWeeksDir:String, origin:String, seen:Map<String, Bool>):Void
	{
		if (charactersDir == null)
			return;

		var exists:Bool = false;
		try { exists = FileSystem.exists(charactersDir) && FileSystem.isDirectory(charactersDir); } catch (e:Dynamic) {}
		if (!exists)
			return;

		var files:Array<String> = [];
		try { files = FileSystem.readDirectory(charactersDir); } catch (e:Dynamic) { files = []; }
		scanLog += charactersDir + ' (' + files.length + ')\n';

		var modFolder:String = (origin == null) ? '' : origin;
		var charSkipSearch:Array<String> = [];

		function jsonExists(name:String):Bool
		{
			try { return FileSystem.exists(Path.join([charactersDir, name + '.json'])); } catch (e:Dynamic) {}
			return false;
		}

		function addCharacter(characterName:String, leftSuffix:String, rightSuffix:String):Bool
		{
			if (BLACKLISTED_CHARACTERS.contains(characterName))
				return false;
			for (suffix in SKIP_SUFFICES)
				if (StringTools.endsWith(characterName, suffix))
					return false;

			// Base game: ONLY bf, pico-playable and tankman-playable. Mods are not limited.
			if (origin == null && modFolder == '')
			{
				if (characterName == 'bf') {}
				else if ((characterName == 'pico' || characterName == 'tankman') && rightSuffix != '') {}
				else
					return false;
			}

			var key = characterName + '|' + modFolder;
			if (seen.exists(key))
				return false;
			seen.set(key, true);

			charactersList.push([characterName, leftSuffix, rightSuffix, modFolder]);
			charSkipSearch.push(characterName + leftSuffix);
			charSkipSearch.push(characterName + rightSuffix);

			try
			{
				if (charactersWeeksDir != null && FileSystem.exists(Path.join([charactersWeeksDir, characterName + ".json"])))
					weeksKeys.set(characterName + '|' + modFolder, true);
			}
			catch (e:Dynamic) {}

			return true;
		}

		for (file in files)
		{
			if (file == null || !StringTools.endsWith(file, '.json'))
				continue;

			var character:String = file.substr(0, file.length - 5);
			if (charSkipSearch.contains(character))
				continue;

			var hasAdded = false;

			// character-player / -playable / -right  (+ optional left side)
			for (playableSuffix in RIGHT_SUFFIX)
			{
				if (StringTools.endsWith(character, playableSuffix))
				{
					final cutCharName = character.substr(0, character.length - playableSuffix.length);

					var leftSuffix = '';
					for (opponentSuffix in LEFT_SUFFIX)
						if (jsonExists(cutCharName + opponentSuffix))
							leftSuffix += opponentSuffix;

					if (jsonExists(cutCharName))
					{
						hasAdded = addCharacter(cutCharName, leftSuffix, playableSuffix);
						break;
					}
				}
			}
			if (hasAdded) continue;

			// character-opponent / -left  (+ right side)
			for (opponentSuffix in LEFT_SUFFIX)
			{
				if (StringTools.endsWith(character, opponentSuffix))
				{
					final cutCharName = character.substr(0, character.length - opponentSuffix.length);

					var rightSuffix = '';
					for (playableSuffix in RIGHT_SUFFIX)
						if (jsonExists(cutCharName + playableSuffix))
							rightSuffix += playableSuffix;

					if (jsonExists(cutCharName + rightSuffix))
					{
						hasAdded = addCharacter(cutCharName, opponentSuffix, rightSuffix);
						break;
					}
				}
			}
			if (hasAdded) continue;

			// plain characters (bf, dad, gf, ...): same json for both sides
			if (character.indexOf('-') == -1)
				addCharacter(character, '', '');
		}
	}

	function getCharacterName(i:Int):String
	{
		final character = getEntry(i);
		if (character == null) return null;
		return character[0] + character[flipped ? 2 : 1];
	}

	// ------------------------------------------------------------------
	//  Actions (keyboard + touch share these)
	// ------------------------------------------------------------------

	var acceptSound:FlxSound;
	var stopUpdates:Bool = false;
	var isExiting:Bool = false;
	var heyWait:Float = -1;
	var leftHoldTime:Float = 0;
	var rightHoldTime:Float = 0;

	function pressButton(b:FlxSprite):Void
	{
		if (b == null) return;
		FlxTween.cancelTweensOf(b);
		b.alpha = 0.5;
		FlxTween.tween(b, {alpha: 1}, 0.25);
	}

	function acceptSkin():Void
	{
		if (selectTimer != null && !selectTimer.finished)
		{
			selectTimer.onComplete(selectTimer);
			selectTimer.cancel();
		}

		ClientPrefs.data.currentSkin = getEntry(curCharacter);
		ClientPrefs.saveSettings();
		updateTexts();

		if (acceptSound != null) acceptSound.stop();
		try { acceptSound = FlxG.sound.play(Paths.sound('CS_confirm'), 0.8); } catch (e:Dynamic) {}
		if (music != null) music.stop();

		playCheer();

		// wait for the cheer ("hey") animation, THEN close slowly (handled in update)
		stopUpdates = true;
		heyWait = 0;
	}

	var cheerAnim:String = '';

	/** Works for normal (sparrow) AND atlas characters, without needing a specific Character API. */
	function charHasAnim(c:Character, name:String):Bool
	{
		try { if (c.animation != null && c.animation.getByName(name) != null) return true; } catch (e:Dynamic) {}
		try
		{
			var f:Dynamic = Reflect.field(c, 'hasAnimation');
			if (f != null && Reflect.callMethod(c, f, [name]) == true) return true;
		}
		catch (e:Dynamic) {}
		try
		{
			var m:Dynamic = Reflect.field(c, 'animOffsets');
			if (m != null && m.exists(name) == true) return true;
		}
		catch (e:Dynamic) {}
		return false;
	}

	/**
	 * Cheer for EVERY character: uses "hey" (or cheer/celebrate/taunt) when the character has it,
	 * otherwise raises the arms (singUP) and does two little hops.
	 */
	function playCheer():Void
	{
		var c = character.members[0];
		if (c == null) return;

		cheerAnim = '';
		for (name in ['hey', 'cheer', 'celebrate', 'taunt'])
		{
			if (charHasAnim(c, name))
			{
				cheerAnim = name;
				break;
			}
		}

		if (cheerAnim != '')
		{
			c.playAnim(cheerAnim, true);
			return;
		}

		c.playAnim('singUP', true);
		var baseY:Float = c.y;
		FlxTween.cancelTweensOf(c);
		FlxTween.tween(c, {y: baseY - 45}, 0.18, {ease: FlxEase.quadOut, onComplete: function(_)
		{
			FlxTween.tween(c, {y: baseY}, 0.22, {ease: FlxEase.quadIn, onComplete: function(_)
			{
				FlxTween.tween(c, {y: baseY - 30}, 0.15, {ease: FlxEase.quadOut, onComplete: function(_)
				{
					FlxTween.tween(c, {y: baseY}, 0.2, {ease: FlxEase.quadIn});
				}});
			}});
		}});
	}

	function goBack():Void
	{
		stopUpdates = true;
		leaveMenu(0.5);
	}

	function flipSkin():Void
	{
		flipped = !flipped;
		prevCharacter = null;
		setCharacter(0);
	}

	function toggleFavorite():Void
	{
		var entry = getEntry(curCharacter);
		if (entry == null) return;

		final charId = entry[0] + ':' + entry[3];
		if (ClientPrefs.data.favSkins == null)
			ClientPrefs.data.favSkins = [];

		if (ClientPrefs.data.favSkins.contains(charId))
		{
			ClientPrefs.data.favSkins.remove(charId);
			if (unfavSound != null) { unfavSound.volume = 1; unfavSound.play(true); }
			if (character.members[0] != null) character.members[0].playAnim("hurt", true);
		}
		else
		{
			ClientPrefs.data.favSkins.push(charId);
			if (favSound != null) { favSound.volume = 1; favSound.play(true); }
			if (character.members[0] != null) character.members[0].playAnim("hey", true);
		}
		updateTexts();
		ClientPrefs.saveSettings();
	}

	/** Own touch / mouse handling: no TouchPad, no camera lookups. Coordinates are game (screen) coordinates. */
	function handlePointer():Void
	{
		var px:Float = -1;
		var py:Float = -1;
		var pressed:Bool = false;

		#if FLX_TOUCH
		for (t in FlxG.touches.list)
		{
			if (t != null && t.justPressed)
			{
				px = t.screenX;
				py = t.screenY;
				pressed = true;
				break;
			}
		}
		#end
		#if FLX_MOUSE
		if (!pressed && FlxG.mouse.justPressed)
		{
			px = FlxG.mouse.screenX;
			py = FlxG.mouse.screenY;
			pressed = true;
		}
		#end

		if (!pressed)
			return;

		// letter buttons (mobile)
		for (tb in touchBtns)
		{
			if (px >= tb.spr.x && px <= tb.spr.x + tb.spr.width && py >= tb.spr.y && py <= tb.spr.y + tb.spr.height)
			{
				pressButton(tb.spr);
				doAction(tb.action);
				return;
			}
		}

		final barH:Float = 100;

		// middle area: left / right edges change the character
		if (py > barH && py < FlxG.height - barH)
		{
			if (px < 260)
				setCharacter(-1);
			else if (px > FlxG.width - 260)
				setCharacter(1);
		}
	}

	function doAction(action:String):Void
	{
		switch (action)
		{
			case 'accept': acceptSkin();
			case 'back': goBack();
			case 'fav': toggleFavorite();
			case 'favjump': jumpToFavorite(1);
			case 'flip': flipSkin();
		}
	}

	function isFavorite(i:Int):Bool
	{
		var entry = getEntry(i);
		if (entry == null || ClientPrefs.data.favSkins == null)
			return false;
		return ClientPrefs.data.favSkins.contains(entry[0] + ':' + entry[3]);
	}

	/** Quick access: jumps straight to the next (dir >= 0) or previous favorite skin, wrapping around. */
	function jumpToFavorite(dir:Int = 1):Void
	{
		var favs:Array<Int> = [];
		for (i in 0...charactersList.length)
			if (isFavorite(i))
				favs.push(i);

		if (favs.length == 0)
		{
			charInfo.text = 'No favorite skins yet! Press Q on a skin to add it.';
			charInfo.visible = true;
			new FlxTimer().start(2.5, function(_) updateTexts());
			return;
		}

		var target:Int = -2;
		if (dir >= 0)
		{
			for (f in favs)
				if (f > curCharacter) { target = f; break; }
			if (target == -2)
				target = favs[0];
		}
		else
		{
			var k:Int = favs.length - 1;
			while (k >= 0)
			{
				if (favs[k] < curCharacter) { target = favs[k]; break; }
				k--;
			}
			if (target == -2)
				target = favs[favs.length - 1];
		}

		if (target == curCharacter)
		{
			charInfo.text = 'This is your only favorite skin.';
			charInfo.visible = true;
			new FlxTimer().start(2, function(_) updateTexts());
			return;
		}

		setCharacter(target - curCharacter);
	}

	override function update(elapsed:Float)
	{
		// a broken child object must never take the whole game down
		try
		{
			super.update(elapsed);
		}
		catch (e:Dynamic)
		{
			trace('SkinsState.update error: ' + e);
		}

		arrowLeft.x = FlxMath.lerp(arrowLeft.x, alX, elapsed * 10);
		arrowRight.x = FlxMath.lerp(arrowRight.x, arX, elapsed * 10);

		if (controls.UI_LEFT)
			leftHoldTime += elapsed;
		else
			leftHoldTime = 0;

		if (controls.UI_RIGHT)
			rightHoldTime += elapsed;
		else
			rightHoldTime = 0;

		camFollow.setPosition(FlxG.width / 2, FlxG.height / 2);

		if (heyWait >= 0 && !isExiting)
		{
			heyWait += elapsed;

			var c = character.members[0];
			var done:Bool = heyWait > 2.5;
			if (cheerAnim != '' && c != null && c.animation.curAnim != null && c.animation.curAnim.name == cheerAnim)
			{
				if (heyWait > 0.3 && c.animation.curAnim.finished)
					done = true;
			}
			else if (heyWait > 1.2)
				done = true; // hop-cheer finished

			if (done)
			{
				heyWait = -1;
				leaveMenu(1.4);
			}
		}

		if (stopUpdates)
		{
			if (isExiting)
				camFollow.y += !ClientPrefs.data.lowQuality ? 600 : 200;
			return;
		}

		if (music != null && music.playing)
			Conductor.songPosition = music.time;

		handlePointer();
		if (stopUpdates)
			return;

		if (FlxG.keys.pressed.SHIFT)
		{
			if (character.members[0] != null)
			{
				if (controls.NOTE_UP) character.members[0].playAnim("singUP");
				if (controls.NOTE_DOWN) character.members[0].playAnim("singDOWN");
				if (controls.NOTE_LEFT) character.members[0].playAnim("singLEFT");
				if (controls.NOTE_RIGHT) character.members[0].playAnim("singRIGHT");
			}
		}
		else
		{
			if (controls.UI_LEFT_P)
				setCharacter(-1);
			else if (controls.UI_RIGHT_P)
				setCharacter(1);
		}

		if (!FlxG.keys.pressed.SHIFT && controls.ACCEPT)
		{
			acceptSkin();
			return;
		}

		if (controls.BACK)
		{
			goBack();
			return;
		}

		if (FlxG.keys.justPressed.TAB)
			flipSkin();

		if (FlxG.keys.justPressed.F)
			jumpToFavorite(FlxG.keys.pressed.SHIFT ? -1 : 1);

		// Favorite (Q or fav bind)
		var favPressed = FlxG.keys.justPressed.Q;
		try
		{
			if (!favPressed && ClientPrefs.keyBinds.exists('fav'))
			{
				for (k in ClientPrefs.keyBinds.get('fav'))
					if (FlxG.keys.anyJustPressed([k])) favPressed = true;
			}
		}
		catch (e:Dynamic) {}

		if (favPressed)
			toggleFavorite();

		if (controls.RESET)
		{
			curCharacter = -2;
			setCharacter(1);
		}

		if (character.members[0]?.animation?.curAnim != null)
		{
			switch (character.members[0].animation.curAnim.name)
			{
				case 'singRIGHT': camFollow.x += 20;
				case 'singLEFT': camFollow.x -= 20;
				case 'singUP': camFollow.y -= 20;
				case 'singDOWN': camFollow.y += 20;
			}
		}
	}

	function leaveMenu(fade:Float = 0.5)
	{
		if (isExiting) return;
		isExiting = true;
		camera.follow(camFollow, LOCKON, 0.01);

		blackRectangle.alpha = 0;
		add(blackRectangle);
		FlxTween.tween(blackRectangle, {alpha: 1}, fade, {ease: FlxEase.quadInOut});

		if (music != null && music.playing)
			music.fadeOut(fade, 0);

		new FlxTimer().start(fade + 0.1, function(_)
		{
			if (music != null)
				music.stop();

			for (v in [FlxG.sound.music, FreeplayState.vocals, FreeplayState.opponentVocals])
			{
				if (v == null) continue;
				try
				{
					v.play();
					v.fadeIn(0.5, 0, 1);
				}
				catch (e:Dynamic) {}
			}

			Conductor.bpm = prevConBPM;
			Conductor.bpmChangeMap = prevConBPMChanges;
			Conductor.songPosition = prevConTime;

			var target:Class<Dynamic> = (backClass != null) ? backClass : MainMenuState;
			FlxG.switchState(Type.createInstance(target, []));
		});
	}

	// ------------------------------------------------------------------
	//  Showing a character
	// ------------------------------------------------------------------

	var prevCharacter:Null<Int> = null;

	function setCharacter(difference:Int, ?beatHold:Bool = false)
	{
		curCharacter += difference;

		if (curCharacter >= charactersList.length)
			curCharacter = beatHold ? -1 : charactersList.length - 1;
		else if (curCharacter < -1)
			curCharacter = beatHold ? charactersList.length - 1 : -1;

		if (curCharacter == prevCharacter)
			return;
		prevCharacter = curCharacter;

		if (ready)
		{
			if (difference > 0) arrowRight.x += 40;
			if (difference < 0) arrowLeft.x -= 40;
			if (difference != 0)
			{
				try { FlxG.sound.play(Paths.sound('CS_select'), 0.6); } catch (e:Dynamic) {}
			}
		}

		arrowLeft.visible = curCharacter > -1;
		arrowRight.visible = curCharacter < charactersList.length - 1;

		if (character.members[0] != null)
			character.members[0].destroy();
		character.clear();

		if (staticSound != null) staticSound.play(true);
		staticMan.visible = true;
		staticMan.flipX = !flipped;

		if (selectTimer != null)
			selectTimer.cancel();

		var entry = getEntry(curCharacter);
		if (entry != null)
		{
			final loadIndex = curCharacter;
			selectTimer = new FlxTimer().start(0.35, function(_)
			{
				var e = getEntry(loadIndex);
				if (e == null) return;

				var char:Character = null;
				var lastError:String = '';

				// 1) the exact side we want, 2) the plain name as a fallback
				for (name in [getCharacterName(loadIndex), e[0]])
				{
					if (name == null) continue;
					try
					{
						Mods.currentModDirectory = e[3];
						char = new Character(0, 0, name, !flipped);
						break;
					}
					catch (exc:Dynamic)
					{
						lastError = Std.string(exc);
						char = null;
					}
				}

				if (char == null)
				{
					staticMan.visible = true;
					charInfo.text = 'Failed to load: ' + getCharacterName(loadIndex) + '  (' + lastError + ')';
					charInfo.visible = true;
					trace('Failed to load skin: ' + lastError);
					return;
				}

				try
				{
					char.dance();
					placeCharacter(char);
					character.add(char);

					staticMan.visible = false;
					if (staticSound != null) staticSound.stop();

					var hca = char.healthColorArray;
					if (hca != null && hca.length >= 3)
						tweenColor(FlxColor.fromRGB(hca[0], hca[1], hca[2]));
				}
				catch (exc:Dynamic)
				{
					staticMan.visible = true;
					charInfo.text = 'Failed to show: ' + e[0] + '  (' + Std.string(exc) + ')';
					charInfo.visible = true;
				}
			});
		}
		else
		{
			if (staticSound != null) staticSound.stop();
			tweenColor(FlxColor.fromRGB(255, 255, 255));
		}

		updateTexts();
	}

	/**
	 * Centers the character on the stage: horizontally on the screen center, feet on a fixed floor,
	 * scaled like the original 0.8 camera zoom (and smaller if it would not fit between the bars).
	 */
	function placeCharacter(char:Character):Void
	{
		final floorY:Float = FlxG.height - 100 - 30;
		final centerX:Float = FlxG.width / 2;

		var fw:Float = char.frameWidth;
		var fh:Float = char.frameHeight;

		if (fw <= 0 || fh <= 0)
		{
			// atlas characters without a plain frame size: use the hitbox
			char.scale.x *= CHAR_ZOOM;
			char.scale.y *= CHAR_ZOOM;
			char.x = centerX - char.width / 2;
			char.y = floorY - char.height;
			return;
		}

		var maxH:Float = FlxG.height - 100 - 100 - 40;
		var f:Float = Math.min(CHAR_ZOOM, maxH / (fh * char.scale.y));
		char.scale.x *= f;
		char.scale.y *= f;

		var sx:Float = char.scale.x;
		var sy:Float = char.scale.y;
		var left:Float = char.x - char.offset.x + char.origin.x * (1 - sx);
		var top:Float = char.y - char.offset.y + char.origin.y * (1 - sy);

		char.x += centerX - (left + fw * sx / 2);
		char.y += floorY - (top + fh * sy);
	}

	function updateTexts()
	{
		var entry = getEntry(curCharacter);

		if (entry == null)
			title.text = curCharacter == -1 ? "(NONE)" : "-";
		else
			title.text = StringTools.replace(entry[0], '-', ' ');
		title.x = FlxG.width / 2 - title.width / 2;

		if (isEquipped(curCharacter))
		{
			charSelect.text = 'Selected!';
			charSelect.alpha = 1;
		}
		else
		{
			#if mobile
			charSelect.text = 'Press A to select!';
			#else
			charSelect.text = 'Press ACCEPT to select!';
			#end
			charSelect.alpha = 0.8;
		}

		charInfo.visible = false;
		charInfo.text = '';

		if (charactersList.length == 0)
		{
			charInfo.text = 'No characters found!\n' + (scanLog == '' ? 'Checked: ' + BASE_CHARACTER_DIRS.join(', ') : scanLog);
			charInfo.visible = true;
			charInfo.y = FlxG.height - 100 - charInfo.height;
		}

		if (charactersWithWeeks.contains(curCharacter))
		{
			charInfo.text = 'This Character has custom MIXES!';
			charInfo.visible = true;
		}

		if (entry != null)
		{
			final charId = entry[0] + ':' + entry[3];
			if (ClientPrefs.data.favSkins != null && ClientPrefs.data.favSkins.contains(charId))
			{
				charInfo.text += (charInfo.text.length > 0 ? ' ' : '') + '(Favorite Character)';
				charInfo.visible = true;
			}
		}
	}

	var colorTweens:Array<FlxTween> = [];

	function tweenColor(hueColor:FlxColor)
	{
		if (colorTweens != null)
			for (tween in colorTweens)
				tween.cancel();
		colorTweens = [];

		var color = new FlxColor(hueColor);
		color.lightness = Math.min(0.7, color.lightness);

		for (obj in stageObjects)
		{
			colorTweens.push(FlxTween.color(obj, 1, obj.color, color, {
				onComplete: function(twn:FlxTween)
				{
					colorTweens.remove(twn);
				},
				ease: FlxEase.quadOut
			}));
		}
	}

	function isEquipped(i:Int):Bool
	{
		var entry = getEntry(i);

		if (ClientPrefs.data.currentSkin == null)
			return entry == null;

		if (entry == null)
			return false;

		for (index => item in entry)
		{
			if (item != ClientPrefs.data.currentSkin[index])
				return false;
		}
		return true;
	}

	override function beatHit()
	{
		super.beatHit();

		if (staticMan != null && staticMan.visible && staticMan.animation != null)
			staticMan.animation.play('idle');

		if (stopUpdates) return;

		if (character.members[0]?.animation?.curAnim != null && character.members[0].animation.curAnim.finished)
			character.members[0].dance();
	}

	override function stepHit()
	{
		super.stepHit();

		if (!FlxG.keys.pressed.SHIFT)
		{
			if (leftHoldTime > 0.5)
				setCharacter(-1, true);
			else if (rightHoldTime > 0.5)
				setCharacter(1, true);
		}
	}

	override function destroy()
	{
		if (music != null)
		{
			music.stop();
			music = null;
		}
		super.destroy();
	}
}
