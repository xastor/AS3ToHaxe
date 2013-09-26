/*
 * Copyright (c) 2011, TouchMyPixel & contributors
 * Original author : Tarwin Stroh-Spijer <tarwin@touchmypixel.com>
 * Contributers: Tony Polinelli <tonyp@touchmypixel.com>
 * All rights reserved.
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 *   - Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer.
 *   - Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE TOUCH MY PIXEL & CONTRIBUTERS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE TOUCH MY PIXEL & CONTRIBUTORS
 * BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

package;

import neko.Lib;
import sys.FileSystem;
import Sys;

using StringTools;
using AS3ToHaxe;

/**
 * Simple Program which iterates -from folder, finds .mtt templates and compiles them to the -to folder
 */
class AS3ToHaxe
{
	public static var keys = ["-from", "-to", "-remove"];
	
	var to:String;
	var from:String;
	var remove:String;
	var sysargs:Array<String>;
	
	var items:Array<String>;
	
	public static var basePackage:String = "away3d";
	
	private var nameSpaces:Map<String, ClassDefs>;
	private var maxLoop:Int;
	
	static function main() 
	{
		new AS3ToHaxe();
	}
	
	public function new()
	{
		maxLoop = 1000;
		
		if (parseArgs())
		{
		
			// make sure that the to directory exists
			if (!FileSystem.exists(to)) FileSystem.createDirectory(to);
			
			// delete old files
			if (remove == "true")
				removeDirectory(to);
			
			items = [];
			// fill items
			recurse(from);

			// to remember namespaces
			nameSpaces = new Map<String, ClassDefs>();
			
			for (item in items)
			{
				// make sure we only work wtih AS fiels
				var ext = getExt(item);
				switch(ext)
				{
					case "as": 
						convert(item);
				}
			}
			
			// build namespace files
			buildNameSpaces();
		}
	}
	
	private function convert(file:String):Void
	{		
		var fromFile = file;
		var toFile = to + "/" + file.substr(from.length + 1, file.lastIndexOf(".") - (from.length)) + "hx";
		
		var rF = "";
		var rC = "";
		
		var b = 0;
		
		// create the folder if it doesn''t exist
		var dir = toFile.substr(0, toFile.lastIndexOf("/"));
		createFolder(dir);
		
		var s = sys.io.File.getContent(fromFile);
		
		// spacse to tabs
		s = regReplace(s, "    ", "\t");
		// undent
		s = regReplace(s, "^\t", "");
		
		// some quick setup, finding what we''ve got
		var className = regMatch(s, "public class([ ]*)([A-Z][a-zA-Z0-9_]*)", 2)[1];
		var hasVectors = (regMatch(s, "Vector([ ]*)\\.([ ]*)<([ ]*)([^>]*)([ ]*)>").length != 0);

		// package
		s = regReplace(s, "package ([a-zA-Z\\.0-9-_]*)([ \n\r]*){", "package $1;\n", "gs");
		// remove last 
		s = regReplace(s, "\\}([\n\r\t ]*)\\}([\n\r\t ]*)$", "}", "gs");

		// extra indentation
		s = regReplace(s, "\n\t", "\n");
		
		// class
		s = regReplace(s, "public class", "class");

		// constructor
		s = regReplace(s, "function " + className, "function new");
		
		// Casts
		s = regReplace(s, "([^a-zA-Z0-9_.]+)Number\\(([^\\)]+)\\)", "$1Std.parseFloat($2)");
		s = regReplace(s, "([^a-zA-Z0-9_.]+)int\\((\\-?[0-9]*\\.[0-9]*+)\\)", "$1Std.int($2)");
		s = regReplace(s, "([^a-zA-Z0-9_.]+)int\\(([^\\)]+)\\)", "$1Std.parseInt($2)");
		s = regReplace(s, "([^a-zA-Z0-9_.]+)String\\(([^\\)]+)\\)", "$1Std.string($2)");
		s = regReplace(s, "([^a-zA-Z0-9_.]+)([A-Z][a-zA-Z0-9_]*)\\(([^\\)]+)\\)", "$1cast($3, $2)");
		s = regReplace(s, "([^a-zA-Z0-9_.]+)([a-zA-Z_][a-zA-Z0-9_]*) +as +([A-Z][a-zA-Z0-9_]*)", "$1cast($2, $3)");
		s = regReplace(s, "([^a-zA-Z0-9_.]+)([a-zA-Z_][a-zA-Z0-9_]*)([ ]+)is([ ]+)([a-zA-Z_][a-zA-Z0-9_]*)", "$1Std.is($2,$5)");
		
		// simple typing
		s = regReplace(s, ":([ ]*)void", ":$1Void");
		s = regReplace(s, ":([ ]*)Boolean", ":$1Bool");
		s = regReplace(s, ":([ ]*)int", ":$1Int");
		s = regReplace(s, ":([ ]*)uint", ":$1UInt");
		s = regReplace(s, ":([ ]*)Number", ":$1Float");
		s = regReplace(s, ":([ ]*)\\*", ":$1Dynamic");
		
		s = regReplace(s, "<Number>", "<Float>");
		s = regReplace(s, "<int>", "<Int>");
		s = regReplace(s, "<uint>", "<UInt>");
		s = regReplace(s, "<Boolean>", "<Bool>");
		
		// vector
		// definition
		s = regReplace(s, "Vector([ ]*)\\.([ ]*)<([ ]*)([^>]*)([ ]*)>", "Vector<$3$4$5>");
		// new (including removing stupid spaces)
		s = regReplace(s, "new Vector([ ]*)([ ]*)<([ ]*)([^>]*)([ ]*)>([ ]*)\\(([ ]*)\\)([ ]*)", "new Vector()");
		// and import if we have to
		if (hasVectors) {
			s = regReplace(s, "class([ ]*)(" + className + ")", "import flash.Vector;\n\nclass$1$2");
		}
		
		// array
		s = regReplace(s, " Array([ ]*);", " Array<Dynamic>;");
		
		// remap protected -> private & internal -> private
		s = regReplace(s, "protected var", "private var");
		s = regReplace(s, "internal var", "private var");
		s = regReplace(s, "protected function", "private function");
		s = regReplace(s, "internal function", "private function");

		/* -----------------------------------------------------------*/
		// namespaces
		// find which namespaces are used in this class
		var r = new EReg("([^#])use([ ]+)namespace([ ]+)([a-zA-Z-]+)([ ]*);", "g");
		b = 0;
		while (true) {
			b++; if (b > maxLoop) { logLoopError("namespaces find", file); break; }
			if (r.match(s)) {
				nameSpaces.set(Std.string(r.matched(4)), new ClassDefs());
				s = r.replace(s, "//" + r.matched(0).replace("use", "#use") + "\nusing " + basePackage + ".namespace." + Std.string(r.matched(4)).fUpper() +  ";");
			}else {
				break;
			}
		}
		
		// collect all namespace definitions
		// replace them with private
		for (k in nameSpaces.keys()) {
			var n = nameSpaces.get(k);
			b = 0;
			while (true) {
				b++; if (b > maxLoop) { logLoopError("namespaces collect/replace var", file); break; }
				// vars
				var r = new EReg(n.name + "([ ]+)var([ ]+)", "g");
				s = r.replace(s, "private$1var$2");
				if (!r.match(s)) break;
			}
			b = 0;
			while (true) {
				b++; if (b > maxLoop) { logLoopError("namespaces collect/replace func", file); break; }
				// funcs
				var matched:Bool = false;
				var r = new EReg(n.name + "([ ]+)function([ ]+)", "g");
				if (r.match(s)) matched = true;
				s = r.replace(s, "private$1function$2");
				r = new EReg(n.name + "([ ]+)function([ ]+)get([ ]+)", "g");
				if (r.match(s)) matched = true;
				s = r.replace(s, "private$1function$2get$3");
				r = new EReg(n.name + "([ ]+)function([ ]+)set([ ]+)", "g");
				if (r.match(s)) matched = true;
				s = r.replace(s, "private$1function$2$3set");
				if (!matched) break;
			}
		}
		
		/* -----------------------------------------------------------*/
		// change const to inline statics
		s = regReplace(s, "([\n\t ]+)(public|private)([ ]*)const([ ]+)([a-zA-Z0-9_]+)([ ]*):", "$1$2$3static inline var$4$5$6:");
		s = regReplace(s, "([\n\t ]+)(public|private)([ ]*)(static)*([ ]+)const([ ]+)([a-zA-Z0-9_]+)([ ]*):", "$1$2$3$4$5inline var$6$7$8:");
		
		/* -----------------------------------------------------------*/
		// move variables being set from var def to top of constructor
		// do NOT do this for const
		// if they're static, leave them there
		// TODO!
		
		/* -----------------------------------------------------------*/
		// Error > flash.Error
		// if " Error (" then add "import flash.Error" to head
		var r = new EReg("([ ]+)new([ ]+)Error([ ]*)\\(", "");
		if (r.match(s))
			s = regReplace(s, "class([ ]*)(" + className + ")", "import flash.Error;\n\nclass$1$2");
		
		/* -----------------------------------------------------------*/

		// create getters and setters
		b = 0;
		while (true) {
			b++;
			var d = { get: null, set: null, type: null, ppg: null, pps: null, name: null };
			
			// get
			var r = new EReg("([\n\t ]+)([a-z]+)([ ]*)function([ ]*)get([ ]+)([a-zA-Z_][a-zA-Z0-9_]+)([ ]*)\\(([ ]*)\\)([ ]*):([ ]*)([A-Z][a-zA-Z0-9_]*)", "");
			var m = r.match(s);
			if (m) {
				d.ppg = r.matched(2);
				if (d.ppg == "") d.ppg = "public";
				d.name = r.matched(6);
				d.get = "get_" + d.name;
				d.type = r.matched(11);
			}
			
			// set
			var r = new EReg("([\n\t ]+)([a-z]+)([ ]*)function([ ]*)set([ ]+)([a-zA-Z_][a-zA-Z0-9_]*)([ ]*)\\(([ ]*)([a-zA-Z][a-zA-Z0-9_]*)([ ]*):([ ]*)([a-zA-Z][a-zA-Z0-9_]*)", "");
			var m = r.match(s);
			if (m) {
				if (r.matched(6) == d.get || d.get == null)
					if (d.name == null) d.name = r.matched(6);
				d.pps = r.matched(2);
				if (d.pps == "") d.pps = "public";
				d.set = "set_" + d.name;
				if (d.type == null) d.type = r.matched(12);
			}
			
			// ERROR
			if (b > maxLoop) { logLoopError("getter/setter: " + d, file); break; }

			// replace get
			if (d.get != null)
				s = regReplace(s, d.ppg + "([ ]+)function([ ]+)get([ ]+)" + d.name, "private function " + d.get);
			
			// replace set
			if (d.set != null)
				s = regReplace(s, d.pps + "([ ]+)function([ ]+)set([ ]+)" + d.name, "private function " + d.set);
			
			// make haxe getter/setter OR finish
			if (d.get != null || d.set != null) {
				var gs = (d.ppg != null ? d.ppg : d.pps) + " var " + d.name + "(" + (d.get != null ? 'get' : 'null') + ", " + (d.set != null ? 'set' : 'null') + "):" + d.type + ";";
				s = regReplace(s, "private function " + (d.get != null ? d.get : d.set), gs + "\n \tprivate function " + (d.get != null ? d.get : d.set));
			}else {
				break;
			}
		}
		
		// Replace undefined with null
		s = regReplace(s, "undefined", "null", "g");
		
		// Replace strict operators, with lose ones
		s = regReplace(s, "===", "==", "g");
		s = regReplace(s, "!==", "!=", "g");
		
		// Replace Function types with Dynamic
		s = regReplace(s, ":([ ]*)Function", ":$1Dynamic", "g");

		/* -----------------------------------------------------------*/
		
		// for loops that count
		// for (i=0; i < len; ++i) | for (var i : int = 0; i < len; ++i)
		s = regReplace(s, "for( *)\\(( *)(var )?([a-zA-Z_][a-zA-Z0-9_]*)( *: *[a-zA-Z_][a-zA-Z0-9_]+)? *= *([^;]*);[ a-zA-Z0-9_]*(<=|<|>|>=) *([a-zA-Z0-9_]*)[^\\)]*\\)", "for$1($2$4 in $6...$8$2)", "g");
		
		// for loops that count without setting a variable int
		//for (var i : int; i < len; ++i)
		s = regReplace(s, "for( *)\\(( *)var ?([a-zA-Z_][a-zA-Z0-9_]*)(: *Int) *;[ a-zA-Z0-9_]*(<=|<|>|>=) *([a-zA-Z0-9_]*)[^\\)]*\\)", "for$1($2$3 in 0...$6$2)", "g");
		
		
		
		// for each loops
		s = regReplace(s, "for each([ ]*)\\(([ ]*)(var )?([a-zA-Z_][a-zA-Z0-9_]*)( *: *[a-zA-Z_][a-zA-Z0-9_]*)?([ ]+)in([ ]+)([a-zA-Z_][a-zA-Z0-9_]*)([ ]*)\\)", "for$1($2$4 in $8$2)", "g"); 
		
		// for loops counting
		
		
		/* -----------------------------------------------------------*/

		var o = sys.io.File.write(toFile, true);
		o.writeString(s);
		o.close();
		
		// use for testing on a single file
		//Sys.exit(1);
	}
	
	private function logLoopError(type:String, file:String)
	{
		trace("ERROR: " + type + " - " + file);
	}
	
	private function buildNameSpaces()
	{
		// build friend namespaces!
		//trace(nameSpaces);
	}
	
	public static function regReplace(str:String, reg:String, rep:String, ?regOpt:String = "g"):String
	{
		return new EReg(reg, regOpt).replace(str, rep);
	}
	
	public static function regMatch(str:String, reg:String, ?numMatches:Int = 1, ?regOpt:String = "g"):Array<String>
	{
		var r = new EReg(reg, regOpt);
		var m = r.match(str);
		if (m) {
			var a = [];
			var i = 1;
			while (i <= numMatches) {
				a.push(r.matched(i));
				i++;
			}
			return a;
		}
		return [];
	}
	
	private function createFolder(path:String):Void
	{
		var parts = path.split("/");
		var folder = "";
		for (part in parts)
		{
			if (folder == "") folder += part;
			else folder += "/" + part;
			if (!FileSystem.exists(folder)) FileSystem.createDirectory(folder);
		}
	}
	
	private function parseArgs():Bool
	{
		// Parse args
		var args = Sys.args();
		for (i in 0...args.length)
			if (Lambda.has(keys, args[i]))
				Reflect.setField(this, args[i].substr(1), args[i + 1]);
			
		// Check to see if argument is missing
		if (to == null) { Lib.println("Missing argument '-to'"); return false; }
		if (from == null) { Lib.println("Missing argument '-from'"); return false; }
		
		return true;
	}
	
	public function recurse(path:String)
	{
		var dir = FileSystem.readDirectory(path);
		
		for (item in dir)
		{
			var s = path + "/" + item;
			if (FileSystem.isDirectory(s))
			{
				recurse(s);
			}
			else
			{
				var exts = ["as"];
				if(Lambda.has(exts, getExt(item)))
					items.push(s);
			}
		}
	}
	
	public function getExt(s:String)
	{
		return s.substr(s.lastIndexOf(".") + 1).toLowerCase();
	}
	
	public function removeDirectory(d, p = null)
	{
		if (p == null) p = d;
		var dir = FileSystem.readDirectory(d);

		for (item in dir)
		{
			item = p + "/" + item;
			if (FileSystem.isDirectory(item)) {
				removeDirectory(item);
			}else{
				FileSystem.deleteFile(item);
			}
		}
		
		FileSystem.deleteDirectory(d);
	}
	
	public static function fUpper(s:String)
	{
		return s.charAt(0).toUpperCase() + s.substr(1);
	}
}

class ClassDefs
{
	public var name:String;
	public var defs:Map<String, String>;
	
	public function new()
	{
		
	}
}