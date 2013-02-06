# encoding: UTF-8

@file_ignores = /coverage|.git\//

@js_comment = {
 start:  /^\s*\/\*/,
 end:    /\*\//,
 single: /^\s\/\//
}

class LOC < Hash
  def initialize
    super do
      0
    end
  end

  def inc file
    self[file] += 1
  end

  def total
    self.values.inject(:+) || 0
  end

  def total_formatted
    commaize total
  end

  protected

  def commaize number
    text = number.to_s

    if text.length > 3 then
      text.insert -4, ','
      text[0..-5] = commaize text[0..-5]
    end

    text.rjust 10
  end

end

@code   = LOC.new
@test   = LOC.new
@vendor = LOC.new
@count  = 0

require 'pry'

def progress text = nil
  clear_line = "\e[2K"
  start_of_line = "\e[0G"
  print start_of_line, clear_line
  print "(#{@count += 1}/#{@total_count})", text.strip if text
end

def skip? line
  comment = @js_comment.inject(Hash.new) do |results, (type, regex)|
    results[type] = line =~ regex
  results
  end

  comment[:start] && !comment[:end] || comment[:single]
end

def test? line
  line =~ /spec/
end

def vendor? line
  line =~ /vendor|submodules/
end

def process file
  return false if file =~ @file_ignores

  File.open file do |js|
    next if File.directory? js

    js.each_line do |line|
      scan file, line
    end
  end
end

def scan file, line
  line.encode! 'UTF-16', 'UTF-8', invalid: :replace, replace: ''
  line.encode! 'UTF-8', 'UTF-16'

  if line.strip.empty? || skip?(line) then
    return
  elsif vendor? file then
    @vendor.inc file
  elsif test? file then
    @test.inc file
  else
    @code.inc file
  end
end

@total_count = `wc -l #{ARGV.first}`.to_i
File.open ARGV.first do |list_of_files|
  list_of_files.each_line do |file|
    progress file
    process file.strip
  end
end

def ratio
  code = @code.total.to_f / @test.total
  test = @test.total.to_f / @code.total

  if code > test then
    "#{code.round(1)}:1"
  else
    "1:#{code.round(1)}"
  end.rjust 12
end

puts "\n\n"
puts "Files:  #{@count.to_s.rjust 14}"
puts "------------------------"
puts "Code:   #{@code.total_formatted}"
puts "Test:   #{@test.total_formatted}"
puts "Vendor: #{@vendor.total_formatted}"
puts "------------------------"
puts "LOC/Test: #{ratio}"
