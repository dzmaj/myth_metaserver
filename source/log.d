module log;

import std.stdio;
import std.file;
import std.datetime;
import std.string;

import vibe.data.json;

// Very simple file logging - can expand when needed

// TODO: Fix for multiple threads/shared
private	static File s_log;
private	static File s_chat_log;
private static File s_error_log;
private static File s_debug_log;

public static this()
{
	s_log = stdout;
}

@safe public void initialize_logging(string file_name)
{
	s_log = File(file_name, "a");
	s_chat_log = File("chat_" ~ file_name, "a");
	s_error_log = File("error_" ~ file_name, "a");
	s_debug_log = File("debug_" ~ file_name, "a");
}

@safe private string get_time_string()
{
	auto dt = Clock.currTime();
	return format("%04d-%02d-%02d %02d:%02d:%02d",
				  dt.year, dt.month, dt.day, dt.hour, dt.minute, dt.second);
}

@trusted nothrow public void log_message(A...)(in char[] format, A args)
{
    try {
        s_log.writefln("%s: " ~ format, get_time_string(), args);
	    s_log.flush();
    } catch(Exception e) {
        log_error_message("Error logging message: %s", e.msg);
    }
	
}

//log a message to a separate file
@trusted nothrow public void log_chat_message(A...)(in char[] format, A args)
{
    try {
        s_chat_log.writefln("%s: " ~ format, get_time_string(), args);
	    s_chat_log.flush();
    } catch(Exception e) {
        log_error_message("Error logging chat message: %s", e.msg);
    }
	
}

@trusted nothrow public void log_error_message(A...)(in char[] format, A args)
{
    try {
        s_error_log.writefln("%s: " ~ format, get_time_string(), args);
	    s_error_log.flush();
    } catch(Exception e) {
        
    }
	
}

@trusted nothrow public void log_debug_message(A...)(in char[] format, A args)
{
    try {
        s_debug_log.writefln("%s: " ~ format, get_time_string(), args);
	    s_debug_log.flush();
    } catch(Exception e) {
        log_error_message("Error logging debug message: %s", e.msg);
    }
}


// Read JSON config files into structures
// Doesn't necessarily fit in "log" module, but it's close enough
@safe public T read_config(T)(string config_file)
{
	T config = T.init;
	try
	{
		string contents = readText(config_file);
		log_message("Loading config from from '%s'...", config_file);
		deserializeJson(config, parseJson(contents));
	}
	catch (FileException e) {}
	catch (Exception e) { log_message("Parse error: %s", e.msg); }

	log_message("Done loading config.");
	return config;
}
