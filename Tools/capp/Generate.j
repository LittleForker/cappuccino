
@import "Configuration.j"

var OS = require("OS"),
    SYSTEM = require("system"),
    FILE = require("file"),
    OBJJ = require("objective-j");


function gen(/*va_args*/)
{
    var index = 0,
        count = arguments.length,

        shouldSymbolicallyLink = false,
        justFrameworks = false,
        noConfig = false,
        force = false,
        
        template = "Application",
        destination = "";

    for (; index < count; ++index)
    {
        var argument = arguments[index];

        switch (argument)
        {

            case "-l":              shouldSymbolicallyLink = true;
                                    break;

            case "-t":
            case "--template":      template = arguments[++index];
                                    break;
                                
            case "-f":
            case "--frameworks":    justFrameworks = true;
                                    break;

            case "--noconfig":      noConfig = true;
                                    break;

            case "--force":         force = true;
                                    break;

            default:                destination = argument;
        }
    }

    if (destination.length === 0)
        destination = justFrameworks ? "." : "Untitled";

    var sourceTemplate = null;

    if (FILE.isAbsolute(template))
        sourceTemplate = FILE.join(template);
    else
        sourceTemplate = FILE.join(SYSTEM.env["SELF_HOME"], "lib", "capp", "Resources", "Templates", template);

    var configFile = FILE.join(sourceTemplate, "template.config"),
        config = {};

    if (FILE.isFile(configFile))
        config = JSON.parse(FILE.read(configFile, { charset:"UTF-8" }));

    var destinationProject = destination,
        configuration = noConfig ? [Configuration defaultConfiguration] : [Configuration userConfiguration];

    if (justFrameworks)
        createFrameworksInFile(destinationProject, shouldSymbolicallyLink, force);

    else if (!FILE.exists(destinationProject))
    {
        // FIXME???
        OS.system("cp -vR " + sourceTemplate + " " + destinationProject);

        var files = FILE.glob(FILE.join(destinationProject, "**", "*")),
            index = 0,
            count = files.length,
            name = FILE.basename(destinationProject),
            orgIdentifier = [configuration valueForKey:@"organization.identifier"] || "";

        [configuration setTemporaryValue:name forKey:@"project.name"];
        [configuration setTemporaryValue:orgIdentifier + '.' +  toIdentifier(name) forKey:@"project.identifier"];
        [configuration setTemporaryValue:toIdentifier(name) forKey:@"project.nameasidentifier"];

        for (; index < count; ++index)
        {
            var path = files[index];

            if (FILE.isDirectory(path))
                continue;

            // Don't do this for images.
            if ([".png", ".jpg", ".jpeg", ".gif", ".tif", ".tiff"].indexOf(FILE.extension(path)) !== -1)
                continue;

            var contents = FILE.read(path, { charset : "UTF-8" }),
                key = nil,
                keyEnumerator = [configuration keyEnumerator];

            while (key = [keyEnumerator nextObject])
                contents = contents.replace(new RegExp("__" + RegExp.escape(key) + "__", 'g'), [configuration valueForKey:key]);

            FILE.write(path, contents, { charset: "UTF-8"});
        }

        var frameworkDestination = destinationProject;

        if (config.FrameworksPath)
            frameworkDestination = FILE.join(frameworkDestination, config.FrameworksPath);

        createFrameworksInFile(frameworkDestination, shouldSymbolicallyLink);
    }
    else
        print("Directory already exists");
}

function createFrameworksInFile(/*String*/ aFile, /*Boolean*/ symlink, /*Boolean*/ force)
{
    var destination = FILE.path(aFile);
    
    if (!destination.isDirectory())
        throw new Error("Can't create Frameworks. Directory does not exist: " + destination);
    
    if (symlink && !(SYSTEM.env["CAPP_BUILD"] || SYSTEM.env["STEAM_BUILD"]))
        throw "CAPP_BUILD or STEAM_BUILD must be defined";

    var installedFrameworks = FILE.path(FILE.join(OBJJ.OBJJ_HOME, "lib", "Frameworks")),
        builtFrameworks = FILE.path(SYSTEM.env["CAPP_BUILD"] || SYSTEM.env["STEAM_BUILD"]);
    
    var sourceFrameworks = symlink ? builtFrameworks.join("Release") : installedFrameworks,
        sourceDebugFrameworks = symlink ? builtFrameworks.join("Debug") : installedFrameworks.join("Debug");
        
    var destinationFrameworks = destination.join("Frameworks"),
        destinationDebugFrameworks = destination.join("Frameworks", "Debug");
    
    print("Creating Frameworks directory in " + destinationFrameworks + ".");
    
    //destinationFrameworks.mkdirs(); // redundant
    destinationDebugFrameworks.mkdirs();
    
    ["Objective-J", "Foundation", "AppKit"].forEach(function(framework) {
        installFramework(
            sourceFrameworks.join(framework),
            destinationFrameworks.join(framework),
            force, symlink);
        installFramework(
            sourceDebugFrameworks.join(framework),
            destinationDebugFrameworks.join(framework),
            force, symlink);
    });
}

function installFramework(source, dest, force, symlink) {
    if (dest.exists()) {
        if (force) {
            dest.rmtree();
        } else {
            print("Warning: " + dest + " already exists. Use --force to overwrite.");
            return;
        }
    }
    if (source.exists()) {
        print((symlink ? "Symlinking " : "Copying ") + source + " to " + dest);
        if (symlink)
            FILE.symlink(source, dest);
        else
            FILE.copyTree(source, dest);
    }
    else
        print("Warning: "+source+" doesn't exist.");
}

function toIdentifier(/*String*/ aString)
{
    var identifier = "",
        index = 0,
        count = aString.length,
        capitalize = NO,
        firstRegex = new RegExp("^[a-zA-Z_$]"),
        regex = new RegExp("^[a-zA-Z_$0-9]");

    for (; index < count; ++index)
    {
        var character = aString.charAt(index);

        if ((index === 0) && firstRegex.test(character) || regex.test(character))
        {
            if (capitalize)
                identifier += character.toUpperCase();
            else
                identifier += character;

            capitalize = NO;
        }
        else
            capitalize = YES;
    }

    return identifier;
}
