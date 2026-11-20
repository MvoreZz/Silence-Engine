package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import haxe.zip.Reader;
import haxe.io.BytesInput;
#end

/**
 * Auto-extracts .zip archives found in the mods folder into folders of the same name.
 * Skips zips that already have a matching extracted folder.
 */
class ModZipExtractor
{
	public static function run():Void
	{
		#if (sys && MODS_ALLOWED)
		try
		{
			var modsDir:String = null;
			try { modsDir = Mods.modsPath; } catch (e:Dynamic) {}
			if (modsDir == null || modsDir.length < 1)
			{
				try { modsDir = Paths.mods(); } catch (e:Dynamic) {}
			}
			if (modsDir == null || modsDir.length < 1)
				modsDir = 'mods/';

			if (!FileSystem.exists(modsDir) || !FileSystem.isDirectory(modsDir))
				return;

			for (file in FileSystem.readDirectory(modsDir))
			{
				if (file == null) continue;
				var lower = file.toLowerCase();
				if (!StringTools.endsWith(lower, '.zip'))
					continue;

				var zipPath = Path.join([modsDir, file]);
				var baseName = file.substr(0, file.length - 4);
				var outDir = Path.join([modsDir, baseName]);

				// Already extracted
				if (FileSystem.exists(outDir) && FileSystem.isDirectory(outDir))
					continue;

				try
				{
					extractZip(zipPath, outDir);
					trace('[ModZipExtractor] Extracted: ' + file + ' -> ' + baseName);
				}
				catch (e:Dynamic)
				{
					trace('[ModZipExtractor] Failed ' + file + ': ' + e);
				}
			}
		}
		catch (e:Dynamic)
		{
			trace('[ModZipExtractor] ' + e);
		}
		#end
	}

	#if sys
	static function extractZip(zipPath:String, outDir:String):Void
	{
		var bytes = File.getBytes(zipPath);
		var reader = Reader.readZip(new BytesInput(bytes));
		if (!FileSystem.exists(outDir))
			FileSystem.createDirectory(outDir);

		for (entry in reader)
		{
			if (entry == null || entry.fileName == null) continue;
			var name:String = entry.fileName;
			// skip absolute / parent paths
			if (name.indexOf('..') >= 0) continue;
			if (StringTools.startsWith(name, '/') || StringTools.startsWith(name, '\\'))
				name = name.substr(1);

			var dest = Path.join([outDir, name]);
			if (StringTools.endsWith(name, '/') || StringTools.endsWith(name, '\\'))
			{
				if (!FileSystem.exists(dest))
					FileSystem.createDirectory(dest);
				continue;
			}

			var parent = Path.directory(dest);
			if (parent != null && parent.length > 0 && !FileSystem.exists(parent))
				FileSystem.createDirectory(parent);

			var data = Reader.unzip(entry);
			if (data != null)
				File.saveBytes(dest, data);
		}
	}
	#end
}
