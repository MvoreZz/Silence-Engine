package substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import objects.HealthIcon;

/**
 * Continue-from-checkpoint prompt. UI mirrors ResetScoreSubState (YES/NO + icon).
 * Yes = win icon frame, No = lose icon frame. Icon = opponent / song character.
 */
class ResumePromptSubState extends MusicBeatSubstate
{
	var bg:FlxSprite;
	var alphabetArray:Array<Alphabet> = [];
	var icon:HealthIcon;
	var onYes:Bool = false;
	var yesText:Alphabet;
	var noText:Alphabet;
	var yesCb:Void->Void;
	var noCb:Void->Void;

	public function new(songName:String, yesCallback:Void->Void, noCallback:Void->Void, ?character:String = 'bf')
	{
		super();
		yesCb = yesCallback;
		noCb = noCallback;

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		bg.scrollFactor.set();
		add(bg);

		var tooLong:Float = (songName.length > 18) ? 0.8 : 1;
		var text:Alphabet = new Alphabet(0, 180, "Continue from", true);
		text.screenCenter(X);
		alphabetArray.push(text);
		text.alpha = 0;
		add(text);

		var text2:Alphabet = new Alphabet(0, text.y + 90, songName, true);
		text2.scaleX = tooLong;
		text2.screenCenter(X);
		alphabetArray.push(text2);
		text2.alpha = 0;
		add(text2);

		var text3:Alphabet = new Alphabet(0, text2.y + 90, "where you left off?", true);
		text3.screenCenter(X);
		alphabetArray.push(text3);
		text3.alpha = 0;
		add(text3);

		var charName:String = (character != null && character.length > 0) ? character : 'bf';
		icon = new HealthIcon(charName);
		icon.setGraphicSize(Std.int(icon.width * 0.8));
		icon.updateHitbox();
		icon.setPosition(text2.x + text2.width + 20, text2.y - 30);
		icon.alpha = 0;
		add(icon);

		yesText = new Alphabet(0, text3.y + 150, 'Yes', true);
		yesText.screenCenter(X);
		yesText.x -= 200;
		add(yesText);

		noText = new Alphabet(0, text3.y + 150, 'No', true);
		noText.screenCenter(X);
		noText.x += 200;
		add(noText);

		updateOptions();

		try {
			addTouchPad('LEFT_RIGHT', 'A_B');
			addTouchPadCamera();
		} catch (e:Dynamic) {}
	}

	override function update(elapsed:Float)
	{
		bg.alpha += elapsed * 1.5;
		if (bg.alpha > 0.6) bg.alpha = 0.6;

		for (spr in alphabetArray)
			spr.alpha += elapsed * 2.5;
		icon.alpha += elapsed * 2.5;

		if (controls.UI_LEFT_P || controls.UI_RIGHT_P)
		{
			FlxG.sound.play(Paths.sound('scrollMenu'), 1);
			onYes = !onYes;
			updateOptions();
		}
		if (controls.BACK)
		{
			FlxG.sound.play(Paths.sound('cancelMenu'), 1);
			closeWith(false);
			return;
		}
		else if (controls.ACCEPT)
		{
			FlxG.sound.play(Paths.sound(onYes ? 'confirmMenu' : 'cancelMenu'), 1);
			closeWith(onYes);
			return;
		}

		#if mobile
		if (touchPad == null)
		{
			try {
				addTouchPad('LEFT_RIGHT', 'A_B');
				addTouchPadCamera();
			} catch (e:Dynamic) {}
		}
		#end

		super.update(elapsed);
	}

	function updateOptions()
	{
		var scales:Array<Float> = [0.75, 1];
		var alphas:Array<Float> = [0.6, 1.25];
		var confirmInt:Int = onYes ? 1 : 0;

		yesText.alpha = alphas[confirmInt];
		yesText.scale.set(scales[confirmInt], scales[confirmInt]);
		noText.alpha = alphas[1 - confirmInt];
		noText.scale.set(scales[1 - confirmInt], scales[1 - confirmInt]);
		// HealthIcon: frame 0 = win/healthy, frame 1 = lose — Yes should show win
		if (icon != null && icon.animation != null && icon.animation.curAnim != null)
			icon.animation.curAnim.curFrame = onYes ? 0 : 1;
	}

	function closeWith(accepted:Bool)
	{
		try { controls.isInSubstate = false; } catch (e:Dynamic) {}
		close();
		if (accepted)
		{
			if (yesCb != null) yesCb();
		}
		else
		{
			if (noCb != null) noCb();
		}
	}

	override function destroy()
	{
		bg = FlxDestroyUtil.destroy(bg);
		alphabetArray = FlxDestroyUtil.destroyArray(alphabetArray);
		icon = FlxDestroyUtil.destroy(icon);
		yesText = FlxDestroyUtil.destroy(yesText);
		noText = FlxDestroyUtil.destroy(noText);
		super.destroy();
	}
}
