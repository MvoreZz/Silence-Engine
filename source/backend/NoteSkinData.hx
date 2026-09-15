package backend;

/**
 * Compatibility stub for builds that still import NoteSkinData.
 * Real NoteSkinData is not required for mania notes on this engine.
 */
class NoteSkinData
{
	public var skin:String = '';

	public function new() {}

	public static function getCurrent(?player:Int = 0):NoteSkinData
	{
		var d = new NoteSkinData();
		try {
			d.skin = ClientPrefs.data.noteSkin;
		} catch (e:Dynamic) {
			d.skin = 'Default';
		}
		return d;
	}
}
