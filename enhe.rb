#!/usr/bin/ruby
# -*- coding: utf-8 -*-

require 'open-uri'
require 'nokogiri'

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
    output he_word, ["[NOT FOUND]"], false
    return
  end

  first = true
  boxes.each do |box|
    word      = box.css("span.word").text.strip
    translate = box.css("div.default_trans").text.strip
    output word, [translate], first
    first = false
  end
end

ARGV.each do |word|
  if word =~ /[a-zA-Z]/
    lookup_he(word)
  else
    lookup_en(word)
  end
end
