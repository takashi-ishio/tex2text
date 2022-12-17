#!/usr/local/bin/ruby -Ke
# Script to Remove comments and tags from TeX file
=begin
The MIT License

Copyright 2007 Takashi Ishio

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
=end

SimpleTextOption = '-s'
NewParagraph = '<NEW_PARAGRAPH>'
Environment = '<Environment>'
Usage = 'tex2text.rb [-s] [TeX FileName]'

Verb = '\verb'
Footnote = '\footnote'

if ARGV.length == 0
  puts Usage
  exit
end

opt = ARGV[0]
SimpleTextMode = (opt == SimpleTextOption)

if (opt == SimpleTextOption) && (ARGV.length == 1)
  puts Usage
  exit
end

filename = if SimpleTextMode then ARGV[1] else ARGV[0] end


class TexReader

  def initialize(filename)
    @contents = readfile(File.basename(filename), File.dirname(filename) + "/").join("\n") + "\n"
  end
  
  def readfile(filename, basedir)
    contents = []
    f = File.open(basedir + filename)
    f.each { |line|
      if line =~ /\s*\\input\{([-a-zA-Z0-9\/.]+)\}/
        input_filename = $1
        if input_filename[-4..-1] != ".tex"
          input_filename.concat(".tex")
        end
        input_file_contents = readfile(input_filename, basedir)
        contents.concat(input_file_contents)
      else
        contents << line
      end
    }
    remove_comments(contents)
    return contents
  end
  
  attr :contents
  
  def remove_comments(contents)
    contents.map! { |line| 
      if /^((:?[^\\]|\\.)*?)%/ =~ line
        $1
      else
        line.chomp
      end
    }
    contents.delete_if {|line| line == '' }
  end
  

  def parse_verb
    verbs = []
    while i = @contents.index(Verb) do
      start_char = @contents[i + Verb.length]
      end_char_pos = @contents.index(start_char, i + Verb.length + 1)
      if end_char_pos
        verbs << @contents[i + Verb.length + 1 .. end_char_pos-1 ]
        @contents[i .. end_char_pos ] = "\"Verb #{verbs.size}\""
      else
        $stderr.puts "cannot find the end of \\verb tag."
      end
    end
    return verbs
  end
  
  def find_unescaped_char(char, idx)
    while idx = @contents.index(char, idx+1) do
      if (idx == 0) || (@contents[idx-1] != ?\\ )
        return idx
      end
    end
    return nil
  end
  
  Expr = '$'
  def parse_math
    expressions = []
    i = -1
    while i = find_unescaped_char(Expr, i) do
      end_char_pos = find_unescaped_char(Expr, i)
      if end_char_pos
        expressions << @contents[i + 1 .. end_char_pos-1 ]
        @contents[i .. end_char_pos ] = "\"Expression #{expressions.size}\""
      else
        info_start = if i > 10 then i - 10 else i end
        info_end   = if i < @contents.length - 40 then info_start + 40 else @contents.length-1 end
        $stderr.puts "cannot find the end of \"$\"."
        $stderr.puts "  context: #{@contents[info_start .. info_end]}"
        $stderr.puts "  last expression: #{expressions[-1]}" if expressions.length > 0
        expressions << @contents[i + 1 .. -1 ]
        @contents[i .. -1] = "\"Expression #{expressions.size}\""
        break
      end
    end
    return expressions
  end
  
  def parse_footnote
    footnotes = []
    while i = @contents.index(Footnote) do
      end_char_pos = @contents.index(/[^\\]\}/, i + Footnote.length + 1)
      if end_char_pos
        footnotes << @contents[i + Footnote.length + 1 .. end_char_pos ]
        if not SimpleTextMode
          @contents[i .. end_char_pos + 1 ] = " (*#{footnotes.size})" 
        else
          @contents[i .. end_char_pos + 1 ] = ""
        end
      else
        $stderr.puts "cannot find the end of \\footnote tag."
        @contents[i .. -1] = ""
      end
    end
    return footnotes
  end
  
  
  def resolve_labels
    contents = @contents.split("\n")
    label = Hash.new
    fig_value = 1
    tab_value = 1
    chapter = 0
    section   = 0
    subsection = 0
    subsubsection = 0
    is_figure = false
    is_table  = false
    contents.map! { |line|
      # count sections, figures, tables
      if /\\begin\{figure\}/ =~ line
        is_figure = true
      elsif /\\end\{figure\}/ =~ line
        is_figure = false
      elsif /\\end\{table\}/ =~ line
        is_table = false
      elsif /\\begin\{table\}/ =~ line
        is_table = true
      elsif /\\chapter\*\{([^\}]+)\}/ =~ line
        line = NewParagraph + " * #{$1}"
      elsif /\\chapter\{([^\}]+)\}/ =~ line
        chapter += 1
        section = 0
        subsection = 0
        subsubsection = 0
        line = NewParagraph + "Chapter #{chapter}: #{$1}"
      elsif /\\section\{([^\}]+)\}/ =~ line
        section += 1
        subsection = 0
        subsubsection = 0
        line = NewParagraph + "#{section} #{$1}"
      elsif /\\section\*\{([^\}]+)\}/ =~ line
        line = NewParagraph + " * #{$1}"
      elsif /\\subsection\{([^\}]+)\}/ =~ line
        subsection += 1
        subsubsection = 0
        line = NewParagraph + "#{section}.#{subsection} #{$1}"
      elsif /\\subsubsection\{([^\}]+)\}/ =~ line
        subsubsection += 1
        line = NewParagraph + "#{section}.#{subsection}.#{subsubsection} #{$1}"
      end

      # assign labels
      if /\\label\{([^}]+)\}/ =~ line
        if is_figure
          label[$1] = fig_value
          fig_value += 1
        elsif is_table
          label[$1] = tab_value
          tab_value += 1
        else
          sec = "#{section}"
          sec = sec + ".#{subsection}" if subsection > 0
          sec = sec + ".#{subsubsection}" if subsubsection > 0
          label[$1] = sec
        end
      end
      # remove label declaration
      while line =~ /(.*)\\label\{[^}]+\}(.*)/ do
        line = $1 + " " + $2
      end
      
      line
    }
    # resolve \ref
    contents.map! { |line|
      while line =~ /([^\\]*)\\ref\{([^}]+)\}(.*)/  do
        if label[$2]
          line = "#{$1}#{label[$2]}#{$3}"
        else
          line = "#{$1}??#{$3}"
        end
      end
      line
    }
    contents.compact!
    @contents = contents.join("\n")
  end

  def resolve_citation
    contents = @contents.split("\n")
    cite = Hash.new
    value = 1
    contents.each { |line|
      if line =~ /\\bibitem\{([^}]+)\}/
        cite[$1] = value
        value += 1
      end
    }
    contents.map! { |line|
      while line =~ /(.*[^\\])\\cite\{([^}]+)\}(.*)/  do
        k1 = $1
        k2 = $2
        k3 = $3
        cited = []
        k2.split(",").each { |label|
          label.strip!
          if cite[label]
            cited << cite[label] 
          else
            cited << "?"
          end
        }
        if SimpleTextMode
          line = k1 + k3
        else
          line = k1 + "[" + cited.join(", ") + "]" + k3
        end
      end
      line
    }
    @contents = contents.join("\n")
  end
  
  def remove_figures_and_tables
    contents = @contents.split("\n")

    in_tag = false
    contents.map! { |line|
      if in_tag
        if line =~ /\\end\{(table|figure|thebibliography)\}(.*)/
          in_tag = false
          if $2 == ""
            nil
          else
            $2
          end
        else
          nil
        end
      elsif line =~ /(.*)\\begin\{(table|figure|thebibliography)\}/
        in_tag = true
        if $1 == ""
          nil
        else
          $1
        end
      else
        line
      end
    }
    contents.compact!

    @contents = contents.join("\n")
  end
end

reader = TexReader.new(filename)
verbs = reader.parse_verb
footnotes = reader.parse_footnote
expressions = reader.parse_math

reader.resolve_labels
reader.resolve_citation
reader.remove_figures_and_tables

# remove other environments
contents = reader.contents.split("\n")
contents.map! { |line|
  if /(.*)\\(begin|end)\{([^\}]+)\}(.*)/ =~ line
    "#{Environment}#{$1.strip}--- #{$2} < #{$3} > --- #{$4}"
  else
    line
  end
}
contents = contents.join("\n")

# remove other inline tags 
def remove_tag(line, tag, remove_params)
  while i = line.index(tag) do
    line[i .. i + tag.length - 1] = ""
    while (line[i] == ?{) || (line[i] == ?[) do 
      if line[i] == ?{
        re = /(([^\\])\})/         # "\}" represents simple "}" (not the end of the tag)
        if end_tag_pos = line.index(re, i+1)
          if remove_params 
            line[i .. end_tag_pos + 1] = ""
          else
            line[ end_tag_pos + 1 .. end_tag_pos + 1 ] = ""
            line[i..i] = ""
          end
        end
      elsif line[i] == ?[
        re = /(([^\\])\])/         # "\}" represents simple "}" (not the end of the tag)
        if end_tag_pos = line.index(re, i+1) 
          if remove_params 
            line[i .. end_tag_pos + 1] = ""
          else
            line[ end_tag_pos + 1 .. end_tag_pos + 1 ] = ""
            line[i..i] = ""
          end
        end
      end
    end
  end

  line
end
RemovalWithParams = [ "\\item", "\\usepackage", "\\cleardoublepage",
            "\\tableofcontents", "\\listoffigures", "\\listoftables", "\\setcounter" ]
Removal = [ "\\bf", "\\sf", "\\it", "\\emph", "\\textrm", "\\textsf", "\\texttt", 
            "\\textmc", "\\textgt", "\\textgt", "\\textmd", "\\textbf", "\\textup", 
            "\\textit", "\\textsl", "\\textsc", "\\textnormal"]

# Process RemovalWithParams first because "\\it" in Removal matches "\\item".
RemovalWithParams.each { |tag|
  contents = remove_tag(contents, tag, true)
}
Removal.each { |tag|
  contents = remove_tag(contents, tag, false)
}

# remove empty lines
contents = contents.split("\n")
for i in 0.. contents.size - 2
  if (contents[i].strip == "") and (contents[i+1].strip == "")
    contents[i] = nil
  end
end
contents.compact!


# adjust lines
paragraphs = [""]
contents.each { |line|
  if line[0..NewParagraph.length-1] == NewParagraph
    paragraphs << "" if paragraphs[-1] != ""
    paragraphs << ""
    paragraphs << line[NewParagraph.length..-1]
    paragraphs << ""
    paragraphs << ""
    next
  end
  if line[0..Environment.length-1] == Environment
    paragraphs << "" if paragraphs[-1] != ""
    paragraphs << line[Environment.length..-1]
    paragraphs << ""
    next
  end

  if SimpleTextMode
    paragraphs[-1].concat " " if paragraphs[-1].length > 0
    l = line.strip
    paragraphs[-1].concat l
    paragraphs << "" if l[-1] == ?.
  else
    paragraphs << line
  end
}
contents = paragraphs

# output the result 
contents.each { |line| puts line } 

if verbs.size > 0
  puts ""
  puts "--- verbs ---"
  verbs.each_with_index { |verb, idx|
    puts "Verb #{1+idx} = #{verb}"
  }
end

if footnotes.size > 0
  puts ""
  puts "--- footnotes ---"
  footnotes.each_with_index { |foot, idx|
    puts "*#{1+idx} = #{foot}"
  }
end

if expressions.size > 0
  puts ""
  puts "--- expressions ---"
  expressions.each_with_index { |expr, idx|
    puts "Expression #{1+idx} = #{expr}"
  }
end


