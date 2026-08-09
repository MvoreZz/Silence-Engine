package objects;

class SustainSplash extends FlxSprite
{
	public static var startCrochet:Float;
	public static var frameRate:Int;

	public var strumNote:StrumNote;

	var timer:FlxTimer;
	var ending:Bool = false;

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

		if (strumNote != null && !ending)
		{
			setPosition(strumNote.x, strumNote.y);
			visible = strumNote.visible;
			alpha = ClientPrefs.data.holdSplashAlpha - (1 - strumNote.alpha);

			// Kill it only when in the hold animation and upon returning to strum static
			if (animation.curAnim != null
				&& animation.curAnim.name == "hold"
				&& strumNote.animation.curAnim != null
				&& strumNote.animation.curAnim.name == "static")
			{
				forceKill();
			}
		}
		else if (strumNote != null && ending)
		{
			// During the end animation just track the position; dont get killed because you're standing still
			setPosition(strumNote.x, strumNote.y);
			visible = strumNote.visible;
		}
	}

	public function setupSusSplash(strum:StrumNote, daNote:Note, ?playbackRate:Float = 1):Void
	{
		ending = false;
		animation.finishCallback = null;

		if (timer != null)
		{
			timer.cancel();
			timer = null;
		}

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

		// Opponent hit veya alpha 0 ise hic end oynatma
		if (daNote.hitByOpponent || ClientPrefs.data.holdSplashAlpha == 0)
			return;

		timer = new FlxTimer().start(timeThingy, function(_)
		{
			if (animation == null)
			{
				forceKill();
				return;
			}

			final disabled:Bool = daNote.isSustainNote
				? (daNote.parent != null && daNote.parent.noteSplashData.disabled)
				: daNote.noteSplashData.disabled;

			if (disabled)
			{
				forceKill();
				return;
			}

			ending = true;
			alpha = ClientPrefs.data.holdSplashAlpha - (1 - (strumNote != null ? strumNote.alpha : 1));
			clipRect = null;
			animation.play('end', true, false, 0);
			if (animation.curAnim != null)
			{
				animation.curAnim.looped = false;
				animation.curAnim.frameRate = 24;
			}
			animation.finishCallback = function(__)
			{
				forceKill();
			};
		});
	}

	function forceKill():Void
	{
		ending = false;
		if (timer != null)
		{
			timer.cancel();
			timer = null;
		}
		animation.finishCallback = null;
		visible = false;
		alpha = 0;
		x = -50000;
		kill();
	}
}
