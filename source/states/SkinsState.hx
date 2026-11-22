package states;

import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.group.FlxGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;
import flixel.input.keyboard.FlxKey;
import haxe.io.Path;
import backend.WeekData;
import objects.Character;
import objects.HealthIcon;

/**
 * Character skin select menu.
 * Scans assets + enabled mods for playable characters and stores choice in ClientPrefs.data.currentSkin.
 */
class SkinsState extends MusicBeatState
{
	static var BLACKLISTED_CHARACTERS = ['default'];
	public static var LEFT_SUFFIX = ['-opponent', '-left'];
	public static var RIGHT_SUFFIX = ['-player', '-playable', '-right'];
	static var SKIP_SUFFICES = ['-pixel', '-christmas', '-car', '-blazin'];

	var charactersWithWeeks:Array<Int> = [];
	// [character_name, left_suffix, right_suffix, mod_folder]
	var charactersList:Array<Array<String>> = [];
	static var curCharacter:Int = -1;

	var character:FlxTypedGroup<Character>;
	var characterCamera:FlxCamera;

	var hud:FlxCamera;
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

	var stageCrowd:Dynamic;
	var stageSpeakers:Dynamic;
	var defaultGirlfriend:Dynamic;
	var camFollow:FlxObject;

	var stageObjects:Array<FlxSprite> = [];

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

		FlxG.cameras.add(characterCamera = new FlxCamera(), false);
		FlxG.cameras.add(hud = new FlxCamera(), false);
		try { CustomFadeTransition.nextCamera = hud; } catch (e:Dynamic) {}
		characterCamera.bgColor.alpha = 0;
		hud.bgColor.alpha = 0;
		characterCamera.zoom = 0.8;

		camFollow = new FlxObject(FlxG.width / 2, FlxG.height / 2 - 200, 1, 1);
		camera.follow(camFollow, LOCKON, 0.05);
		characterCamera.follow(camFollow, LOCKON, 0.05);
		camera.snapToTarget();
		characterCamera.snapToTarget();
		camFollow.setPosition(FlxG.width / 2, FlxG.height / 2);

		blackRectangle = new FlxSprite();
		blackRectangle.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		blackRectangle.cameras = [hud];

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.color = 0xff303030;
		bg.setGraphicSize(Std.int(bg.width * 1.1));
		bg.screenCenter();
		bg.antialiasing = ClientPrefs.data.antialiasing;
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
		character.cameras = [characterCamera];
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
		barUp.cameras = [hud];
		add(barUp);

		var barDown = new FlxSprite();
		barDown.makeGraphic(FlxG.width, 100, FlxColor.BLACK);
		barDown.y = FlxG.height - barDown.height;
		barDown.cameras = [hud];
		add(barDown);

		title = new Alphabet(0, 0, "BOYFRIEND", true);
		title.cameras = [hud];
		title.y = barUp.height / 2 - title.height / 2;
		title.x = FlxG.width / 2 - title.width / 2;
		add(title);

		arrowLeft = new Alphabet(0, 0, "<", true);
		arrowLeft.cameras = [hud];
		arrowLeft.y = FlxG.height / 2 - arrowLeft.height / 2;
		arrowLeft.x = alX = 100;
		add(arrowLeft);

		arrowRight = new Alphabet(0, 0, ">", true);
		arrowRight.cameras = [hud];
		arrowRight.y = FlxG.height / 2 - arrowRight.height / 2;
		arrowRight.x = arX = FlxG.width - arrowRight.width - 100;
		add(arrowRight);

		charSelect = new FlxText(0, 0, FlxG.width);
		charSelect.text = 'Press ACCEPT to select!';
		charSelect.setFormat("VCR OSD Mono", 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		charSelect.y = barDown.y + barDown.height / 2 - charSelect.height / 2;
		charSelect.cameras = [hud];
		add(charSelect);

		charInfo = new FlxText(0, 0, FlxG.width);
		charInfo.setFormat("VCR OSD Mono", 18, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		charInfo.y = charSelect.y - 30;
		charInfo.cameras = [hud];
		add(charInfo);

		var tip1 = new FlxText(20, 0, FlxG.width, 'TAB - Flip side\nQ - Favorite\nRESET - None');
		tip1.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		tip1.y = charSelect.y - 10;
		tip1.alpha = 0.5;
		tip1.cameras = [hud];
		add(tip1);

		tweenColor(FlxColor.fromHSL(180, 1, 0.5));
		if (colorTweens != null)
			for (tween in colorTweens)
				tween.duration = 0;

		setCharacter(0);

		#if mobile
		try
		{
			addTouchPad('LEFT_RIGHT', 'A_B');
			addTouchPadCamera();
		}
		catch (e:Dynamic) {}
		#end

		super.create();
		try { CustomFadeTransition.nextCamera = hud; } catch (e:Dynamic) {}
	}

	function scanCharacters()
	{
		charactersList = [];
		charactersWithWeeks = [];

		for (origin in [null].concat(Mods.parseList().enabled))
		{
			var characters:String;
			var charactersWeeks:String;

			if (origin == null)
			{
				Mods.loadTopMod();
				characters = 'assets/characters/';
				charactersWeeks = 'assets/characters_weeks/';
			}
			else
			{
				Mods.currentModDirectory = origin;
				characters = Paths.mods(origin + '/characters/');
				charactersWeeks = Paths.mods(origin + '/characters_weeks/');
			}

			if (!FileSystem.exists(characters))
				continue;

			var charSkipSearch = [];

			function addCharacter(characterName:String, leftSuffix:String, rightSuffix:String, origin:String):Bool
			{
				if (BLACKLISTED_CHARACTERS.contains(characterName))
					return false;

				for (suffix in SKIP_SUFFICES)
					if (characterName.endsWith(suffix))
						return false;

				charactersList.push([characterName, leftSuffix, rightSuffix, origin == null ? '' : origin]);
				charSkipSearch.push(characterName + leftSuffix);
				charSkipSearch.push(characterName + rightSuffix);

				if (FileSystem.exists(Path.join([charactersWeeks, characterName + ".json"])))
					charactersWithWeeks.push(charactersList.length - 1);

				if (isEquipped(charactersList.length - 1))
					curCharacter = charactersList.length - 1;

				return true;
			}

			for (file in FileSystem.readDirectory(characters))
			{
				var filePath = Path.join([characters, file]);
				var character:String = file.substr(0, file.length - 5);

				if (charSkipSearch.contains(character) || FileSystem.isDirectory(filePath) || !file.endsWith('.json'))
					continue;

				var hasAdded = false;

				for (playableSuffix in RIGHT_SUFFIX)
				{
					if (character.endsWith(playableSuffix))
					{
						final cutCharName = character.substr(0, character.length - playableSuffix.length);
						var leftSuffix = '';
						for (opponentSuffix in LEFT_SUFFIX)
						{
							if (FileSystem.exists(Path.join([characters, '${cutCharName + opponentSuffix}.json'])))
								leftSuffix = opponentSuffix;
						}
						if (FileSystem.exists(Path.join([characters, '${cutCharName}.json'])))
						{
							hasAdded = addCharacter(cutCharName, leftSuffix, playableSuffix, origin);
							break;
						}
					}
				}
				if (hasAdded) continue;

				for (opponentSuffix in LEFT_SUFFIX)
				{
					if (character.endsWith(opponentSuffix))
					{
						final cutCharName = character.substr(0, character.length - opponentSuffix.length);
						var rightSuffix = '';
						for (playableSuffix in RIGHT_SUFFIX)
						{
							if (FileSystem.exists(Path.join([characters, '${cutCharName + playableSuffix}.json'])))
								rightSuffix = playableSuffix;
						}
						if (rightSuffix != '' && FileSystem.exists(Path.join([characters, '${cutCharName + rightSuffix}.json'])))
						{
							hasAdded = addCharacter(cutCharName, opponentSuffix, rightSuffix, origin);
							break;
						}
					}
				}
			}
		}
	}

	function getCharacterName(i:Int):String
	{
		final character = charactersList[i];
		if (character == null) return null;
		return character[0] + character[flipped ? 2 : 1];
	}

	var acceptSound:FlxSound;
	var stopUpdates:Bool = false;
	var isExiting:Bool = false;
	var leftHoldTime:Float = 0;
	var rightHoldTime:Float = 0;

	override function update(elapsed:Float)
	{
		super.update(elapsed);

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

		// Select
		if (!FlxG.keys.pressed.SHIFT && controls.ACCEPT)
		{
			if (selectTimer != null && !selectTimer.finished)
			{
				selectTimer.onComplete(selectTimer);
				selectTimer.cancel();
			}

			ClientPrefs.data.currentSkin = charactersList[curCharacter];
			ClientPrefs.saveSettings();
			updateTexts();

			if (acceptSound != null) acceptSound.stop();
			try { acceptSound = FlxG.sound.play(Paths.sound('CS_confirm'), 0.8); } catch (e:Dynamic) {}
			if (music != null) music.stop();

			if (character.members[0] != null)
				character.members[0].playAnim("hey", true);

			stopUpdates = true;
			FlxTimer.wait(1, () -> {
				leaveMenu();
			});
			return;
		}

		if (controls.BACK)
		{
			stopUpdates = true;
			FlxTimer.wait(0.3, () -> leaveMenu());
			return;
		}

		if (FlxG.keys.justPressed.TAB)
		{
			flipped = !flipped;
			prevCharacter = null;
			setCharacter(0);
		}

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

		if (favPressed && curCharacter >= 0)
		{
			final charId = charactersList[curCharacter][0] + ':' + charactersList[curCharacter][3];
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
		characterCamera.follow(camFollow, LOCKON, 0.01);

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
			finishLeave();
	}

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

		if (persistentUpdate)
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

		if (charactersList[curCharacter] != null)
		{
			selectTimer = new FlxTimer().start(0.35, function(_)
			{
				try
				{
					Mods.currentModDirectory = charactersList[curCharacter][3];
					var name = getCharacterName(curCharacter);
					var char = new Character(0, 0, name, !flipped);
					char.x += char.positionArray[0];
					char.y += char.positionArray[1];
					char.dance();
					character.add(char);

					staticMan.visible = false;
					if (staticSound != null) staticSound.stop();

					try
					{
						var hca = char.healthColorArray;
						if (hca != null && hca.length >= 3)
							tweenColor(FlxColor.fromRGB(hca[0], hca[1], hca[2]));
					}
					catch (e:Dynamic) {}
				}
				catch (exc:Dynamic)
				{
					staticMan.visible = true;
					trace('Failed to load skin: ' + exc);
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

	function updateTexts()
	{
		title.text = curCharacter == -1 ? "(NONE)" : charactersList[curCharacter][0].replace('-', ' ');
		title.x = FlxG.width / 2 - title.width / 2;

		if (isEquipped(curCharacter))
		{
			charSelect.text = 'Selected!';
			charSelect.alpha = 1;
		}
		else
		{
			charSelect.text = 'Press ACCEPT to select!';
			charSelect.alpha = 0.8;
		}

		charInfo.visible = false;
		charInfo.text = '';

		if (charactersWithWeeks.contains(curCharacter))
		{
			charInfo.text = 'This Character has custom MIXES!';
			charInfo.visible = true;
		}

		if (charactersList[curCharacter] != null)
		{
			final charId = charactersList[curCharacter][0] + ':' + charactersList[curCharacter][3];
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
		if (ClientPrefs.data.currentSkin == null)
			return charactersList[i] == null;

		if (charactersList[i] == null)
			return false;

		for (index => item in charactersList[i])
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
		super.destroy();
		if (music != null)
			music.stop();
	}
}
