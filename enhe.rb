#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'open-uri'
require 'nokogiri'
require 'optparse'

def url query
  "http://www.morfix.co.il/#{URI.escape(query)}"
end

def get url
  charset = nil
  html = open(url) do |f|
    charset = f.charset
    f.read
  end
  Nokogiri::HTML.parse(html, nil, charset)
end

def output query, candidates, first = true
  if candidates.length == 0
    first = false
    candidates = ["[NOT FOUND]"]
  end
  candidates.each do |c|
    print (first ? "" : "\# "), query, "\t", c, "\n"
    first = false
  end
end

def lookup_he en_word
  result = get(url(en_word.downcase))
  candidates = result.css("div.heTrans").map { |d| d.text.split(/[;,]/) }
    .flatten.map{ |d| d.strip }

  output en_word, candidates
end

def lookup_en he_word
  result = get(url(he_word))
  boxes = result.css("div.translate_box")

  if boxes.length == 0
    output "[NOT FOUND]", [he_word], false
    return
  end

  first = true
  boxes.each do |box|
    word      = box.css("span.word").text.strip
    translate = box.css("div.default_trans").text.strip
    output translate, [word], first
    first = false
  end
end


def grammer_he_format result
  result.gsub!(/\n?<\/(td|tr)>\n?/m, '</\1>')
  result.gsub!(/\n?<(td|tr).*?>\n?/m, '<\1>')
  result.gsub!(/<\/?table.*?>/m, "\n\n")
  result.gsub!(/\s*<\/td>[^><]*<td.*?>\s*/m, "\t\t\t")
  result.gsub!(/\s*<\/tr>[^><]*<tr.*?>\s*/m, "\n")
  result.gsub!(/ *<.*?> */, "")
  result.gsub!(/^ +/,"")
  result.gsub!(/ +$/,"")
  result.gsub!(/ *\t */,"\t")
  result
end

def grammer_he he_word
  query = he_word.encode("windows-1255")
  right_url = "http://www.ravmilim.co.il/rightHebDict.asp?q=#{URI.escape(query)}num0"
  print right_url
  right = get(right_url)
  right.css("input").each do | input |
    if input.attr("onclick") =~ /\(\s*document\.form\s*,\s*([0-9]+)\s*\)/
      number = $1
      left_url = "https://www.ravmilim.co.il/leftHeDict.asp?sessId=&n=#{number}&CurrentSelection=5&act=6&word=#{URI.escape(query)}"
      print left_url
      left = get(left_url)
      node = left.css("span.main").first
      while node.instance_of?(Nokogiri::XML::Element)
        break if node.name == "td"
        node = node.parent
      end
      print grammer_he_format(node.inner_html.encode!(Encoding::UTF_8))
      break      # only the first element of "right"...
    end
  end
end


option = {}
OptionParser.new do |opt|
  opt.on("-g", "lookup grammar") { |v| option[:g] = v }
  opt.parse!(ARGV)
end

ARGV.each do |word|
  if    word =~ /[a-zA-Z]/ and not option[:g] then; lookup_he(word)
  elsif word =~ /[a-zA-Z]/ and     option[:g] then; raise "grammar only for hebrew input."
  elsif                            option[:g] then; grammer_he(word)
  else                                              lookup_en(word)
  end
end
