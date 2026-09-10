package objects;

class SustainSplash extends FlxSprite
{
	public static var startCrochet:Float;
	public static var frameRate:Int;

	public var strumNote:StrumNote;

	var timer:FlxTimer;
	var ending:Bool = false;
	var activeSplash:Bool = false;

	public function new():Void
	{
		super();
		resetVisuals();
		frames = Paths.getSparrowAtlas('holdCovers/holdCover-' + ClientPrefs.data.holdSkin);
		animation.addByPrefix('hold', 'holdCover0', 24, true);
		animation.addByPrefix('end', 'holdCoverEnd0', 24, false);
		if (!animation.getNameList().contains("hold"))
			trace("Hold splash is missing 'hold' anim!");
	}

	function clearState():Void
	{
		activeSplash = false;
		ending = false;
		if (timer != null)
		{
			timer.cancel();
			timer = null;
		}
		if (animation != null)
			animation.finishCallback = null;
		strumNote = null;
	}

	function resetVisuals():Void
	{
		visible = false;
		alpha = 0;
		x = -50000;
		y = -50000;
	}

	override function kill():Void
	{
		clearState();
		resetVisuals();
		super.kill();
	}

	override function revive():Void
	{
		super.revive();
		clearState();
		resetVisuals();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (!activeSplash || strumNote == null)
			return;

		setPosition(strumNote.x, strumNote.y);
		visible = strumNote.visible && activeSplash;
		alpha = ClientPrefs.data.holdSplashAlpha - (1 - strumNote.alpha);

		if (!ending
			&& animation.curAnim != null
			&& animation.curAnim.name == "hold"
			&& strumNote.animation.curAnim != null
			&& strumNote.animation.curAnim.name == "static")
		{
			kill();
		}
	}

	public function setupSusSplash(strum:StrumNote, daNote:Note, ?playbackRate:Float = 1):Void
	{
		clearState();

		if (daNote == null || strum == null)
			return;

		final parentNote:Note = !daNote.isSustainNote ? daNote : daNote.parent;
		if (parentNote == null)
			return;

		final lengthToGet:Int = parentNote.tail.length;
		if (lengthToGet <= 1)
			return;

		final timeToGet:Float = parentNote.strumTime;
		final timeThingy:Float = (startCrochet * lengthToGet + (timeToGet - Conductor.songPosition + ClientPrefs.data.ratingOffset)) / playbackRate * 0.001;
		if (timeThingy <= 0)
			return;

		strumNote = strum;
		ending = false;
		activeSplash = true;

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

		setPosition(strum.x, strum.y);
		offset.set(PlayState.isPixelStage ? 112.5 : 106.25, 100);
		alpha = ClientPrefs.data.holdSplashAlpha - (1 - strum.alpha);
		visible = true;

		if (daNote.hitByOpponent || ClientPrefs.data.holdSplashAlpha == 0)
			return;

		final noteRef:Note = daNote;
		timer = new FlxTimer().start(timeThingy, function(_)
		{
			if (!activeSplash || animation == null)
			{
				kill();
				return;
			}

			final disabled:Bool = noteRef.isSustainNote
				? (noteRef.parent != null && noteRef.parent.noteSplashData.disabled)
				: noteRef.noteSplashData.disabled;

			if (disabled)
			{
				kill();
				return;
			}

			ending = true;
			clipRect = null;
			animation.play('end', true, false, 0);
			if (animation.curAnim != null)
			{
				animation.curAnim.looped = false;
				animation.curAnim.frameRate = 24;
			}
			animation.finishCallback = function(__)
			{
				kill();
			};
		});
	}
}
