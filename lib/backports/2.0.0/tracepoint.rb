# Note that the backports versione of TracePoint does not support
# certain new events of the Ruby 2.0+ API.
#
class TracePoint

  def self.trace(*events, &proc)
    trace = new(*events, &proc)
    trace.enable
    trace
  end

  def self.tracepoints #:nodoc:
    @tracepoints ||= []
  end

  def tracing?
  end

  def self.switch! #:nodoc:
    if @tracepoints.empty?
      set_trace_func(nil)
    else
      bb_stack = []
      tracing = false

      fn = lambda do |e, f, l, m, b, k|
        e = e.gsub('-', '_').to_sym
        # TODO: This condition likely needs to be refined. The point is to prevent
        #       tracing of the code that does the tracing itself, which a) no one
        #       is interested in and b) prevents possbile infinite recursions.
        skip_trace = (__FILE__ == f || (k == Kernel && m == :set_trace_func))
        unless tracing || skip_trace
          tracing = true
          #(p e, f, l, m, b, k, bb_stack; puts "---") if $DEBUG

          # TODO: Does b-call/b-return constitute a new binding?
          if [:call,:c_call,:b_call,:class].include?(e)
            bb_stack << b
          elsif [:return,:c_return,:b_return,:end].include?(e)
            bb = bb_stack.pop
          end
          b = bb unless b  # sometimes there is no binding?

          @tracepoints.each do |tp|
            next unless tp.handle?(e)
            #begin
              tp.send(:call_with, e, f, l, m, k, b, bb)
            #rescue
            #  # trace error event?
            #end
          end

          tracing = false
        end
      end
      set_trace_func(fn)
    end
  end

  def initialize(*events, &proc)
    @events = events.map{ |e| e.to_sym }
    @proc = proc || raise(ArgumentError, "trace procedure required")
    @enabled = false   
  end

  def handle?(event)
    @events.empty? || @events.include?(event.to_sym)
  end

  def enabled?
    @enabled
  end

  def disabled?
    ! @enabled
  end

  def enable
    if block_given?
      if enabled?
        result = yield
      else
        enable
        begin
          result = yield
        ensure
          disable
        end
      end
      result
    else
      previous_state = enabled?
      @enabled = true
      self.class.tracepoints << self
      self.class.switch!
      previous_state
    end
  end

  def disable
    if block_given?
      if disabled?
        result = yield
      else
        disable
        begin
          result = yield
        ensure
          enable
        end
      end
      result
    else
      previous_state = enabled?
      @enabled = false
      self.class.tracepoints.delete(self.reset)
      self.class.switch!
      previous_state
    end
  end

  def event
    raise if disabled?
    @event
  end

  def path
    raise if disabled?
    @path
  end

  def lineno
    raise if disabled?
    @lineno
  end

  def binding
    raise if disabled?
    @binding
  end

  # The previous binding.
  #
  # Note: This is the only *extra* feature that is not currently
  #       part of Ruby 2.0's implementation. It has proven useful
  #       so it's been kept. It would be nice if ko1 (Koichi Sasada)
  #       would agree to include in Ruby's API.
  #
  # Returns [Binding]
  def prior_binding
    raise if disabled?
    @prior_binding
  end
  alias binding_of_caller prior_binding

  def self
    binding.self
  end

  def defined_class
    binding.eval "#{self.class}"
  end

  def method_id
    raise if disabled?
    @method
  end

  def raised_exception
    $!
  end

  # TODO: It may not be possible to implement return_value.
  def return_value
    raise NotImplementedError, "Please contribute a patch if you know how to fix."

    case event
    when :return, :c_return, :b_return
      self
    end
  end

  #--
  # TODO: Ruby's code also had `RUBY_EVENT_SPECIFIED_LINE` with :line,
  #       but I have not idea what that is.
  #++

  def inspect
    return "#<TracePoint:disabled>" if disabled?
    return "#<TracePoint:enabled>" unless event

    case event
    when :line
		  if method_id.nil?
        "#<TracePoint:%s@%s:%s>" % [event, path, lineno]
      else
        "#<TracePoint:%s@%s:%s in `%s'>" % [event, path, lineno, method_id]
      end
    when :call, :c_call, :return, :c_return
      "#<TracePoint:%s `%s'@%s:%s>" % [event, method_id, path, lineno]
    when :thread_begin, :thread_end
	    "#<TracePoint:%s %s>" % [event, self]
    else
      "#<TracePoint:%s@%s:%s>" % [event, path, lineno]
    end
  end

protected

  def call_with(event, file, line, method, klass, bind, prebind=nil) #:nodoc:
    set(event, file, line, method, klass, bind, prebind)
    @proc.call(self)
  end

  def set(event, path, line, method, klass, bind, prebind=nil)  #:nodoc:
    @event   = event.to_sym
    @path    = path
    @lineno  = line
    @method  = method
    @klass   = klass
    @binding = bind || TOPLEVEL_BINDING  # TODO: Correct ?
    @prior_binding = prebind || TOPLEVEL_BINDING  # TODO: or leave nil ?
  end

  def reset
    @event   = nil
    @path    = nil
    @lineno  = nil
    @method  = nil
    @klass   = nil
    @binding = nil
    @prior_binding = nil
    return self
  end
end


class Binding

  # TODO: Get this from other backport
  unless method_defined?(:eval) # 1.8.7+
    def eval(code)
      Kernel.eval(code, self)
    end
  end

  # TODO: Get this from other backport
  unless method_defined?(:self) # 1.9+ ?
    def self()
      @_self ||= eval("self")
    end
  end

end

# Copyright (c) 2005,2013 Thomas Sawyer (BSD-2-Clause License)
