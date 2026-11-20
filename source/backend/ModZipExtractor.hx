package backend;

#if sys
import sys.FileSystem;
import sys.io.File;
import haxe.io.Path;
import haxe.zip.Reader;
import haxe.io.BytesInput;
#end

/**
 * Auto-extracts .zip archives in the mods folder.
 * If the zip has a single root folder, its contents go directly into mods/ZipName/
 * (no mods/ZipName/ZipName/ nesting).
 */
class ModZipExtractor
{
	public static function run():Void
	{
		#if (sys && MODS_ALLOWED)
		try
		{
			var modsDir:String = null;
			try { modsDir = Paths.mods(); } catch (e:Dynamic) {}
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

				if (FileSystem.exists(outDir) && FileSystem.isDirectory(outDir))
				{
					// already extracted (has any content)
					try
					{
						if (FileSystem.readDirectory(outDir).length > 0)
							continue;
					}
					catch (e:Dynamic) {}
				}

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
		var entries = Reader.readZip(new BytesInput(bytes));

		// Detect single root folder: all paths start with "RootName/"
		var rootPrefix:String = null;
		var rootName:String = null;
		for (entry in entries)
		{
			if (entry == null || entry.fileName == null) continue;
			var name:String = entry.fileName.split('\\').join('/');
			if (name.length < 1 || name == './') continue;
			if (StringTools.startsWith(name, '/') ) name = name.substr(1);
			if (name.indexOf('..') >= 0) continue;

			var slash = name.indexOf('/');
			var top:String = (slash >= 0) ? name.substr(0, slash) : name;
			if (top.length < 1) continue;

			// skip macOS junk
			if (top == '__MACOSX') continue;

			if (rootName == null)
				rootName = top;
			else if (rootName != top)
			{
				rootName = null; // multiple roots
				break;
			}
		}

		if (rootName != null)
			rootPrefix = rootName + '/';

		if (!FileSystem.exists(outDir))
			FileSystem.createDirectory(outDir);

		for (entry in entries)
		{
			if (entry == null || entry.fileName == null) continue;
			var name:String = entry.fileName.split('\\').join('/');
			if (name.length < 1) continue;
			if (StringTools.startsWith(name, '/')) name = name.substr(1);
			if (name.indexOf('..') >= 0) continue;
			if (StringTools.startsWith(name, '__MACOSX')) continue;

			// Strip single root folder so we don't get outDir/Root/files
			if (rootPrefix != null)
			{
				if (name == rootName || name == rootPrefix)
					continue; // skip the root dir entry itself
				if (StringTools.startsWith(name, rootPrefix))
					name = name.substr(rootPrefix.length);
				else
					continue;
			}
			if (name.length < 1) continue;

			var dest = Path.join([outDir, name]);
			var isDir = StringTools.endsWith(entry.fileName, '/') || StringTools.endsWith(entry.fileName, '\\');
			if (isDir)
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
