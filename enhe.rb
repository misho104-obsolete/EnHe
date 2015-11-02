#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'open-uri'
require 'nokogiri'
require 'optparse'
require 'mechanize'

class RavMilim
  def initialize
    @agent = Mechanize.new
    toppage = @agent.get('http://www.ravmilim.co.il/')
    topframe = toppage.frames[0]
    if /sessId=(\d+)/.match(topframe.href)
      @session_id = $1
    else
      print "Session id not obtained"
      raise
    end
  end

  def get_right he_word
    query = he_word.encode("windows-1255")
    right_url = "http://www.ravmilim.co.il/rightHebDict.asp?sessId=#{@session_id}&q=#{URI.escape(query)}&num=0&lg="
    p right_url
    @agent.get(right_url)
  end

  def get_left he_word, number
    query = he_word.encode("windows-1255")
    left_url = "http://www.ravmilim.co.il/leftHeDict.asp?sessId=#{@session_id}&n=#{number}&CurrentSelection=5&act=6&word=#{query}"
    @agent.get(left_url)
  end
end

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
  verb_conj = [nil, nil, nil, nil, "to <>", "I <>ed", "(he) <>s", "(he) will <>", "(he) <>!"]
  noun_conj = [nil, nil, "s", nil, "pl", "conj"]
  conjugation = result.lines.grep(/.*הערך.*/)
  conjugation = conjugation.map do |c|
    c = c.gsub(/ *<.*?> */, " ").split(/[ ,]+/).map{|w| w.strip!; w.slice!(0) if w[0] and w[0].ord == 160; w}
    if c[1] =~ /:/ and c[3] =~ /:/
      conj_list = c.length >= 8 ? verb_conj : noun_conj
      c = conj_list.zip(c).map{|x| (x[0].nil? or x[1].nil?) ? nil : x.join("\t")}.compact.join("\n")
    end
    c
  end

  result.gsub!(/\n?<\/(td|tr)>\n?/m, '</\1>')
  result.gsub!(/\n?<(td|tr).*?>\n?/m, '<\1>')
  result.gsub!(/<\/?table.*?>/m, "\n\n")
  result.gsub!(/\s*<\/td>[^><]*<td.*?>\s*/m, "\t\t\t")
  result.gsub!(/\s*<\/tr>[^><]*<tr.*?>\s*/m, "\n")
  result.gsub!(/ *<.*?> */, "")
  result.gsub!(/^ +/,"")
  result.gsub!(/ +$/,"")
  result.gsub!(/ *\t */,"\t")

  # parsed result
  result = [result, "------------------------------\n", conjugation, "==============================\n"].flatten.join("\n").lines.map{|c| c.strip}.join("\n").gsub(/\n\n\n+/, "\n\n")
end

def grammer_he he_word
  $RavMilim.get_right(he_word).search("input").each do | input |
    if input.attr("onclick") =~ /\(\s*document\.form\s*,\s*([0-9]+)\s*\)/
      number = $1
      left = $RavMilim.get_left(he_word, number)
      node = left.search("span.main").first
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

if option[:g]
  $RavMilim = RavMilim.new
end

ARGV.each do |word|
  if    word =~ /[a-zA-Z]/ and not option[:g] then; lookup_he(word)
  elsif word =~ /[a-zA-Z]/ and     option[:g] then; raise "grammar only for hebrew input."
  elsif                            option[:g] then; grammer_he(word)
  else                                              lookup_en(word)
  end
end
