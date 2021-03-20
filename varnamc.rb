#!/usr/bin/env ruby

# encoding: utf-8

##
## Copyright (C) Navaneeth.K.N
##
## This is part of libvarnam. See LICENSE.txt for the license
##

=begin
'varnamc' is a command line client to libvarnam. It allows you to quickly try
libvarnam's features.

Usage - varnamc options <args>
=end

def gem_available?(name)
	require name
rescue LoadError
   false
end

if not gem_available?('ffi')
  puts "Can't find gem - ffi. To install run '[sudo] gem install ffi'"
  exit(1)
end

$options = {}
$libvarnam_major_version = 3

def find_libvarnam
  return $options[:library] if not $options[:library].nil?
  # Trying to find out libvarnam in the predefined locations if
  # absolute path to the library is not specified
  libvarnam_search_paths = ['.', File.dirname(File.expand_path(__FILE__)), '/usr/local/lib', '/usr/local/lib/i386-linux-gnu', '/usr/local/lib/x86_64-linux-gnu', '/usr/lib/i386-linux-gnu', '/usr/lib/x86_64-linux-gnu', '/usr/lib']
  libvarnam_names = ['libvarnam.so', "libvarnam.so.#{$libvarnam_major_version}", 'libvarnam.dylib', 'varnam.dll']
  libvarnam_search_paths.each do |path|
    libvarnam_names.each do |fname|
      fullpath = File.join(path, fname)
      if File.exists?(fullpath)
        return fullpath
      end
    end
  end
  return nil
end

$options[:library] = find_libvarnam
if $options[:library].nil?
  puts "varnamc - Can't find varnam shared library. Try specifying the full path using -l option"
  puts optparse
else
  puts "Using #{$options[:library]}" if $options[:verbose]
end

varnamruby_searchpaths = [".", File.dirname(File.expand_path(__FILE__)), "/usr/local/lib", "/usr/lib"]
varnamruby_loaded = false
varnamruby_searchpaths.each do |p|
  begin
    require "#{p}/varnamruby.rb"
    varnamruby_loaded = true
    break
  rescue LoadError
    # Trying next possibility
  end
end

if not varnamruby_loaded
  puts "Failed to find varnamruby.rb. Search paths: #{varnamruby_searchpaths}"
  puts "This could be because you have a corrupted installation or a bug in varnamc"
  exit(1)
end

require 'optparse'
require 'fileutils'

# Defining command line options
$options[:action] = nil
def set_action(a)
  if $options[:action].nil?
    $options[:action] = a
  else
    puts "varnamc : #{$options[:action]} and #{a} are mutually exclusive options. Only one action is allowed"
    exit(1)
  end
end


optparse = OptionParser.new do |opts|
  opts.banner = "Usage: varnamc options args"

  # ability to provide varnam library name
  $options[:library] = nil
  opts.on('-l', '--library FILE', 'Sets the varnam library') do |file|
    if not File.exist?(file)
      puts "varnamc : Can't find #{file}"
      exit 1
    end
    $options[:library] = file
  end

  $options[:verbose] = false
  opts.on('-v', '--verbose', 'Enable verbose output') do
    $options[:verbose] = true
  end

  $options[:debug] = false
  opts.on('-z', '--debug', 'Enable debugging') do
    $options[:debug] = true
  end

  opts.on('-t', '--transliterate TEXT', 'Transliterate the given text') do |text|
    set_action('transliterate')
    $options[:text_to_transliterate] = text
  end

  $options[:indic_digits] = false
  opts.on('--indic-digits', 'Turns on indic digit rendering while transliterating') do
    $options[:indic_digits] = true
  end

  opts.on('-r', '--reverse-transliterate TEXT', 'Reverse transliterate the given text') do |text|
    $options[:text_to_reverse_transliterate] = text
    set_action('reverse-transliterate')
  end

  opts.on('-n', '--learn [TEXT]', 'Learn the given text') do |text|
    $options[:text_to_learn] = text
    set_action('learn')
  end

  opts.on('-a', '--train PATTERN=WORD', 'Train varnam to use PATTERN for WORD') do |str|
    training_data = str.split('=')
    if not training_data.size == 2
      puts 'varnamc : Incorrect arguments'
      exit(1)
    end
    $options[:training_data] = training_data
    set_action('train')
  end

  opts.on('-f', '--learn-from FILE|DIRECTORY', 'Reads from the specified file/directory') do |path|
    if File.exists? (path)
      if File.directory?(path)
        set_action('learn-from-directory')
      else
        set_action('learn-from-file')
      end
      $options[:learn_from] = path
    else
      puts "varnamc : #{path} is incorrect"
      exit(1)
    end
  end

  opts.on('--train-from FILE|DIRECTORY', 'Reads the specified file/directory and trains all the words specified') do |path|
    if File.exists? (path)
      if File.directory?(path)
        set_action('train-from-directory')
      else
        set_action('train-from-file')
      end
      $options[:train_from] = path
    else
      puts "varnamc : #{path} is incorrect"
      exit(1)
    end
  end

  opts.on('-e','--export-words', 'Export words to the output directory') do
     set_action('export-words')
  end

  opts.on('--export-full', 'Export words & patterns to the output directory') do
     set_action('export-full')
  end

  opts.on('--import-learnings-from FILE|DIRECTORY', 'Import learned data from the specified file/directory') do |path|
    if File.exists? (path)
      if File.directory?(path)
        set_action('import-learnings-from-directory')
      else
        set_action('import-learnings-from-file')
      end
      $options[:import_learnings_from] = path
    else
      puts "varnamc : #{path} is incorrect"
      exit(1)
    end
  end

  $options[:symbols_file] = nil
  opts.on('-s', '--symbols VALUE', 'Sets the symbols file') do |value|
    if File.exist?(value)
      $options[:symbols_file] = value
    else
      $options[:lang_code] = value;
    end
  end

  $options[:file_to_compile] = nil
  opts.on('-c', '--compile FILE', 'Compile symbols file') do |file|
    if not File.exist?(file)
      puts "Can't find #{file}"
      exit(1)
    end
    $options[:file_to_compile] = file
    set_action('compile')
  end

  $options[:learnings_file] = nil
  opts.on('--learnings-file FILE', 'Specify the file to store all learnings') do |file|
    $options[:learnings_file] = file
  end

  $options[:word_to_detect_lang] = nil
  opts.on('--detect-language WORD', 'Detect language of the word') do |word|
    set_action('detect')
    $options[:word_to_detect_lang] = word
  end

  $options[:output_directory] = nil
  opts.on('-d', '--output-dir dir', 'Sets the output directory') do |directory|
    if not Dir.exist?(directory)
      puts "#{directory} is not a directory"
      exit(1)
    end
    $options[:output_directory] = directory
  end

  # help screen
  opts.on( '-h', '--help', 'Display this screen' ) do
    puts opts
    exit
  end

  opts.on( '--schemes-available', 'Display all available schemes' ) do
    set_action('schemes-available')
  end

  opts.on('--version', 'Display version' ) do
    puts "libvarnam version #{VarnamLibrary.varnam_version()}"
    exit
  end

end

begin
  optparse.parse!
rescue => e
  puts "varnamc : incorrect arguments"
	puts e.to_s
  puts optparse
  exit(1)
end

if $options[:action].nil?
  puts "varnamc : no actions specified"
  puts optparse
  exit(1)
end

$suggestions_file = ''

def initialize_varnam_handle
  if $options[:action] == 'compile'
    $vst_file_name = $options[:file_to_compile].sub(File.extname($options[:file_to_compile]), "") + ".vst"

    if not $options[:output_directory].nil?
      $vst_file_name = get_file_path(File.basename($vst_file_name))
    end

    if File.exists?($vst_file_name)
      File.delete($vst_file_name)
    end
  else
    $vst_file_name = $options[:symbols_file]
  end

  initialized = false;
  $varnam_handle = FFI::MemoryPointer.new :pointer
  init_error_msg = FFI::MemoryPointer.new(:pointer, 1)
  if not $vst_file_name.nil?
    initialized = VarnamLibrary.varnam_init($vst_file_name, $varnam_handle, init_error_msg)
    # Configuring suggestions
    $options[:learnings_file] = get_learnings_file $vst_file_name
    configured = VarnamLibrary.varnam_config($varnam_handle.get_pointer(0), Varnam::VARNAM_CONFIG_ENABLE_SUGGESTIONS, :string, $options[:learnings_file])
    if configured != 0
        error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
        error error_message
        exit(1)
    end
  elsif not $options[:lang_code].nil?
    sources_root = ENV["VARNAM_SOURCES_ROOT"]
    unless sources_root.nil?
      VarnamLibrary.varnam_set_symbols_dir "#{ENV['VARNAM_SOURCES_ROOT']}/schemes"
    end
    initialized = VarnamLibrary.varnam_init_from_id($options[:lang_code], $varnam_handle, init_error_msg)
    if initialized == 0 and not $options[:learnings_file].nil?
      # User has specified explicit learnings file. Use that instead of the default one
      configured = VarnamLibrary.varnam_config($varnam_handle.get_pointer(0), Varnam::VARNAM_CONFIG_ENABLE_SUGGESTIONS, :string, $options[:learnings_file])
      if configured != 0
        error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
        error error_message
        exit(1)
      end
    end
  else
    puts "varnamc : Can't load symbols file. Use --symbols option to specify the symbols file"
    exit(1)
  end

  if (initialized != 0)
    ptr = init_error_msg.read_pointer()
    msg = ptr.nil? ? "" : ptr.read_string
    puts "Varnam initialization failed #{msg}"
    exit(1)
  end

  if ($options[:debug])
    puts "Turning debug on"
    done = VarnamLibrary.varnam_enable_logging($varnam_handle.get_pointer(0), Varnam::VARNAM_LOG_DEBUG, DebugCallback);
    if done != 0
      error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
      puts "Unable to turn debugging on. #{error_message}"
      exit(1)
    end
  end

end

def get_file_path(fname)
  if $options[:output_directory].nil?
    return File.join(Dir.home, ".local/share/varnam", fname)
  else
    return File.join($options[:output_directory], fname)
  end
end

def get_learnings_file(symbols_file_name)
  return $options[:learnings_file] if not $options[:learnings_file].nil?

  # we use the standard $HOME/.local/share/varnam/suggestions
  make_suggestions_dir_if_required
  return get_file_path(File.join("suggestions", "#{File.basename(symbols_file_name, ".")}.learnings"))
end

def make_suggestions_dir_if_required
  out_dir = File.join(Dir.home, '.local/share/varnam/suggestions')
  if not $options[:output_directory].nil?
      out_dir = $options[:output_directory]
  end
  FileUtils.mkdir_p out_dir if not Dir.exists?(out_dir)
end

def do_action
  if $options[:action] == 'schemes-available'
		display_available_schemes
		return
  end

  initialize_varnam_handle
  if $options[:action] == 'transliterate'
    transliterate
  end
  if $options[:action] == 'reverse-transliterate'
    reverse_transliterate
  end
  if $options[:action] == 'compile'
    start_compilation
  end
  if $options[:action] == 'learn'
    learn_text
  end
  if $options[:action] == 'learn-from-file'
    learn_from_file
  end
  if $options[:action] == 'learn-from-directory'
    learn_from_directory
  end
  if $options[:action] == 'train-from-file'
    train_from_file
  end
  if $options[:action] == 'train-from-directory'
    train_from_directory
  end

  if $options[:action] == 'export-words' or $options[:action] == 'export-full'
      export_words
  end

  if $options[:action] == 'train'
    train_pattern_word
  end
  if $options[:action] == 'detect'
    detect_language
  end

  if $options[:action] == 'import-learnings-from-file'
      import_learnings_from_file
  end

  if $options[:action] == 'import-learnings-from-directory'
      import_learnings_from_directory
  end

end

$custom_lists = {}
$current_custom_list = []

# Starts a list context. Any tokens created inside will get added to this list
# It can have multiple list names and token will get added to all of these. One token
# can be in multiple lists
def list(*names, &block)
    if not $current_custom_list.empty?
        # This happens when user tries to nest list.
        # Nesting list is not allowed
        error "Can't create nested list"
        exit (1)
    end

    if names.empty?
        error "List should have a name"
        exit (1)
    end

    names.each do |name|
        if not name.is_a?(String) and not name.is_a?(Symbol)
            error "List name should be a string or symbols"
            exit (1)
        end

        $custom_lists[name] = [] if not $custom_lists.has_key?(name)
        $current_custom_list << $custom_lists[name]
    end

    yield if block_given?
ensure
    $current_custom_list = []
end

def push_to_current_custom_list(token)
    if token.nil?
        error "Can't add empty token"
        exit (1)
    end

    $current_custom_list.each do |l|
        l.push(token)
    end
end

# We handle method missing to return appropriate lists
def self.method_missing(name, *args, &block)
    return $custom_lists[name] if $custom_lists.has_key?(name)
    super
end


# this contains default symbols key overridden in the scheme file
# key will be the token type
$overridden_default_symbols = []

def _ensure_sanity_of_array(array)
  # Possibilities are
  #  [e1, e2]
  #  [e1, [e2,e3], e4]
  error "An empty array won't workout" if array.size == 0
  array.each do |element|
    if element.is_a?(Array)
      _ensure_sanity_of_array(element)
    else
      _ensure_type_safety(element)
    end
  end
end

def _ensure_sanity_of_element(element)
  if element.is_a?(Array)
    _ensure_sanity_of_array(element)
  else
    _ensure_type_safety(element)
    if element.is_a?(String) and element.length == 0
      error "Empty values are not allowed"
    end
  end
end

def _ensure_type_safety(element)
  valid_types = [Fixnum, String, Array]
  error "#{element.class} is not a valid type. Valid types are #{valid_types.to_s}" if not valid_types.include?(element.class)
end

def _ensure_sanity(hash)
  if not hash.is_a?(Hash)
    error "Expected a Hash, but got a #{hash.class}"
    exit 1
  end

  hash.each_pair do |key, value|
    _context.current_expression = "#{key} => #{value}"

    _ensure_sanity_of_element (key)
    _ensure_sanity_of_element (value)

    warn "#{value} has more than three elements. Additional elements specified will be ignored" if value.is_a?(Array) and value.size > 3

    _context.current_expression = nil
  end
end

def _extract_keys_values_and_persist(keys, values, token_type, match_type = Varnam::VARNAM_MATCH_EXACT, priority, accept_condition)
  keys.each do |key|
    if key.is_a?(Array)
      # This a possibility match
      key.flatten!
      _extract_keys_values_and_persist(key, values, token_type, Varnam::VARNAM_MATCH_POSSIBILITY, priority, accept_condition)
    else
      _persist_key_values(key, values, token_type, match_type, priority, accept_condition)
    end
  end
end

def _persist_key_values(pattern, values, token_type, match_type, priority, accept_condition)
  return if _context.errors > 0

  match = match_type == Varnam::VARNAM_MATCH_EXACT ? "EXACT" : "POSSIBILITY"

  if (values.is_a?(Array))
    values.flatten!
    value1 = values[0]
    value2 = values[1] if values.size >= 2
    value3 = values[2] if values.size >= 3
  else
    value1 = values
    value2 = ""
    value3 = ""
  end

  tag = _context.current_tag
  tag = "" if tag.nil?
  created = VarnamLibrary.varnam_create_token($varnam_handle.get_pointer(0), pattern, value1, value2, value3, tag, token_type, match_type, priority, accept_condition, 1)
  if created != 0
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    error error_message
    return
  end

  _context.tokens[token_type] = [] if _context.tokens[token_type].nil?
  vtoken = VarnamToken.new(token_type, pattern, value1, value2, value3, tag, match_type, priority, accept_condition)
  _context.tokens[token_type].push(vtoken)
  push_to_current_custom_list vtoken
end

def flush_unsaved_changes
  saved = VarnamLibrary.varnam_flush_buffer($varnam_handle.get_pointer(0))
  if saved != 0
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    error error_message
    return
  end
end

def infer_dead_consonants(infer)
  configured = VarnamLibrary.varnam_config($varnam_handle.get_pointer(0), Varnam::VARNAM_CONFIG_USE_DEAD_CONSONANTS, :int, infer ? 1 : 0)
  if configured != 0
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    error error_message
    return
  end
end

def ignore_duplicates(ignore)
  configured = VarnamLibrary.varnam_config($varnam_handle.get_pointer(0), Varnam::VARNAM_CONFIG_IGNORE_DUPLICATE_TOKEN, :int, ignore ? 1 : 0)
  if configured != 0
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    error error_message
    return
  end
end

def set_scheme_details()
	d = VarnamLibrary::SchemeDetails.new
	d[:langCode] = FFI::MemoryPointer.from_string($scheme_details[:langCode])
	d[:identifier] = FFI::MemoryPointer.from_string($scheme_details[:identifier])
	d[:displayName] = FFI::MemoryPointer.from_string($scheme_details[:displayName])
	d[:author] = FFI::MemoryPointer.from_string($scheme_details[:author])
	d[:compiledDate] = FFI::MemoryPointer.from_string(Time.now.to_s)
	if $scheme_details[:isStable].nil?
		d[:isStable] = 0
	else
		d[:isStable] = $scheme_details[:isStable]
	end

  done = VarnamLibrary.varnam_set_scheme_details($varnam_handle.get_pointer(0), d.pointer)
  if done != 0
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    error error_message
    return
  end
end

$scheme_details = {}

def language_code(code)
	$scheme_details[:langCode] = code
end

def identifier(id)
	$scheme_details[:identifier] = id
end

def display_name(name)
	$scheme_details[:displayName] = name
end

def author(name)
	$scheme_details[:author] = name
end

def stable(value)
	$scheme_details[:isStable] = 0
	$scheme_details[:isStable] = 1 if value
end

def generate_cv
    all_vowels = get_vowels
    all_consonants = get_consonants

    all_consonants.each do |c|
        consonant_has_inherent_a_sound = c.pattern.end_with?('a') and not c.pattern[c.pattern.length - 2] == 'a'
        all_vowels.each do |v|
            next if v.value2.nil? or v.value2.length == 0

            if consonant_has_inherent_a_sound
                pattern = "#{c.pattern[0..c.pattern.length-2]}#{v.pattern}"
            else
                pattern = "#{c.pattern}#{v.pattern}"
            end

            values = ["#{c.value1}#{v.value2}"]
            if c.match_type == Varnam::VARNAM_MATCH_POSSIBILITY or v.match_type == Varnam::VARNAM_MATCH_POSSIBILITY
                match_type = Varnam::VARNAM_MATCH_POSSIBILITY
            else
                match_type = Varnam::VARNAM_MATCH_EXACT
            end

            accept_condition = nil
            if not v.accept_condition == Varnam::VARNAM_TOKEN_ACCEPT_ALL and not c.accept_condition == Varnam::VARNAM_TOKEN_ACCEPT_ALL
                accept_condition = v.accept_condition
            elsif not v.accept_condition == Varnam::VARNAM_TOKEN_ACCEPT_ALL
                accept_condition = v.accept_condition
            else
                accept_condition = c.accept_condition
            end

            priority = Varnam::VARNAM_TOKEN_PRIORITY_NORMAL
            if v.priority < c.priority
                priority = v.priority
            else
                priority = c.priority
            end


            _persist_key_values pattern, values, Varnam::VARNAM_TOKEN_CONSONANT_VOWEL, match_type, priority, accept_condition
        end
    end
end

def combine_array(array, is_pattern, replacements, current_item)
    if replacements.empty?
        error 'Replacements should be present when combining an array. This could be a bug within varnamc'
        exit (1)
    end

    result = []
    array.each do |a|
        if a.is_a?(Array)
            result.push(combine_array(a, is_pattern, replacements, current_item))
        else
            if is_pattern
                if current_item.match_type == Varnam::VARNAM_MATCH_POSSIBILITY
                    result.push([a.to_s.gsub("*", replacements[0])])
                else
                    result.push(a.to_s.gsub("*", replacements[0]))
                end
            else
                new_key = a.to_s.gsub("\*1", replacements[0])
                if replacements.length > 1 and not replacements[1].to_s.empty?
                    new_key = new_key.gsub("\*2", replacements[1])
                end
                if replacements.length > 2 and not replacements[2].to_s.empty?
                    new_key = new_key.gsub("\*3", replacements[2])
                end
                result.push (new_key)
            end
        end
    end

    return result
end

# Combines an array and a hash values
# This method also replaces the placeholder in hash
def combine(array, hash)
    _ensure_sanity(hash)
    if not array.is_a?(Array)
        error "Expected an array, but got a #{array.class}"
        exit 1
    end

    grouped = {}
    array.each do |item|
        hash.each_pair do |key, value|
            new_key = nil
            if key.is_a?(Array)
                new_key = combine_array(key, true, [item.pattern], item)
            else
                if item.match_type == Varnam::VARNAM_MATCH_POSSIBILITY
                    new_key = [[key.to_s.gsub("*", item.pattern)]]
                else
                    new_key = key.to_s.gsub("*", item.pattern)
                end
            end

            new_value = nil
            if value.is_a?(Array)
                new_value = combine_array(value, false, [item.value1, item.value2, item.value3], item)
            else
                new_value = value.to_s.gsub("\*1", item.value1)
                if not item.value2.nil? and not item.value2.to_s.empty?
                    new_value = new_value.gsub("\*2", item.value2)
                end
                if not item.value3.nil? and not item.value3.to_s.empty?
                    new_value = new_value.gsub("\*3", item.value3)
                end
            end

            if grouped[new_value].nil?
                grouped[new_value] = new_key
            else
                grouped[new_value].push(new_key)
            end
        end
    end

    # invert the hash
    result = {}
    grouped.each_pair do |key, value|
        result[value] = key
    end

    return result
end

def _create_token(hash, token_type, options = {})
  return if _context.errors > 0

  priority = _get_priority options
  accept_condition = _get_accept_condition options

  hash.each_pair do |key, value|
    if key.is_a?(Array)
      _extract_keys_values_and_persist(key, value, token_type, priority, accept_condition)
    else
      _persist_key_values(key, value, token_type, Varnam::VARNAM_MATCH_EXACT, priority, accept_condition)
    end
  end
end

def _validate_number(number, name)
    if not number.is_a?(Integer)
        error "#{name} should be a number"
        exit (1)
    end
end

def _get_priority(options)
    return Varnam::VARNAM_TOKEN_PRIORITY_NORMAL if options[:priority].nil? or options[:priority] == :normal
    return Varnam::VARNAM_TOKEN_PRIORITY_LOW if options[:priority] == :low
    return Varnam::VARNAM_TOKEN_PRIORITY_HIGH if options[:priority] == :high

    _validate_number options[:priority], "priority"

    return options[:priority]
end

def _get_accept_condition(options)
    return Varnam::VARNAM_TOKEN_ACCEPT_ALL if options[:accept_if].nil? or options[:accept_if] == :all
    return Varnam::VARNAM_TOKEN_ACCEPT_IF_STARTS_WITH if options[:accept_if] == :starts_with
    return Varnam::VARNAM_TOKEN_ACCEPT_IF_IN_BETWEEN if options[:accept_if] == :in_between
    return Varnam::VARNAM_TOKEN_ACCEPT_IF_ENDS_WITH if options[:accept_if] == :ends_with

    _validate_number options[:accept_if], "accept_if"
end

def vowels(options={}, hash)
  _ensure_sanity(hash)
  _create_token(hash, Varnam::VARNAM_TOKEN_VOWEL, options)
end

def consonants(options={}, hash)
  _ensure_sanity(hash)
  _create_token(hash, Varnam::VARNAM_TOKEN_CONSONANT, options)
end

def period(p)
	_create_token({"." => p}, Varnam::VARNAM_TOKEN_PERIOD, {})
end

def tag(name, &block)
   _context.current_tag = name
   block.call
   _context.current_tag = nil
end

def consonant_vowel_combinations(options={}, hash)
  _ensure_sanity(hash)
  _create_token(hash, Varnam::VARNAM_TOKEN_CONSONANT_VOWEL, options)
end

def anusvara(options={}, hash)
  _ensure_sanity(hash)
  _create_token(hash, Varnam::VARNAM_TOKEN_ANUSVARA, options)
end

def visarga(options={}, hash)
  _ensure_sanity(hash)
  _create_token(hash, Varnam::VARNAM_TOKEN_VISARGA, options)
end

def virama(options={}, hash)
  _ensure_sanity(hash)
  _create_token(hash, Varnam::VARNAM_TOKEN_VIRAMA, options)
end

def symbols(options={}, hash)
  _ensure_sanity(hash)
  _create_token(hash, Varnam::VARNAM_TOKEN_SYMBOL, options)
end

def numbers(options={}, hash)
  _ensure_sanity(hash)
  _create_token(hash, Varnam::VARNAM_TOKEN_NUMBER, options)
end

def others(options={}, hash)
  _ensure_sanity(hash)
  _create_token(hash, Varnam::VARNAM_TOKEN_OTHER, options)
end

def non_joiner(hash)
  _ensure_sanity(hash)
  _create_token(hash, Varnam::VARNAM_TOKEN_NON_JOINER);
  $overridden_default_symbols.push Varnam::VARNAM_TOKEN_NON_JOINER
end

def joiner(hash)
  _ensure_sanity(hash)
  _create_token(hash, Varnam::VARNAM_TOKEN_JOINER);
  $overridden_default_symbols.push Varnam::VARNAM_TOKEN_JOINER
end

def get_tokens(token_type, criteria = {})
  tokens = _context.tokens[token_type]
  if criteria.empty?
    return tokens
  elsif criteria[:exact]
    return tokens.find_all {|t| t.match_type == Varnam::VARNAM_MATCH_EXACT}
  else
    return tokens.find_all {|t| t.match_type == Varnam::VARNAM_MATCH_POSSIBILITY}
  end
end

def get_vowels(criteria = {})
  return get_tokens(Varnam::VARNAM_TOKEN_VOWEL, criteria)
end

def get_consonants(criteria = {})
  return get_tokens(Varnam::VARNAM_TOKEN_CONSONANT, criteria)
end

def get_consonant_vowel_combinations(criteria = {})
  return get_tokens(Varnam::VARNAM_TOKEN_CONSONANT_VOWEL, criteria)
end

def get_anusvara(criteria = {})
  return get_tokens(Varnam::VARNAM_TOKEN_ANUSVARA, criteria)
end

def get_visarga(criteria = {})
  return get_tokens(Varnam::VARNAM_TOKEN_VISARGA, criteria)
end

def get_symbols(criteria = {})
  return get_tokens(Varnam::VARNAM_TOKEN_SYMBOL, criteria)
end

def get_numbers(criteria = {})
  return get_tokens(Varnam::VARNAM_TOKEN_OTHER, criteria)
end

def get_virama
    tokens = get_tokens(Varnam::VARNAM_TOKEN_VIRAMA, {})
    if tokens.empty?
        error 'Virama is not set'
        exit (1)
    end
    return tokens[0]
end

def ffito_string(value)
  str = ""
  ptr = value.to_ptr
  if not ptr.null?
    str = ptr.read_string
    str.force_encoding('UTF-8')
  end
  return str
end

def get_dead_consonants(criteria = {})
  # dead consonants are infered by varnam. ruby wrapper don't know anything about it.
  token_type = Varnam::VARNAM_TOKEN_DEAD_CONSONANT
  token_ptr = FFI::MemoryPointer.new :pointer
  done = VarnamLibrary.varnam_get_all_tokens($varnam_handle.get_pointer(0), token_type, token_ptr);
  if done != 0
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    error error_message
    return
  end

  size = VarnamLibrary.varray_length(token_ptr.get_pointer(0))
  i = 0
  _context.tokens[token_type] = [] if _context.tokens[token_type].nil?
  until i >= size
    tok = VarnamLibrary.varray_get(token_ptr.get_pointer(0), i)
    ptr = token_ptr.read_pointer
    item = VarnamLibrary::Token.new(tok)
    varnam_token = VarnamToken.new(item[:type],
                                   ffito_string(item[:pattern]), ffito_string(item[:value1]),
                                   ffito_string(item[:value2]), ffito_string(item[:value3]),
                                   ffito_string(item[:tag]), item[:match_type])
    _context.tokens[token_type].push(varnam_token)
    i += 1
  end
  return get_tokens(token_type, criteria)
end

def print_warnings_and_errors
  if _context.warnings > 0
    _context.warning_messages.each do |msg|
      puts msg
    end
  end

  if _context.errors > 0
    _context.error_messages.each do |msg|
      puts msg
    end
  end
end

# Sets default symbols if user has not set overridden in the scheme file
def set_default_symbols
  non_joiner "_" => "_"  if not $overridden_default_symbols.include?(Varnam::VARNAM_TOKEN_NON_JOINER)
  joiner "__" => "__"  if not $overridden_default_symbols.include?(Varnam::VARNAM_TOKEN_JOINER)
  symbols "-" => "-"
end

def start_compilation
  puts "Compiling #{$options[:file_to_compile]}"
  puts "Building #{$vst_file_name}"

  at_exit {
      print_warnings_and_errors if _context.errors > 0
      puts "Completed with '#{_context.warnings}' warning(s) and '#{_context.errors}' error(s)"
  }

  load $options[:file_to_compile]
  set_default_symbols
  flush_unsaved_changes
  set_scheme_details

  if _context.errors > 0
      returncode = 1
  else
      returncode = 0
  end

  exit(returncode)
end

def ensure_single_word(text)
  if text.split(' ').length > 1
    puts "varnamc : Expected a single word."
    exit(1)
  end
end

def transliterate
  if $options[:text_to_transliterate].nil?
    puts "Nothing to transliterate"
    exit 1
  end
  totl = $options[:text_to_transliterate]
  ensure_single_word totl

  if $options[:indic_digits]
      configured = VarnamLibrary.varnam_config($varnam_handle.get_pointer(0),
                                               Varnam::VARNAM_CONFIG_USE_INDIC_DIGITS, :string, "1")
      if configured != 0
          error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
          error error_message
          exit(1)
      end
  end

  words_ptr = FFI::MemoryPointer.new :pointer
  done = VarnamLibrary.varnam_transliterate($varnam_handle.get_pointer(0), totl, words_ptr);
  if done != 0
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    puts error_message
    exit(1)
  end

  size = VarnamLibrary.varray_length(words_ptr.get_pointer(0))
  0.upto(size - 1) do |i|
    word_ptr = VarnamLibrary.varray_get(words_ptr.get_pointer(0), i)
    vword = VarnamLibrary::Word.new(word_ptr)
    word = VarnamWord.new(vword[:text], vword[:confidence])
    puts "  " + word.text
  end
end

def reverse_transliterate
  if $options[:text_to_reverse_transliterate].nil?
    puts "Nothing to reverse transliterate"
    exit 1
  end
  tortl = $options[:text_to_reverse_transliterate]
  ensure_single_word tortl

  output_ptr = FFI::MemoryPointer.new(:pointer, 1)
  done = VarnamLibrary.varnam_reverse_transliterate($varnam_handle.get_pointer(0), tortl, output_ptr);
  if done != 0
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    puts error_message
    exit(1)
  end

  ptr = output_ptr.read_pointer()
  output = ptr.nil? ? "" : ptr.read_string
  puts output
end

def learn_text
  if $options[:text_to_learn].nil?
    puts "Nothing to learn"
    exit 1
  end

  text = $options[:text_to_learn]
  ensure_single_word text
  done = VarnamLibrary.varnam_learn($varnam_handle.get_pointer(0), text);
  if done != 0
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    puts error_message
    exit(1)
  end
  puts "Learned #{text}"
end

$learn_counter = 0
$learn_passed_counter = 0
$learn_failed_counter = 0
$failure_log = nil

$train_counter = 0
$train_passed_counter = 0
$train_failed_counter = 0
$train_failure_log = nil

LearnCallback = FFI::Function.new(:void, [:pointer, :string, :int, :pointer]) do |handle, word, status, data|
  if status == 0
    #puts "(#{$learn_counter}) Learned #{word}"
    $learn_passed_counter += 1
  else
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    puts "Failed to learn #{word}. #{error_message}"
    $failure_log = File.open(get_file_path("varnamc-learn-failures.txt"), "w") if $failure_log.nil?
    $failure_log.puts word + ' : ' + error_message
    $learn_failed_counter += 1
  end
  $learn_counter += 1
end

ExportCallback = FFI::Function.new(:void, [:int, :int, :string]) do |total_words, total_processed, current_word|
    percentage = (total_processed.to_f / total_words) * 100
    print "\rExporting #{percentage.to_int}%"
    $stdout.flush
end

DebugCallback = FFI::Function.new(:void, [:string]) do |message|
  puts message
end

def learn_from_file
  if $options[:learn_from].nil?
    puts "Nothing to learn"
    exit 1
  end

  fname = $options[:learn_from]
  learn_words_in_the_file fname

  puts "Processed #{$learn_counter} word(s). #{$learn_passed_counter} word(s) passed. #{$learn_failed_counter} word(s) failed."
  puts "Failed words are logged to - #{$failure_log.path}" if $learn_failed_counter > 0
  $failure_log.close if not $failure_log.nil?
end

def learn_words_in_the_file(fname, compact = true)
  done = VarnamLibrary.varnam_learn_from_file($varnam_handle.get_pointer(0), fname, nil, LearnCallback, nil);
  if done != 0
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    puts error_message
    exit(1)
  end
  compact_learnings_file if compact
end

def learn_from_directory
  puts "Processing files from #{$options[:learn_from]}"
  if $options[:learn_from].nil?
    puts "Nothing to learn"
    exit 1
  end

  path = $options[:learn_from]
  files = Dir.glob("#{path}/**/*.txt")
  puts "Found #{files.size} file(s)"

  files.each_with_index do |fname, index|
    if not File.directory?(fname)
      puts "(#{index + 1}/#{files.size}) Processing #{fname}"
      learn_words_in_the_file fname, false
    end
  end

  compact_learnings_file

  puts "Processed #{$learn_counter} word(s). #{$learn_passed_counter} word(s) passed. #{$learn_failed_counter} word(s) failed."
  puts "Failed words are logged to - #{$failure_log.path}" if $learn_failed_counter > 0
  $failure_log.close unless $failure_log.nil?
end

def compact_learnings_file
  puts "Compacting the generated file..."
	done = VarnamLibrary.varnam_compact_learnings_file($varnam_handle.get_pointer(0));
	if done != 0
		error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
		raise error_message
	end
end

def train_words_in_the_file(fname)
    text = File.open(fname).read.force_encoding('UTF-8').encode('UTF-8')
    text.gsub!(/\r\n?/, "\n")
    text.each_line do |line|
        parts = line.split(' ')
        if not parts.length == 2
            message = "Error at text: #{line.strip}. Invalid format. Each line should contain pattern and word separated with a single space"
            puts message
            $train_failure_log = File.open(get_file_path("varnamc-train-failures.txt"), "w") if $train_failure_log.nil?
            $train_failure_log.puts message
            $train_failed_counter += 1
        else
            pattern = parts[0]
            value = parts[1]
            error = perform_training(pattern, value)
            if not error.nil?
                message = "Failed to train #{pattern} => #{value}. #{error.force_encoding('UTF-8')}"
                $train_failure_log = File.open(get_file_path("varnamc-train-failures.txt"), "w") if $train_failure_log.nil?
                $train_failure_log.puts message
                $train_failed_counter += 1
            else
                $train_passed_counter += 1
            end
        end
        $train_counter += 1
    end
end

def train_from_file
  if $options[:train_from].nil?
    puts "Nothing to train"
    exit 1
  end

  fname = $options[:train_from]
  train_words_in_the_file fname

  puts "Processed #{$train_counter} word(s). #{$train_passed_counter} word(s) passed. #{$train_failed_counter} word(s) failed."
  puts "Failed words are logged to - #{$train_failure_log.path}" if $train_failed_counter > 0
  $train_failure_log.close if not $train_failure_log.nil?
end

def train_from_directory
  puts "Processing files from #{$options[:train_from]}"
  if $options[:train_from].nil?
    puts "Nothing to train"
    exit 1
  end

  path = $options[:train_from]
  files = Dir.glob("#{path}/**/*.txt")
  puts "Found #{files.size} file(s)"

  files.each_with_index do |fname, index|
    if not File.directory?(fname)
      puts "(#{index + 1}/#{files.size}) Processing #{fname}"
      train_words_in_the_file fname
    end
  end
  puts "Processed #{$train_counter} word(s). #{$train_passed_counter} word(s) passed. #{$train_failed_counter} word(s) failed."
  puts "Failed words are logged to - #{$train_failure_log.path}" if $train_failed_counter > 0
  $train_failure_log.close
end

def perform_training(pattern, word)
    ensure_single_word pattern
    ensure_single_word word

    done = VarnamLibrary.varnam_train($varnam_handle.get_pointer(0), pattern, word);
    if done != 0
        error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
        return error_message
    end

    return nil
end

def train_pattern_word
  if not $options[:training_data].size == 2
    puts "varnamc : Incorrect training data"
    exit(1)
  end

  pattern = $options[:training_data][0]
  word = $options[:training_data][1]

  error = perform_training(pattern, word);
  if not error.nil?
      puts error
      exit(1)
  end

  puts "Success. #{pattern} will resolve to #{word}"
end

$import_failure_log = nil
$import_failure_count = 0
ImportFailureCallback = FFI::Function.new(:void, [:string]) do |current_word|
    if $import_failure_log.nil?
        $import_failure_log = File.open(get_file_path("varnamc-import-failures.txt"), "w")
    end
    $import_failure_log.puts current_word
    $import_failure_count += 1
end

def import_learned_words_in_the_file(fname)
    if not File.exists?(fname)
        puts "Invalid file: #{fname}"
        exit (1)
    end

    done = VarnamLibrary.varnam_import_learnings_from_file($varnam_handle.get_pointer(0), fname, ImportFailureCallback);
    if done != 0
        error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
        puts error_message
    exit(1)
    end
end

def import_learnings_from_file
    if $options[:import_learnings_from].nil?
        puts "Nothing to import"
        exit (1)
    end

    fname = $options[:import_learnings_from]
    puts "Importing: #{fname}"
    import_learned_words_in_the_file fname
end

def import_learnings_from_directory
    path = $options[:import_learnings_from]
    if path.nil?
        puts "Nothing to import"
        exit 1
    end

    puts "Processing files from #{path}"
    files = Dir.glob("#{path}/**/*.words.txt")
    files.concat Dir.glob("#{path}/**/*.patterns.txt")
    puts "Found #{files.size} file(s)"

    files.each_with_index do |fname, index|
        if not File.directory?(fname)
            puts "(#{index + 1}/#{files.size}) Processing #{fname}"
            import_learned_words_in_the_file fname
        end
    end
    puts "Processed #{files.size} file(s)."
    puts "#{$import_failure_count} failed. Failed words are logged to #{$import_failure_log.path}" if $import_failure_count > 0
    $failure_log.close if not $failure_log.nil?
end


def detect_language
  if $options[:word_to_detect_lang].nil?
    puts "varnamc : No word found"
    exit(1)
  end

  word = $options[:word_to_detect_lang]
  ensure_single_word word

  code = VarnamLibrary.varnam_detect_lang($varnam_handle.get_pointer(0), word);
  puts Varnam::LANG_CODES[code]
end

def export_words
  if $options[:output_directory].nil?
    puts "varnamc : Output directory not found"
    exit(1)
  end

  outDir = $options[:output_directory]
  puts "Exporting words from '#{$options[:learnings_file]}' to '#{outDir}'"

  # Removing any trailing /
  outDir[outDir.length - 1] = '' if outDir.end_with?('/')

  exporttype = Varnam::VARNAM_EXPORT_WORDS if $options[:action] == 'export-words'
  exporttype = Varnam::VARNAM_EXPORT_FULL if $options[:action] == 'export-full'

  done = VarnamLibrary.varnam_export_words($varnam_handle.get_pointer(0), 30000, outDir.strip,
                                           exporttype, ExportCallback);
  if done != 0
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    puts "Export failed. #{error_message}"
    exit(1)
  end

  puts ""
  puts "Exported words to #{outDir}"

end

def _persist_stemrules(old_ending, new_ending)
  return if _context.errors > 0
  rc = VarnamLibrary.varnam_create_stemrule($varnam_handle.get_pointer(0), old_ending, new_ending)
  if rc != 0
    error_message = VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
    error error_message
  end
  return rc
end

def _create_stemrule(hash, options)
  return if _context.errors > 0
  hash.each_pair do |key,value|
    rc = _persist_stemrules(key, value)
    if rc != 0
      puts "could not create stemrule for " + key + ":" + value
    end
  end
end 

def stemrules(hash,options={})
 # _ensure_sanity(hash)
  _create_stemrule(hash, options) 
  puts VarnamLibrary.varnam_get_last_error($varnam_handle.get_pointer(0))
end

def display_available_schemes
	handles = VarnamLibrary::varnam_get_all_handles()
	unless handles.nil?
		puts "SCHEMES AVAILABLE"
		puts "================="
		VarnamLibrary::varray_length(handles).times do |i|
    	handle = VarnamLibrary.varray_get(handles, i)
  		ptr = FFI::MemoryPointer.new :pointer
			done = VarnamLibrary.varnam_get_scheme_details(handle, ptr)
			if done != 0
				puts "Failed to get scheme details"
			else
    		item = VarnamLibrary::SchemeDetails.new(ptr.get_pointer(0))
				puts "   Lang code: #{item[:langCode].read_string}"
				puts "   Identifier: #{item[:identifier].read_string}"
				puts "   Display name: #{item[:displayName].read_string}"
				puts "   Author: #{item[:author].read_string}"
				puts "   Compiled on: #{item[:compiledDate].read_string}"
				puts "   Stable?: #{item[:isStable] > 0 ? true : false}"
				puts "\n\n"
			end
		end
	end
end

def exceptions_stem(hash, options={})
  hash.each_pair do |key,value|
    rc = VarnamLibrary.varnam_create_stem_exception($varnam_handle.get_pointer(0), key, value)
    if rc != 0
      puts "Could not create stemrule exception"
    end
  end
end
do_action

