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
	var btnBack:FlxSprite;
	var btnSelect:FlxSprite;
	var btnFlip:FlxSprite;
	var btnBackText:FlxText;
	var btnFlipText:FlxText;

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

				var stage = new FlxSprite(0, 390);
				stage.antialiasing = ClientPrefs.data.antialiasing;
				stage.frames = Paths.getSparrowAtlas('charSelect/charSelectStage');
				stage.animation.addByPrefix('idle', "stage full instance 1", 24);
				stage.animation.play('idle');
				stage.updateHitbox();
				stage.screenCenter(X);
				stage.scrollFactor.set(0.9, 0.9);
				add(stage);

				var stageCurtain = new FlxSprite(0, 0).loadGraphic(Paths.image('charSelect/curtains'));
				stageCurtain.setGraphicSize(Std.int(stageCurtain.width * 1.05));
				stageCurtain.updateHitbox();
				stageCurtain.antialiasing = ClientPrefs.data.antialiasing;
				stageCurtain.screenCenter(XY);
				stageCurtain.scrollFactor.set(0.95, 0.1);
				add(stageCurtain);

				stageObjects = [stageBg, stage, stageCurtain];
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

		// ---- bottom bar: 3 touch buttons [BACK] [SELECT] [FLIP] ----
		final third:Float = FlxG.width / 3;
		final btnW:Int = Std.int(third - 30);
		final btnH:Int = 64;
		final btnY:Float = barDown.y + (barDown.height - btnH) / 2;

		btnBack = makeButton(third * 0 + 15, btnY, btnW, btnH);
		btnSelect = makeButton(third * 1 + 15, btnY, btnW, btnH);
		btnFlip = makeButton(third * 2 + 15, btnY, btnW, btnH);

		btnBackText = makeButtonText(btnBack, 'BACK', btnH);
		charSelect = makeButtonText(btnSelect, 'SELECT', btnH);
		btnFlipText = makeButtonText(btnFlip, 'FLIP SIDE', btnH);

		charInfo = new FlxText(0, 0, FlxG.width);
		charInfo.setFormat("VCR OSD Mono", 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		charInfo.y = barDown.y - 30;
		charInfo.scrollFactor.set(0, 0);
		charInfo.visible = false;
		add(charInfo);

		#if !mobile
		var tip1 = new FlxText(20, 0, FlxG.width, 'TAB - Flip side\nQ - Favorite\nRESET - None');
		tip1.setFormat("VCR OSD Mono", 14, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tip1.y = barDown.y - 60;
		tip1.alpha = 0.5;
		tip1.scrollFactor.set(0, 0);
		add(tip1);
		#end

		tweenColor(FlxColor.fromHSL(180, 1, 0.5));
		if (colorTweens != null)
			for (tween in colorTweens)
				tween.duration = 0;

		setCharacter(0);

		super.create();
		ready = true;
	}

	function makeButton(x:Float, y:Float, w:Int, h:Int):FlxSprite
	{
		var b = new FlxSprite(x, y);
		b.makeGraphic(w, h, FlxColor.WHITE);
		b.color = FlxColor.fromRGB(40, 40, 40);
		b.alpha = 0.85;
		b.scrollFactor.set(0, 0);
		add(b);
		return b;
	}

	function makeButtonText(b:FlxSprite, text:String, h:Int):FlxText
	{
		var t = new FlxText(b.x, 0, b.width, text);
		t.setFormat("VCR OSD Mono", 26, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		t.y = b.y + (h - t.height) / 2;
		t.scrollFactor.set(0, 0);
		add(t);
		return t;
	}

	function getEntry(i:Int):Array<String>
	{
		return (i >= 0 && i < charactersList.length) ? charactersList[i] : null;
	}

	// ------------------------------------------------------------------
	//  Character discovery
	// ------------------------------------------------------------------

	function scanCharacters()
	{
		charactersList = [];
		charactersWithWeeks = [];
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
					charactersWithWeeks.push(charactersList.length - 1);
			}
			catch (e:Dynamic) {}

			if (isEquipped(charactersList.length - 1))
				curCharacter = charactersList.length - 1;

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
	var leftHoldTime:Float = 0;
	var rightHoldTime:Float = 0;

	function pressButton(b:FlxSprite):Void
	{
		if (b == null) return;
		FlxTween.cancelTweensOf(b);
		b.color = FlxColor.fromRGB(110, 110, 110);
		FlxTween.color(b, 0.25, b.color, FlxColor.fromRGB(40, 40, 40));
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

		if (character.members[0] != null)
			character.members[0].playAnim("hey", true);

		stopUpdates = true;
		new FlxTimer().start(1, function(_) {
			leaveMenu();
		});
	}

	function goBack():Void
	{
		stopUpdates = true;
		new FlxTimer().start(0.3, function(_) {
			leaveMenu();
		});
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

		final barH:Float = 100;

		// bottom bar: BACK | SELECT | FLIP
		if (py >= FlxG.height - barH)
		{
			final third = FlxG.width / 3;
			if (px < third)
			{
				pressButton(btnBack);
				goBack();
			}
			else if (px < third * 2)
			{
				pressButton(btnSelect);
				acceptSkin();
			}
			else
			{
				pressButton(btnFlip);
				flipSkin();
			}
			return;
		}

		// middle area: left / right edges change the character
		if (py > barH)
		{
			if (px < 260)
				setCharacter(-1);
			else if (px > FlxG.width - 260)
				setCharacter(1);
		}
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

	function leaveMenu()
	{
		isExiting = true;
		camera.follow(camFollow, LOCKON, 0.01);

		FlxTween.tween(blackRectangle, {alpha: 1}, 0.5, {ease: FlxEase.quadInOut});
		blackRectangle.alpha = 0;
		add(blackRectangle);

		function finishLeave()
		{
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
		}

		if (music != null && music.playing)
			music.fadeOut(0.5, 0, t -> {
				music.stop();
				finishLeave();
			});
		else
			new FlxTimer().start(0.5, function(_) finishLeave());
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
	 * The original used a second camera with zoom 0.8 around the screen center.
	 * We emulate the same result on the default camera by scaling the sprite and
	 * moving it so its visual center lands where the zoomed camera would put it.
	 */
	function placeCharacter(char:Character):Void
	{
		var wx:Float = char.x + char.positionArray[0];
		var wy:Float = char.y + char.positionArray[1];
		var w:Float = char.width;
		var h:Float = char.height;
		var cx:Float = FlxG.width / 2;
		var cy:Float = FlxG.height / 2;

		char.scale.x *= CHAR_ZOOM;
		char.scale.y *= CHAR_ZOOM;

		char.x = cx + (wx + w / 2 - cx) * CHAR_ZOOM - w / 2;
		char.y = cy + (wy + h / 2 - cy) * CHAR_ZOOM - h / 2;
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
			charSelect.text = 'SELECT';
			charSelect.alpha = 0.9;
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
