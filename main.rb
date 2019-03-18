#!/usr/bin/ruby

# general todo: this file is a proof of concept. needs
# to be ported to C++ to be usable on very large files.

require "ostruct"
require "optparse"

class PrintLine
  attr_accessor :opts

  # contains the spec representation of the '-n' option.
  # until '-n-<n>', etc, is actually implemented, @startval
  # must ALWAYS be defined - although the parser will obviously
  # already reject unparseable input.
  # if @endval is not nil, then print until @endval.
  # if @printafter is defined, then, regardless of @endval, print
  # until EOF.
  # ((note: it is impossible to define both @endval AND @printafter via '-n' anway))
  class LineSpec
    attr_accessor :startval, :endval, :printafter

    def initialize(startval=nil, endval=nil, prafter=false)
      @startval = startval
      @endval = endval
      @printafter = prafter
    end

    def to_msg
    end
  end

  def initialize()
    @opts = OpenStruct.new({
      # output handle - currently not possible to define via flags
      outfh: $stdout,
      # if true, prepend each line with their respective line number
      printlineno: false,
      # where line specs reside
      specs: [],
    })
    # cache output handle
    @ofh = @opts.outfh
  end

  def reset_opts
  end

  def note(fmt, *a, **kw)
    return
    str = (if (a.empty? && kw.empty?) then fmt else sprintf(fmt, *a, **kw) end)
    $stderr.printf("-- %s\n", str)
  end

  def fail(fmt, *a, **kw)
    str = (if (a.empty? && kw.empty?) then fmt else sprintf(fmt, *a, **kw) end)
    $stderr.printf("error: %s\n", str)
    exit(1)
  end

  def push_spec(startval, endval=nil, prafter=false)
    @opts.specs.push(LineSpec.new(startval, endval, prafter))
  end

  
  # todo:
  #   -n-100    would print everything BEFORE line 100
  #   -n
  def parse_nval(str)
    if str.match(/^\d+/) then
      # exact line
      if (m=str.match(/^(?<start>\d+)$/)) != nil then
        sv = m["start"].to_i
        push_spec(sv, nil, false)
        note("n: specific line %d selected", sv)
      # print everything after <n>
      elsif (m=str.match(/^(?<start>\d+)-$/)) != nil then
        sv = m["start"].to_i
        push_spec(sv, nil, true)
        note("n: print everything after %d selected", sv)
      # ranged print: print from <start> to <end>
      elsif (m=str.match(/^(?<start>\d+)-(?<end>\d+)/)) != nil then
        sv = m["start"].to_i
        ev = m["end"].to_i
        push_spec(sv, ev, false)
        note("n: ranged print from %d to %d selected", sv, ev)
      else
        fail("did not understand argument %p to -n", str)
      end
    else
      fail("could not parse argument %p to -n", str)
    end
  end

  def parse_nspec(str)
    parts = str.split(",").map(&:strip).reject(&:empty?)
    if parts.length > 0 then
      parts.each do |part|
        parse_nval(part)
      end
    else
      fail("-n split is empty???")
    end
  end

  def oprint(ci, ln)
    if opts.printlineno then
      @ofh.printf("%d\t", ci+1)
    end
    @ofh.write(ln)
    @ofh.flush
  end

  def pline(infh, spec)
    ci = 0
    # cache values, because accessing OpenStruct is surprisingly slow
    o_startval = spec.startval
    o_endval = spec.endval
    o_printafter = spec.printafter
    mayprint = false
    infh.each_line do |line|
      if (mayprint) || ((ci + 1) == o_startval) then
        oprint(ci, line)
        # end reached, time to return
        if (o_endval == nil) && (o_printafter == false) then
          return
        end
      else
        if ci == o_startval then
          mayprint = true
        else
          # no point in counting further, so just return
          if ci == o_endval then
            return
          end
        end
      end
      ci += 1
    end
  end

  def main(infh)
    @opts.specs.each do |spec|
      pline(infh, spec)
      if @opts.specs.length > 1 then
        infh.rewind
      end
    end
  end
end

begin
  pl = PrintLine.new
  OptionParser.new{|prs|
    prs.on("-n<val>", "--line=<val>", "print line(s) at <val>"){|v|
      pl.parse_nspec(v)
    }
    prs.on("-l", "--print-lineno", "print line numbers"){|_|
      pl.opts.printlineno = true
    }
  }.parse!
  if ARGV.empty? then
    if $stdout.tty? then
      $stderr.printf("usage: pline [<opts...>] <files...>\n")
      exit(1)
    else
      pl.main($stdin)
    end
  else
    ARGV.each do |arg|
      if File.file?(arg) then
        File.open(arg, "rb") do |fh|
          pl.main(fh)
        end
      else
        $stderr.printf("not a file: %p\n", arg)
      end
    end
  end
end

