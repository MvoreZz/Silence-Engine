package substates;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.tweens.FlxEase;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import states.PlayState;

/**
 * "Continue where you left off?" prompt shown when a mid-song save exists.
 * YES = win icon path, NO = lose icon path (visual only).
 */
class ResumePromptSubState extends FlxSubState
{
	var onYes:Void->Void;
	var onNo:Void->Void;
	var selected:Int = 0; // 0 = YES, 1 = NO
	var yesTxt:FlxText;
	var noTxt:FlxText;
	var songLabel:String;

	public function new(songName:String, yesCb:Void->Void, noCb:Void->Void)
	{
		super();
		this.songLabel = songName;
		this.onYes = yesCb;
		this.onNo = noCb;
	}

	override public function create()
	{
		super.create();

		var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0.7;
		bg.scrollFactor.set();
		add(bg);

		var title = new FlxText(0, FlxG.height * 0.28, FlxG.width,
			'CONTINUE "' + songLabel.toUpperCase() + '"\nFROM WHERE YOU LEFT OFF?',
			32);
		title.setFormat(Paths.font('vcr.ttf'), 32, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		title.borderSize = 2;
		title.scrollFactor.set();
		add(title);

		yesTxt = new FlxText(0, FlxG.height * 0.55, FlxG.width * 0.5, 'YES', 48);
		yesTxt.setFormat(Paths.font('vcr.ttf'), 48, 0xFF66FF66, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		yesTxt.borderSize = 3;
		yesTxt.scrollFactor.set();
		add(yesTxt);

		noTxt = new FlxText(FlxG.width * 0.5, FlxG.height * 0.55, FlxG.width * 0.5, 'NO', 48);
		noTxt.setFormat(Paths.font('vcr.ttf'), 48, 0xFFFF6666, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		noTxt.borderSize = 3;
		noTxt.scrollFactor.set();
		add(noTxt);

		var hint = new FlxText(0, FlxG.height * 0.75, FlxG.width, 'Score, accuracy and progress will be restored if you continue.', 16);
		hint.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		hint.scrollFactor.set();
		add(hint);

		updateSel();
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	function updateSel()
	{
		yesTxt.alpha = selected == 0 ? 1 : 0.45;
		noTxt.alpha = selected == 1 ? 1 : 0.45;
		yesTxt.scale.set(selected == 0 ? 1.15 : 1, selected == 0 ? 1.15 : 1);
		noTxt.scale.set(selected == 1 ? 1.15 : 1, selected == 1 ? 1.15 : 1);
	}

	override public function update(elapsed:Float)
	{
		super.update(elapsed);

		if (FlxG.keys.justPressed.LEFT || FlxG.keys.justPressed.A)
		{
			selected = 0;
			updateSel();
		}
		if (FlxG.keys.justPressed.RIGHT || FlxG.keys.justPressed.D)
		{
			selected = 1;
			updateSel();
		}
		if (FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE)
			confirm();
		if (FlxG.keys.justPressed.ESCAPE)
		{
			selected = 1;
			confirm();
		}

		#if mobile
		for (touch in FlxG.touches.list)
		{
			if (!touch.justPressed) continue;
			if (touch.x < FlxG.width * 0.5)
			{
				selected = 0;
				confirm();
			}
			else
			{
				selected = 1;
				confirm();
			}
		}
		#end
	}

	function confirm()
	{
		close();
		if (selected == 0 && onYes != null)
			onYes();
		else if (onNo != null)
			onNo();
	}
}
