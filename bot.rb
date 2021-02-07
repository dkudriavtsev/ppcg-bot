#!/usr/bin/env ruby

Bundler.require :default
require './lib/patches'
require './lib/tio'

token = ENV['TOKEN']
raise 'No token in environment; set TOKEN' unless token

applog = Log4r::Logger.new 'bot'
applog.outputters = Log4r::Outputter.stderr
ActiveRecord::Base.logger = applog

ActiveRecord::Base.establish_connection(
  adapter: 'sqlite3',
  database: 'db/database.sqlite3'
)

def define_schema
  ActiveRecord::Schema.define do
  end
end

def log_command(name, event, args, extra = nil)
  user = event.author.id
  command = name.to_s
  arguments = args.join ' '

  string = "command execution by user #{user}: .#{command} #{arguments}"
  extra && string << "; #{extra}"
  Log4r::Logger['bot'].info string
end

bot = Discordrb::Commands::CommandBot.new(
  token: token,
  prefix: '~',
  command_doesnt_exist_message: 'Invalid command.'
)

bot.command :echo, {
  help_available: true,
  description: 'Echoes a string',
  usage: '~echo <string>',
  min_args: 1
} do |event, *args|
  log_command(:echo, event, args)
  args.map { |a| a.gsub('@', "\\@\u200D") }.join(' ')
end

bot.command :eval, {
  help_available: false,
  description: 'Evaluates some code. Owner-only.',
  usage: '~eval <code>',
  min_args: 1
} do |e, *args|
  m = e.message
  a = e.author
  log_command(:eval, e, args)
  if a.id == '165998239273844736'.to_s
    eval args.join(' ') # rubocop: disable Security/Eval
  else
    'nope'
  end
end

def walk_tree(tree)
  if tree.instance_of?(Array)
    tree.each_with_object([]) do |elem, a|
      a << elem.children ? walk_tree(elem.children) : elem.dup
    end.flatten
  elsif tree.children
    walk_tree(tree.children)
  else
    elem.dup
  end
end

def get_codespans(text)
  doc = Kramdown::Document.new(text, input: 'GFM')

  rc = doc.root.children

  walk_tree(rc)
    .filter { |elem| elem.type == :codespan }
    .map { |s| pp s.value }
end

bot.command :tio, {
  help_available: true,
  description: 'Evaluates code using Try It Online',
  usage: '~tio <lang> ```<code>``` [```input```]'
} do |event, lang, *_args|
  code, input = get_codespans(event.message.text)

  res = TIO.run(lang, code, nil, input)[0].gsub('```', '\\```').gsub('@', "\\@\u200D")
  msg = event.respond "```\n#{res}\n```"

  msg.create_reaction('❌')
end

bot.reaction_add(emoji: '❌') do |event|
  if event.user.id != '680170235109703696'.to_i
    event.message.delete
  end
end

bot.run true

while (buf = Readline.readline('% ', true))
  s = buf.chomp
  if s.start_with? 'quit', 'stop'
    bot.stop
    exit
  elsif s.start_with? 'restart'
    bot.stop
    exec 'ruby', $PROGRAM_NAME
  elsif s.start_with? 'irb'
    binding.irb
  elsif s == ''
    next
  else
    puts 'Command not found'
  end
end

bot.join
