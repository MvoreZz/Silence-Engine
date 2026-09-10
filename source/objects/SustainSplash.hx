package objects;

class SustainSplash extends FlxSprite
{
	public static var startCrochet:Float;
	public static var frameRate:Int;

	public var strumNote:StrumNote;

	var timer:FlxTimer;

	public function new():Void
	{
		super();

		x = -50000;

		frames = Paths.getSparrowAtlas('holdCovers/holdCover-' + ClientPrefs.data.holdSkin);

		animation.addByPrefix('hold', 'holdCover0', 24, true);
		animation.addByPrefix('end', 'holdCoverEnd0', 24, false);
		if (!animation.getNameList().contains("hold"))
			trace("Hold splash is missing 'hold' anim!");
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (strumNote != null)
		{
			setPosition(strumNote.x, strumNote.y);
			visible = strumNote.visible;
			alpha = ClientPrefs.data.holdSplashAlpha - (1 - strumNote.alpha);

			if (animation.curAnim != null
				&& animation.curAnim.name == "hold"
				&& strumNote.animation.curAnim != null
				&& strumNote.animation.curAnim.name == "static")
			{
				x = -50000;
				kill();
			}
		}
	}

	public function setupSusSplash(strum:StrumNote, daNote:Note, ?playbackRate:Float = 1):Void
	{
		final lengthToGet:Int = !daNote.isSustainNote ? daNote.tail.length : daNote.parent.tail.length;
		final timeToGet:Float = !daNote.isSustainNote ? daNote.strumTime : daNote.parent.strumTime;
		final timeThingy:Float = (startCrochet * lengthToGet + (timeToGet - Conductor.songPosition + ClientPrefs.data.ratingOffset)) / playbackRate * 0.001;

		animation.play('hold', true, false, 0);
		if (animation.curAnim != null)
		{
			animation.curAnim.frameRate = frameRate;
			animation.curAnim.looped = true;
		}
		clipRect = new flixel.math.FlxRect(0, !PlayState.isPixelStage ? 0 : -210, frameWidth, frameHeight);

		if (daNote.shader != null)
		{
			try
			{
				shader = new objects.NoteSplash.PixelSplashShaderRef().shader;
				shader.data.r.value = daNote.shader.data.r.value;
				shader.data.g.value = daNote.shader.data.g.value;
				shader.data.b.value = daNote.shader.data.b.value;
				shader.data.mult.value = daNote.shader.data.mult.value;
			}
			catch (e:Dynamic) {}
		}

		strumNote = strum;
		alpha = ClientPrefs.data.holdSplashAlpha - (1 - strumNote.alpha);
		offset.set(PlayState.isPixelStage ? 112.5 : 106.25, 100);
		visible = true;

		if (timer != null)
			timer.cancel();

		if (!daNote.hitByOpponent && ClientPrefs.data.holdSplashAlpha != 0)
		{
			timer = new FlxTimer().start(timeThingy, function(_)
			{
				final disabled:Bool = daNote.isSustainNote
					? (daNote.parent != null && daNote.parent.noteSplashData.disabled)
					: daNote.noteSplashData.disabled;

				if (!disabled && animation != null)
				{
					alpha = ClientPrefs.data.holdSplashAlpha - (1 - (strumNote != null ? strumNote.alpha : 1));
					animation.play('end', true, false, 0);
					if (animation.curAnim != null)
					{
						animation.curAnim.looped = false;
						animation.curAnim.frameRate = 24;
					}
					clipRect = null;
					animation.finishCallback = function(__)
					{
						kill();
					};
					return;
				}
				kill();
			});
		}
	}
}
